import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class NoShowService {
  /// Signaler un No Show (passager signale chauffeur absent)
  static Future<Map<String, dynamic>> reportNoShow({
    required String tripId,
    required String reportedBy,
    required String reportedUser,
    required String userType, // 'rider' ou 'driver'
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/no-show/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trip_id': tripId,
          'reporter_id': reportedBy,
          'reported_user_id': reportedUser,
          'user_type': userType,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors du signalement: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer les signalements de l'utilisateur
  static Future<List<dynamic>> getMyReports(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/no-show/my-reports?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as List<dynamic>;
      } else {
        throw Exception('Erreur lors de la récupération des signalements');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer les pénalités actives
  static Future<List<dynamic>> getMyPenalties(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/no-show/my-penalties?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as List<dynamic>;
      } else {
        throw Exception('Erreur lors de la récupération des pénalités');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Vérifier si un utilisateur est restreint
  static Future<Map<String, dynamic>> checkRestriction(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/no-show/check-restriction/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de la vérification de restriction');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }
}
