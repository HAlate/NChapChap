import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service pour gérer les appels audio WebRTC entre passager et chauffeur
/// Utilise Supabase Realtime pour la signalisation WebRTC
class CallService {
  final _supabase = Supabase.instance.client;

  /// Initier un appel vers un passager
  Future<String> initiateCall({
    required String tripId,
    required String callerId,
    required String receiverId,
    required String callerType, // 'rider' ou 'driver'
    String? callerName, // Nom de l'appelant (optionnel)
  }) async {
    try {
      // Créer une session d'appel dans la base de données
      final response = await _supabase
          .from('call_sessions')
          .insert({
            'trip_id': tripId,
            'caller_id': callerId,
            'receiver_id': receiverId,
            'caller_type': callerType,
            'status': 'initiated',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final callId = response['id'] as String;

      // Envoyer une notification push au destinataire
      await _sendCallNotification(
        receiverId: receiverId,
        callId: callId,
        callerType: callerType,
        callerName: callerName,
      );

      return callId;
    } catch (e) {
      throw Exception('Erreur lors de l\'initiation de l\'appel: $e');
    }
  }

  /// Accepter un appel
  Future<void> acceptCall(String callId) async {
    try {
      print('[CallService] 🔄 acceptCall START');
      print('[CallService]   - callId: $callId');
      print('[CallService] 💾 Mise à jour database: status=active');

      final response = await _supabase
          .from('call_sessions')
          .update({
            'status': 'active',
            'answered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId)
          .select();

      print('[CallService] ✅ Database mise à jour réussie!');
      print('[CallService] 📊 Response: $response');
    } catch (e) {
      print('[CallService] ❌ ERRF CFA acceptCall: $e');
      throw Exception('Erreur lors de l\'acceptation de l\'appel: $e');
    }
  }

  /// Rejeter ou terminer un appel
  Future<void> endCall(String callId) async {
    try {
      await _supabase.from('call_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', callId);
    } catch (e) {
      throw Exception('Erreur lors de la fin de l\'appel: $e');
    }
  }

  /// Écouter les événements d'appel pour un voyage
  Stream<Map<String, dynamic>> watchCallSession(String tripId) {
    return _supabase
        .from('call_sessions')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((sessions) => sessions.isNotEmpty ? sessions.first : {});
  }

  /// Envoyer les données de signalisation WebRTC
  Future<void> sendSignaling({
    required String callId,
    required String type, // 'offer', 'answer', 'ice-candidate'
    required Map<String, dynamic> data,
  }) async {
    try {
      await _supabase.from('call_signaling').insert({
        'call_id': callId,
        'type': type,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de signalisation: $e');
    }
  }

  /// Écouter les événements de signalisation WebRTC
  Stream<List<Map<String, dynamic>>> watchSignaling(String callId) {
    return _supabase
        .from('call_signaling')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId)
        .order('created_at', ascending: true);
  }

  /// Envoyer une notification d'appel au destinataire
  Future<void> _sendCallNotification({
    required String receiverId,
    required String callId,
    required String callerType,
    String? callerName,
  }) async {
    try {
      print('[CallService] 📤 Envoi notification à: $receiverId');
      print('[CallService] CallId: $callId, Type: $callerType');

      // Utiliser RPC avec p_read comme string (bug SDK avec boolean)
      final result = await _supabase.rpc('create_notification', params: {
        'p_user_id': receiverId,
        'p_type': 'incoming_call',
        'p_title': 'Appel entrant',
        'p_message': callerType == 'rider'
            ? 'Votre passager vous appelle'
            : 'Votre chauffeur vous appelle',
        'p_data': {
          'call_id': callId,
          'caller_type': callerType,
          'caller_name': callerName,
        },
        'p_read': 'false', // String au lieu de boolean
      });

      print('[CallService] ✅ Notification créée via RPC: $result');
    } catch (e) {
      print(
          '[CallService] ❌ Erreur lors de l\'envoi de la notification d\'appel: $e');
      rethrow;
    }
  }
}
