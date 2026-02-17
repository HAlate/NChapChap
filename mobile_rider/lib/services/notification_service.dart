import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service pour écouter et gérer les notifications en temps réel
class NotificationService {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _notificationSubscription;

  // Stream controller pour les notifications d'appels entrants
  final _incomingCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream des appels entrants
  Stream<Map<String, dynamic>> get incomingCalls =>
      _incomingCallController.stream;

  /// Démarrer l'écoute des notifications
  void startListening() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('[NotificationService] ❌ Pas d\'utilisateur connecté');
      return;
    }

    print(
        '[NotificationService] 🎧 Écoute des notifications démarrée pour: $userId');

    // Écouter les notifications en temps réel - UNIQUEMENT les non lues
    _notificationSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('read', false)
        .listen((notifications) {
          print(
              '[NotificationService] 📦 Reçu ${notifications.length} notifications');

          // Debug : afficher toutes les notifications reçues
          for (var notif in notifications) {
            print(
                '[NotificationService] 🔍 Notification: user_id=${notif['user_id']}, read=${notif['read']}, type=${notif['type']}');
          }

          // Filtrer uniquement les notifications de cet utilisateur non lues
          final userNotifications = notifications.where((notification) {
            final notifUserId = notification['user_id'];
            final isForUser = notifUserId == userId;
            final isUnread = notification['read'] == false;

            print(
                '[NotificationService] 🧪 Test: notifUserId=$notifUserId, userId=$userId, isForUser=$isForUser, isUnread=$isUnread');

            if (isForUser && isUnread) {
              print(
                  '[NotificationService] ✅ Notification valide: ${notification['type']}');
            } else {
              print(
                  '[NotificationService] ❌ Notification rejetée: isForUser=$isForUser, isUnread=$isUnread');
            }

            return isForUser && isUnread;
          });

          print(
              '[NotificationService] 🔍 Filtré: ${userNotifications.length} pour cet utilisateur');

          for (final notification in userNotifications) {
            _handleNotification(notification);
          }
        }, onError: (error) {
          print('[NotificationService] ❌ Erreur stream: $error');
        });
  }

  /// Gérer une notification reçue
  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;

    if (type == 'incoming_call') {
      // Vérifier que l'appel vient bien du driver (pas un appel que le rider a créé)
      final data = notification['data'] as Map<String, dynamic>?;
      final callerType = data?['caller_type'] as String?;

      if (callerType != 'driver') {
        print(
            '[NotificationService] ⏭️ Notification ignorée: caller_type=$callerType (attendu: driver)');
        return;
      }

      // Vérifier que la notification est récente (< 10 secondes)
      final createdAt = DateTime.parse(notification['created_at'] as String);
      final age = DateTime.now().difference(createdAt);

      if (age.inSeconds < 10) {
        // Notification récente - appel en temps réel
        print(
            '[NotificationService] 📞 Appel entrant reçu! (${age.inSeconds}s ago)');
        _incomingCallController.add(notification);

        // NE PAS marquer comme lu - le driver le fera
        // _markAsRead(notification['id'] as String);
      } else {
        // Notification ancienne du snapshot - ignorer
        print(
            '[NotificationService] ⏭️ Notification ancienne ignorée (${age.inSeconds}s ago)');
      }
    }
  }

  /// Marquer une notification comme lue
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({
        'read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
    } catch (e) {
      print('Erreur marquage notification: $e');
    }
  }

  /// Arrêter l'écoute
  void dispose() {
    _notificationSubscription?.cancel();
    _incomingCallController.close();
  }
}
