import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../features/order/presentation/widgets/incoming_call_alert.dart';
import '../features/order/presentation/screens/call_screen.dart';
import '../services/call_service.dart';
import '../core/router/app_router.dart';

/// Widget qui écoute les appels entrants et affiche les alertes
class CallNotificationListener extends StatefulWidget {
  final Widget child;

  const CallNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<CallNotificationListener> createState() =>
      _CallNotificationListenerState();
}

class _CallNotificationListenerState extends State<CallNotificationListener> {
  StreamSubscription? _callSubscription;
  final _callService = CallService();

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    _callSubscription =
        notificationService.incomingCalls.listen((notification) async {
      if (!mounted) return;

      final data = notification['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final callId = data['call_id'] as String?;
      final callerType = data['caller_type'] as String?;

      if (callId == null || callerType == null) return;

      print('[CallListener] 📞 Appel entrant: $callId de $callerType');

      // Récupérer les infos de la session d'appel
      final session = await _getCallSession(callId);
      if (session == null) {
        print('[CallListener] ❌ Session introuvable');
        return;
      }

      // Vérifier après l'opération async
      if (!mounted) {
        print('[CallListener] ⚠️ Widget démonté après récupération session');
        return;
      }

      final callerName = callerType == 'rider' ? 'Passager' : 'Chauffeur';

      // Afficher l'alerte d'appel entrant en utilisant le navigatorKey global
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        print('[CallListener] ⚠️ Navigator context non disponible');
        return;
      }

      // Vérifier que le context est monté avant de continuer
      if (!mounted) {
        print('[CallListener] ⚠️ Widget non monté, annulation');
        return;
      }

      // Utiliser addPostFrameCallback pour éviter les conflits avec le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          print('[CallListener] ⚠️ Widget démonté après callback');
          return;
        }

        // Afficher l'alerte d'appel entrant
        IncomingCallAlert.show(
          context: navigatorContext,
          callId: callId,
          tripId: session['trip_id'] as String? ?? '',
          callerName: callerName,
          callerType: callerType,
          onAccept: () async {
            print('[CallListener] ✅ Appel accepté: $callId');

            try {
              if (!mounted) {
                print('[CallListener] ⚠️ Widget démonté, navigation annulée');
                return;
              }

              if (!navigatorContext.mounted) {
                print('[CallListener] ⚠️ Context invalide pour navigation');
                return;
              }

              // Naviguer vers l'écran d'appel
              await Navigator.push(
                navigatorContext,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    callId: callId,
                    tripId: session['trip_id'] as String,
                    receiverId: session['caller_id'] as String,
                    receiverName: callerName,
                    receiverType: callerType,
                    isIncoming: true,
                  ),
                ),
              );
            } catch (e) {
              print('[CallListener] ❌ Erreur navigation: $e');
            }
          },
          onReject: () async {
            print('[CallListener] ❌ Appel rejeté: $callId');
            try {
              await _callService.endCall(callId);
            } catch (e) {
              print('[CallListener] ❌ Erreur rejet appel: $e');
            }
          },
        );
      });
    });
  }

  Future<Map<String, dynamic>?> _getCallSession(String callId) async {
    try {
      final response = await Supabase.instance.client
          .from('call_sessions')
          .select()
          .eq('id', callId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('[CallListener] Erreur récupération session: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
