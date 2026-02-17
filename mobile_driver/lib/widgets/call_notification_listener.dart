import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../features/tracking/presentation/widgets/incoming_call_alert.dart';
import '../features/tracking/presentation/screens/call_screen.dart';
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
      final callerName = data['caller_name'] as String?;

      if (callId == null || callerType == null) return;

      print(
          '[CallListener] 📞 Appel entrant: $callId de $callerType ($callerName)');

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

      // Récupérer les infos de la session pour avoir le trip_id
      final session = await _getCallSession(callId);
      if (session == null) {
        print('[CallListener] ❌ Session introuvable');
        return;
      }

      // Vérifier à nouveau après l'opération async
      if (!mounted) {
        print('[CallListener] ⚠️ Widget démonté après récupération session');
        return;
      }

      // Récupérer le nom complet depuis le trip si c'est un rider
      String displayName = callerName?.trim() ?? '';
      print(
          '[CallListener] 🔍 Nom initial depuis notification: "$displayName"');

      if (callerType == 'rider' && session['trip_id'] != null) {
        try {
          print(
              '[CallListener] 🔍 Récupération rider depuis trip: ${session['trip_id']}');
          final tripData = await Supabase.instance.client
              .from('trips')
              .select('rider:rider_id(full_name, name)')
              .eq('id', session['trip_id'])
              .maybeSingle();

          print('[CallListener] 🔍 Trip data reçu: $tripData');

          if (tripData != null && tripData['rider'] != null) {
            final rider = tripData['rider'] as Map<String, dynamic>;
            print('[CallListener] 🔍 Rider data: $rider');

            final fullName = rider['full_name']?.toString().trim();
            final name = rider['name']?.toString().trim();

            print('[CallListener] 🔍 full_name: "$fullName", name: "$name"');

            if (fullName?.isNotEmpty == true) {
              displayName = fullName!;
            } else if (name?.isNotEmpty == true) {
              displayName = name!;
            }

            print('[CallListener] 🔍 Nom final sélectionné: "$displayName"');
          } else {
            print('[CallListener] ⚠️ tripData ou rider est null');
          }
        } catch (e) {
          print('[CallListener] ⚠️ Erreur récupération nom rider: $e');
        }
      }

      // Valeur par défaut si toujours vide
      if (displayName.isEmpty) {
        displayName = callerType == 'rider' ? 'Passager' : 'Chauffeur';
        print(
            '[CallListener] 🔍 Utilisation valeur par défaut: "$displayName"');
      } else {
        print('[CallListener] ✅ Nom final utilisé: "$displayName"');
      }

      // Vérifier une dernière fois avant d'afficher le dialog
      if (!mounted) {
        print('[CallListener] ⚠️ Widget démonté avant affichage dialog');
        return;
      }

      // Utiliser addPostFrameCallback pour éviter les conflits avec le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final currentContext = rootNavigatorKey.currentContext;
        if (currentContext == null || !currentContext.mounted) {
          print('[CallListener] ⚠️ Context non disponible pour dialog');
          return;
        }

        IncomingCallAlert.show(
          context: currentContext,
          callId: callId,
          tripId: session['trip_id'] as String? ?? '',
          callerName: displayName,
          callerType: callerType,
          onAccept: () async {
            print('[CallListener] ✅ Appel accepté: $callId');

            // Naviguer vers l'écran d'appel
            try {
              if (!mounted) {
                print('[CallListener] ⚠️ Widget démonté, navigation annulée');
                return;
              }

              final navContext = rootNavigatorKey.currentContext;
              if (navContext == null || !navContext.mounted) {
                print('[CallListener] ⚠️ Context invalide pour navigation');
                return;
              }

              print(
                  '[CallListener] 🚀 Navigation vers CallScreen: callId=$callId, tripId=${session['trip_id']}, receiver=$displayName');
              final result = await Navigator.push(
                navContext,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    callId: callId,
                    tripId: session['trip_id'] as String,
                    receiverId: session['caller_id'] as String,
                    receiverName: displayName,
                    receiverType: callerType,
                    isIncoming: true,
                  ),
                ),
              );
              print('[CallListener] 📱 Retour de CallScreen: $result');
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
          .select('trip_id, caller_id')
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
