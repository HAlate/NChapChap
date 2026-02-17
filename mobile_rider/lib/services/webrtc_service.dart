import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service de gestion WebRTC pour les appels audio
class WebRTCService {
  final _supabase = Supabase.instance.client;

  // Configuration des serveurs ICE (STUN/TURN)
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
      // TURN servers publics gratuits (pour tests)
      // En production, utilisez vos propres serveurs TURN
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Contraintes audio
  final Map<String, dynamic> _audioConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': false,
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription? _signalingSubscription;
  final Set<String> _processedSignalIds = {}; // Track processed signals

  // Controllers pour notifier les changements d'état
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Initialiser la connexion WebRTC
  Future<void> initialize() async {
    try {
      print('[WebRTC] Initializing peer connection...');

      // Créer la peer connection
      _peerConnection = await createPeerConnection(_configuration);

      // Configurer les callbacks
      _setupPeerConnectionListeners();

      print('[WebRTC] Peer connection initialized');
    } catch (e) {
      print('[WebRTC] Error initializing: $e');
      rethrow;
    }
  }

  /// Configurer les listeners de la peer connection
  void _setupPeerConnectionListeners() {
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('[WebRTC] New ICE candidate: ${candidate.candidate}');
      // Les ICE candidates seront envoyés via la signalisation
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('[WebRTC] ICE connection state: $state');
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('[WebRTC] Connection state: $state');
      _connectionStateController.add(state);
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      print('[WebRTC] Received remote track');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream!);
      }
    };

    _peerConnection?.onRemoveStream = (MediaStream stream) {
      print('[WebRTC] Remote stream removed');
    };
  }

  /// Obtenir le flux audio local
  Future<MediaStream> getLocalStream() async {
    try {
      print('[WebRTC] Getting local media stream...');

      _localStream =
          await navigator.mediaDevices.getUserMedia(_audioConstraints);

      // Ajouter le stream local à la peer connection
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      print('[WebRTC] Local stream obtained and added to peer connection');
      return _localStream!;
    } catch (e) {
      print('[WebRTC] Error getting local stream: $e');
      rethrow;
    }
  }

  /// Créer une offre (appelant)
  Future<RTCSessionDescription> createOffer() async {
    try {
      print('[WebRTC] Creating offer...');

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      print('[WebRTC] Offer created: ${offer.sdp}');
      return offer;
    } catch (e) {
      print('[WebRTC] Error creating offer: $e');
      rethrow;
    }
  }

  /// Créer une réponse (destinataire)
  Future<RTCSessionDescription> createAnswer() async {
    try {
      print('[WebRTC] Creating answer...');

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      print('[WebRTC] Answer created: ${answer.sdp}');
      return answer;
    } catch (e) {
      print('[WebRTC] Error creating answer: $e');
      rethrow;
    }
  }

  /// Définir la description distante (SDP de l'autre pair)
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      print('[WebRTC] Setting remote description...');
      await _peerConnection!.setRemoteDescription(description);
      print('[WebRTC] Remote description set');
    } catch (e) {
      print('[WebRTC] Error setting remote description: $e');
      rethrow;
    }
  }

  /// Ajouter un ICE candidate reçu
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      print('[WebRTC] Adding ICE candidate: ${candidate.candidate}');
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('[WebRTC] Error adding ICE candidate: $e');
      // Ne pas rethrow car les ICE candidates peuvent échouer sans bloquer l'appel
    }
  }

  /// Écouter la signalisation pour un appel
  void listenToSignaling(
      String callId, Function(Map<String, dynamic>) onSignal) {
    print('[WebRTC] Starting to listen for signaling on call: $callId');

    _signalingSubscription = _supabase
        .from('call_signaling')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId)
        .listen((List<Map<String, dynamic>> data) {
          print('[WebRTC] Received signaling data: ${data.length} items');

          for (var signal in data) {
            final signalId = signal['id'] as String;
            if (signal['processed'] != true &&
                !_processedSignalIds.contains(signalId)) {
              _processedSignalIds.add(signalId);
              onSignal(signal);
              // Mark as processed in database
              markSignalProcessed(signalId);
            }
          }
        });
  }

  /// Envoyer un signal de signalisation
  Future<void> sendSignal(
      String callId, String type, Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      print('[WebRTC] Sending signal - Type: $type, CallId: $callId');

      await _supabase.from('call_signaling').insert({
        'call_id': callId,
        'sender_id': userId,
        'type': type,
        'data': data,
        'processed': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('[WebRTC] Signal sent successfully');
    } catch (e) {
      print('[WebRTC] Error sending signal: $e');
      rethrow;
    }
  }

  /// Marquer un signal comme traité
  Future<void> markSignalProcessed(String signalId) async {
    try {
      await _supabase.from('call_signaling').update({
        'processed': true,
      }).eq('id', signalId);
    } catch (e) {
      print('[WebRTC] Error marking signal as processed: $e');
    }
  }

  /// Activer/désactiver le microphone
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
      print('[WebRTC] Microphone ${enabled ? "enabled" : "disabled"}');
    }
  }

  /// Activer/désactiver le haut-parleur
  Future<void> setSpeakerEnabled(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
      print('[WebRTC] Speakerphone ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      print('[WebRTC] Error toggling speaker: $e');
    }
  }

  /// Nettoyer et fermer la connexion
  Future<void> dispose() async {
    print('[WebRTC] Disposing WebRTC service...');

    await _signalingSubscription?.cancel();

    // Arrêter les tracks locaux
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });

    // Arrêter les tracks distants
    _remoteStream?.getTracks().forEach((track) {
      track.stop();
    });

    // Fermer la peer connection
    await _peerConnection?.close();

    // Libérer les ressources
    await _localStream?.dispose();
    await _remoteStream?.dispose();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;

    await _remoteStreamController.close();
    await _connectionStateController.close();

    print('[WebRTC] WebRTC service disposed');
  }

  /// Vérifier si la connexion est active
  bool get isConnected {
    return _peerConnection?.connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected;
  }

  /// Obtenir l'état actuel de la connexion
  RTCPeerConnectionState? get currentState {
    return _peerConnection?.connectionState;
  }
}
