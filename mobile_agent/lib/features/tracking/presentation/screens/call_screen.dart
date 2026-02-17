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
  dynamic _callSessionSubscription;
  bool _isInitializing = false;
  bool _isEnding = false; // Flag pour éviter les appels multiples

  @override
  void initState() {
    super.initState();
    print('[CallScreen] 🎬 INIT START');
    print('[CallScreen]   - callId: ${widget.callId}');
    print('[CallScreen]   - tripId: ${widget.tripId}');
    print('[CallScreen]   - isIncoming: ${widget.isIncoming}');
    print('[CallScreen]   - receiverName: ${widget.receiverName}');
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      _initializeCall();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone requise'),
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
      print('[CallScreen] 🔧 Initialisation WebRTC...');

      _webrtcService = WebRTCService();
      await _webrtcService!.initialize();
      await _webrtcService!.getLocalStream();

      _connectionStateSubscription =
          _webrtcService!.connectionState.listen((state) {
        print('[CallScreen] 📡 Connection state: $state');

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
        print('[CallScreen] 📞 Appel entrant - acceptation et attente offre');
        await _acceptCall();
        _listenForOffer();
        _listenToCallSessionChanges();
      } else {
        print('[CallScreen] 📤 Appel sortant');
        setState(() {
          _callStatus = 'Appel en cours...';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _callStatus = 'Connecté';
          });
          _startCallTimer();
        }
      }
    } catch (e) {
      print('[CallScreen] ❌ Erreur initialisation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _listenToCallSessionChanges() {
    print('[CallScreen] 👂 Écoute des changements de statut de session...');

    try {
      final channel = Supabase.instance.client.channel(
        'call-session-${widget.callId}',
      );

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
              print(
                  '[CallScreen] 🔄 Session update reçue: ${payload.newRecord}');
              final status = payload.newRecord['status'];

              if (status == 'ended') {
                print(
                    '[CallScreen] 📞 Session terminée par le rider - déconnexion...');
                _handleRemoteEndCall();
              }
            },
          )
          .subscribe();

      _callSessionSubscription = channel;
      print('[CallScreen] ✅ Écoute Realtime activée');
    } catch (e) {
      print('[CallScreen] ❌ Erreur écoute session: $e');
    }
  }

  void _listenForOffer() {
    print('[CallScreen] 👂 Écoute de l\'offre WebRTC...');

    _webrtcService!.listenToSignaling(widget.callId, (signal) async {
      final type = signal['type'] as String;
      print('[CallScreen] 📥 Signal reçu: $type');

      if (type == 'offer') {
        print('[CallScreen] 📨 Offre reçue, création réponse...');
        setState(() {
          _callStatus = 'Connexion...';
        });

        final data = signal['data'] as Map<String, dynamic>;
        await _createAndSendAnswer(data);
      } else if (type == 'ice-candidate') {
        print('[CallScreen] 🧊 ICE candidate reçu');
        final candidateData = signal['data'] as Map<String, dynamic>;
        await _webrtcService!.addIceCandidate(
          RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  Future<void> _createAndSendAnswer(Map<String, dynamic> offerData) async {
    try {
      print('[CallScreen] 🔨 Création de la réponse...');

      // Définir l'offre distante
      await _webrtcService!.setRemoteDescription(
        RTCSessionDescription(
          offerData['sdp'],
          offerData['type'],
        ),
      );

      // Créer la réponse
      final answer = await _webrtcService!.createAnswer();

      print('[CallScreen] 📤 Envoi de la réponse...');
      await _webrtcService!.sendSignal(
        widget.callId,
        'answer',
        {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      );

      print('[CallScreen] ✅ Réponse envoyée!');
    } catch (e) {
      print('[CallScreen] ❌ Erreur création réponse: $e');
    }
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

  Future<void> _acceptCall() async {
    try {
      print('[CallScreen] 🔄 Acceptation appel...');

      await ref.read(callServiceProvider).acceptCall(widget.callId);

      print('[CallScreen] ✅ Appel accepté en DB');
      setState(() {
        _callStatus = 'En attente...';
      });
    } catch (e) {
      print('[CallScreen] ❌ Erreur acceptation: $e');
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
      print('[CallScreen] 📵 Fin de l\'appel...');
      print('[CallScreen] Mounted: $mounted');

      // Cleanup et mise à jour de la base
      Future.microtask(() async {
        try {
          print('[CallScreen] 🧹 Updating call record...');
          await ref.read(callServiceProvider).endCall(widget.callId);
          print('[CallScreen] ✅ Call record updated');
        } catch (e) {
          print('[CallScreen] ⚠️ Error updating call: $e');
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
      print('[CallScreen] ❌ Erreur fin appel: $e');
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

  void _handleRemoteEndCall() async {
    if (_isEnding) {
      print(
          '[CallScreen] ⏭️ Fin d\'appel déjà en cours, ignoring remote end...');
      return;
    }
    _isEnding = true;

    try {
      print('[CallScreen] 🔚 Appel terminé par l\'autre utilisateur');

      // Navigate back using SchedulerBinding
      if (mounted) {
        print('[CallScreen] 🔙 Scheduling navigation after remote end...');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('[CallScreen] 🔙 Navigating back...');
            Navigator.of(context).pop();
            print('[CallScreen] ✅ Navigation complete');
          }
        });
      }
    } catch (e) {
      print('[CallScreen] ❌ Erreur fin appel distant: $e');
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // TODO: Implémenter le mute audio via WebRTC
    print('[CallScreen] 🔇 Mute: $_isMuted');
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: Implémenter le speaker via WebRTC
    print('[CallScreen] 🔊 Speaker: $_isSpeakerOn');
  }

  @override
  void dispose() {
    print('[CallScreen] 🧹 Dispose - nettoyage...');
    _callTimer?.cancel();
    _connectionStateSubscription?.cancel();

    // Unsubscribe du channel Realtime
    if (_callSessionSubscription != null) {
      try {
        _callSessionSubscription.unsubscribe();
        print('[CallScreen] ✅ Channel Realtime fermé');
      } catch (e) {
        print('[CallScreen] ⚠️ Erreur fermeture channel: $e');
      }
    }

    _webrtcService?.dispose();
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
                    widget.receiverType == 'rider' ? 'Passager' : 'Chauffeur',
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
