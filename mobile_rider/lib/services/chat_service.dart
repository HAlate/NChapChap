import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer la messagerie entre passager et chauffeur
class ChatService {
  final _supabase = Supabase.instance.client;

  /// Envoyer un message
  Future<void> sendMessage({
    required String tripId,
    required String senderId,
    required String receiverId,
    required String senderType, // 'rider' ou 'driver'
    required String message,
  }) async {
    try {
      // Insérer le message dans la base de données
      await _supabase.from('trip_messages').insert({
        'trip_id': tripId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_type': senderType,
        'message': message,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Envoyer une notification au destinataire
      await _sendMessageNotification(
        receiverId: receiverId,
        senderType: senderType,
        message: message,
        tripId: tripId,
      );
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  /// Récupérer les messages d'un voyage
  Future<List<Map<String, dynamic>>> getMessages(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_messages')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }

  /// Écouter les messages en temps réel
  Stream<List<Map<String, dynamic>>> watchMessages(String tripId) {
    return _supabase
        .from('trip_messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: true);
  }

  /// Marquer un message comme lu ET notifier l'expéditeur
  Future<void> markAsRead(String messageId) async {
    try {
      // Récupérer les infos du message avant de le marquer comme lu
      final messageData = await _supabase
          .from('trip_messages')
          .select('sender_id, sender_type')
          .eq('id', messageId)
          .single();

      // Marquer comme lu
      await _supabase.from('trip_messages').update({
        'read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      // Notifier l'expéditeur que son message a été lu
      await _sendReadNotification(
        senderId: messageData['sender_id'],
        senderType: messageData['sender_type'],
      );
    } catch (e) {
      print('Erreur lors du marquage du message: $e');
      // Ne pas throw pour éviter de bloquer l'UI
    }
  }

  /// Compter les messages non lus pour un voyage
  Future<int> getUnreadCount({
    required String tripId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('trip_messages')
          .select('id')
          .eq('trip_id', tripId)
          .eq('receiver_id', userId)
          .eq('read', false);

      return response.length;
    } catch (e) {
      print('Erreur lors du comptage des messages non lus: $e');
      return 0;
    }
  }

  /// Surveiller les messages non lus en temps réel
  Stream<int> watchUnreadCount({
    required String tripId,
    required String userId,
  }) {
    return _supabase
        .from('trip_messages')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((msg) =>
                msg['trip_id'] == tripId &&
                msg['receiver_id'] == userId &&
                msg['read'] == false)
            .length);
  }

  /// Surveiller les messages qu'on a envoyés et qui ont été lus
  Stream<List<Map<String, dynamic>>> watchReadReceipts({
    required String tripId,
    required String userId,
  }) {
    return _supabase
        .from('trip_messages')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((msg) =>
                msg['trip_id'] == tripId &&
                msg['sender_id'] == userId &&
                msg['read'] == true)
            .toList()
          ..sort((a, b) {
            final aTime = a['read_at'];
            final bTime = b['read_at'];
            if (aTime == null || bTime == null) return 0;
            return DateTime.parse(bTime as String)
                .compareTo(DateTime.parse(aTime as String));
          }));
  }

  /// Envoyer une notification de message
  Future<void> _sendMessageNotification({
    required String receiverId,
    required String senderType,
    required String message,
    required String tripId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': receiverId,
        'type': 'new_message',
        'title': 'Nouveau message',
        'message': senderType == 'rider'
            ? 'Message de votre passager'
            : 'Message de votre chauffeur',
        'data': {
          'trip_id': tripId,
          'sender_type': senderType,
          'preview':
              message.length > 50 ? '${message.substring(0, 50)}...' : message,
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  /// Envoyer une notification à l'expéditeur que son message a été lu
  Future<void> _sendReadNotification({
    required String senderId,
    required String senderType,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': senderId,
        'type': 'message_read',
        'title': 'Message lu',
        'message': senderType == 'rider'
            ? 'Le chauffeur a lu votre message'
            : 'Le passager a lu votre message',
        'data': {
          'notification_type': 'read_receipt',
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification de lecture: $e');
    }
  }
}
