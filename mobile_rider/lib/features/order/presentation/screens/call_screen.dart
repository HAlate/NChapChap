import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import '../../../../services/call_service.dart';
import '../../../../services/webrtc_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final callServiceProvider = Provider((ref) => CallService());
final webrtcServiceProvider = Provider((ref) => WebRTCService());

class CallScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String receiverId;
  final String receiverName;
  final String receiverType; // 'rider' ou 'driver'
  final String callId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.tripId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverType,
    required this.callId,
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  int _callDuration = 0;
  String _callStatus = 'Connexion...';
  WebRTCService? _webrtcService;
  StreamSubscription? _connectionStateSubscription;
  dynamic _callSessionSubscription; // RealtimeChannel for call acceptance
  bool _isInitializing = false;
  bool _offerCreated = false; // Pour éviter de créer l'offre plusieurs fois
  bool _isEnding = false; // Flag pour éviter les appels multiples

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  /// Demander les permissions microphone
  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _initializeCall();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone requise pour les appels'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _initializeCall() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      print('[CallScreen] Initializing WebRTC...');

      // Créer le service WebRTC
      _webrtcService = WebRTCService();
      await _webrtcService!.initialize();

      // Obtenir le flux audio local
      await _webrtcService!.getLocalStream();

      // Écouter les changements d'état de connexion
      _connectionStateSubscription =
          _webrtcService!.connectionState.listen((state) {
        print('[CallScreen] Connection state changed: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() {
              _callStatus = 'Connecté';
            });
            _startCallTimer();
          }
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          if (mounted) {
            setState(() {
              _callStatus = 'Déconnecté';
            });
          }
        }
      });

      if (widget.isIncoming) {
        // Appel entrant - accepter automatiquement et attendre l'offre
        setState(() {
          _callStatus = 'Connexion...';
        });
        await _acceptCall();
        _listenForOffer();
      } else {
        // Appel sortant - attendre que le driver accepte avant de créer l'offre
        setState(() {
          _callStatus = 'Sonnerie...';
        });
        _waitForCallAcceptance();
      }
    } catch (e) {
      print('[CallScreen] Error initializing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'initialisation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  /// Créer et envoyer l'offre WebRTC
  Future<void> _createAndSendOffer() async {
    try {
      print('[CallScreen] Creating offer...');

      // Créer l'offre
      final offer = await _webrtcService!.createOffer();

      // Envoyer l'offre via la signalisation
      await _webrtcService!.sendSignal(widget.callId, 'offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });

      print('[CallScreen] Offer sent, waiting for answer...');

      // Écouter la réponse
      _listenForAnswer();
    } catch (e) {
      print('[CallScreen] Error creating offer: $e');
      rethrow;
    }
  }

  /// Écouter l'offre (pour l'appelé)
  void _listenForOffer() {
    print('[CallScreen] Listening for offer...');

    _webrtcService!.listenToSignaling(widget.callId, (signal) async {
      final currentUserId = ref.read(callServiceProvider).getCurrentUserId();

      // Ignorer nos propres signaux
      if (signal['sender_id'] == currentUserId) return;

      if (signal['type'] == 'offer') {
        print('[CallScreen] Received offer');

        try {
          // Définir la description distante
          final sdp = signal['data']['sdp'];
          final type = signal['data']['type'];

          await _webrtcService!.setRemoteDescription(
            RTCSessionDescription(sdp, type),
          );

          // Marquer comme traité
          await _webrtcService!.markSignalProcessed(signal['id']);
        } catch (e) {
          print('[CallScreen] Error processing offer: $e');
        }
      } else if (signal['type'] == 'ice-candidate') {
        print('[CallScreen] Received ICE candidate');

        try {
          final candidateData = signal['data'];
          final candidate = RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          );

          await _webrtcService!.addIceCandidate(candidate);
          await _webrtcService!.markSignalProcessed(signal['id']);
        } catch (e) {
          print('[CallScreen] Error adding ICE candidate: $e');
        }
      }
    });
  }

  /// Écouter la réponse (pour l'appelant)
  void _listenForAnswer() {
    print('[CallScreen] Listening for answer...');

    _webrtcService!.listenToSignaling(widget.callId, (signal) async {
      final currentUserId = ref.read(callServiceProvider).getCurrentUserId();

      // Ignorer nos propres signaux
      if (signal['sender_id'] == currentUserId) return;

      if (signal['type'] == 'answer') {
        print('[CallScreen] Received answer');

        try {
          final sdp = signal['data']['sdp'];
          final type = signal['data']['type'];

          await _webrtcService!.setRemoteDescription(
            RTCSessionDescription(sdp, type),
          );

          await _webrtcService!.markSignalProcessed(signal['id']);
        } catch (e) {
          print('[CallScreen] Error processing answer: $e');
        }
      } else if (signal['type'] == 'ice-candidate') {
        print('[CallScreen] Received ICE candidate');

        try {
          final candidateData = signal['data'];
          final candidate = RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          );

          await _webrtcService!.addIceCandidate(candidate);
          await _webrtcService!.markSignalProcessed(signal['id']);
        } catch (e) {
          print('[CallScreen] Error adding ICE candidate: $e');
        }
      }
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  /// Attendre que le driver accepte l'appel avant de créer l'offre
  void _waitForCallAcceptance() {
    print('[CallScreen] 🔄 Waiting for call acceptance...');
    print('[CallScreen] Watching callId: ${widget.callId}');

    // Utiliser un channel Realtime pour écouter les UPDATE events
    final channel =
        Supabase.instance.client.channel('call-acceptance-${widget.callId}');

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'call_sessions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.callId,
      ),
      callback: (payload) {
        print('[CallScreen] 🎉 UPDATE event received!');
        print('[CallScreen] Payload: ${payload.newRecord}');

        final status = payload.newRecord['status'] as String?;
        print('[CallScreen] 📊 New status: $status');

        if (status == 'active' && mounted && !_offerCreated) {
          _offerCreated = true;
          print('[CallScreen] ✅ Status changed to ACTIVE! Creating offer...');
          setState(() {
            _callStatus = 'Connexion...';
          });
          _createAndSendOffer();
        } else if (status == 'rejected' && mounted) {
          print('[CallScreen] ❌ Rejected');
          setState(() {
            _callStatus = 'Appel rejeté';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
            }
          });
        } else if (status == 'ended' && mounted && !_isEnding) {
          _isEnding = true;
          print('[CallScreen] 🔚 Ended by remote');
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('[CallScreen] 🔙 Navigating back after remote end...');
              Navigator.of(context).pop();
            }
          });
        }
      },
    )
        .subscribe((status, error) {
      print('[CallScreen] 📡 Channel status: $status');
      if (error != null) {
        print('[CallScreen] ❌ Channel error: $error');
      }
    });

    // Garder une référence au channel pour le cleanup
    _callSessionSubscription = channel;
  }

  Future<void> _acceptCall() async {
    try {
      print('[CallScreen] Accepting call...');

      // Accepter l'appel dans la base de données
      await ref.read(callServiceProvider).acceptCall(widget.callId);

      // Créer et envoyer la réponse WebRTC
      final answer = await _webrtcService!.createAnswer();

      await _webrtcService!.sendSignal(widget.callId, 'answer', {
        'sdp': answer.sdp,
        'type': answer.type,
      });

      setState(() {
        _callStatus = 'Connexion...';
      });

      print('[CallScreen] Call accepted, answer sent');
    } catch (e) {
      print('[CallScreen] Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) {
      print('[CallScreen] ⏭️ Fin d\'appel déjà en cours, ignoring...');
      return;
    }
    _isEnding = true;

    try {
      print('[CallScreen] 📞 Ending call...');
      print('[CallScreen] Mounted: $mounted');

      // Cleanup et mise à jour de la base
      Future.microtask(() async {
        try {
          print('[CallScreen] 🧹 Starting async cleanup...');
          print(
              '[CallScreen] 💾 Updating call record with duration: $_callDuration');
          await ref
              .read(callServiceProvider)
              .endCall(widget.callId, _callDuration);
          print('[CallScreen] ✅ Call record updated');
        } catch (e) {
          print('[CallScreen] ⚠️ Error during cleanup: $e');
        }
      });

      // Navigate back using SchedulerBinding to avoid Navigator lock
      if (mounted) {
        print('[CallScreen] 🔙 Scheduling navigation...');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('[CallScreen] 🔙 Navigating back...');
            Navigator.of(context).pop();
            print('[CallScreen] ✅ Navigation complete');
          }
        });
      }
    } catch (e, stackTrace) {
      print('[CallScreen] ❌ Error ending call: $e');
      print('[CallScreen] Stack trace: $stackTrace');
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    await _webrtcService?.setMicrophoneEnabled(!_isMuted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await _webrtcService?.setSpeakerEnabled(_isSpeakerOn);
  }

  @override
  void dispose() {
    print('[CallScreen] 🧹 Dispose called');
    try {
      print('[CallScreen] Cancelling call timer...');
      _callTimer?.cancel();

      print('[CallScreen] Cancelling connection state subscription...');
      _connectionStateSubscription?.cancel();

      // Unsubscribe from Realtime channel
      if (_callSessionSubscription != null) {
        try {
          print('[CallScreen] Removing Realtime channel...');
          Supabase.instance.client.removeChannel(_callSessionSubscription);
        } catch (e) {
          print('[CallScreen] ⚠️ Error disposing channel: $e');
        }
      }

      print('[CallScreen] Disposing WebRTC service...');
      _webrtcService?.dispose();

      print('[CallScreen] ✅ Dispose complete');
    } catch (e, stackTrace) {
      print('[CallScreen] ❌ Error in dispose: $e');
      print('[CallScreen] Stack trace: $stackTrace');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Appel vocal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),

              const Spacer(),

              // Avatar et info appelant
              Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.receiverName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.receiverType == 'driver' ? 'Chauffeur' : 'Passager',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _callStatus == 'Connecté'
                        ? _formatDuration(_callDuration)
                        : _callStatus,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Boutons d'appel entrant
              if (widget.isIncoming && _callStatus == 'Appel entrant...') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton rejeter
                    FloatingActionButton(
                      onPressed: _endCall,
                      backgroundColor: Colors.red,
                      heroTag: 'reject',
                      child: const Icon(Icons.call_end, size: 32),
                    ),
                    // Bouton accepter
                    FloatingActionButton(
                      onPressed: _acceptCall,
                      backgroundColor: Colors.green,
                      heroTag: 'accept',
                      child: const Icon(Icons.call, size: 32),
                    ),
                  ],
                ),
              ] else ...[
                // Contrôles pendant l'appel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton muet
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: _toggleMute,
                          backgroundColor: _isMuted
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          heroTag: 'mute',
                          child: Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            color: _isMuted
                                ? theme.colorScheme.primary
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Muet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // Bouton terminer l'appel
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: _endCall,
                          backgroundColor: Colors.red,
                          heroTag: 'end',
                          child: const Icon(Icons.call_end, size: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Terminer',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // Bouton haut-parleur
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: _toggleSpeaker,
                          backgroundColor: _isSpeakerOn
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          heroTag: 'speaker',
                          child: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            color: _isSpeakerOn
                                ? theme.colorScheme.primary
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Haut-parleur',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
