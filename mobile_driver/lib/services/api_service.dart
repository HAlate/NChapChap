import 'package:http/http.dart' as http;

class ApiService {
  // Vérifie la validité du token auprès du backend
  static Future<http.Response> checkToken(String token) {
    return http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  // Valider le paiement mobile money par code de confirmation
  static Future<http.Response> validatePayment({
    required int userId,
    required int amount,
    required String codeConfirmation,
  }) {
    return http.post(
      Uri.parse('$baseUrl/users/validate-payment'),
      headers: {'Content-Type': 'application/json'},
      body:
          '{"user_id": $userId, "amount": $amount, "code_confirmation": "$codeConfirmation"}',
    );
  }

  // Proposer un prix pour un trajet (négociation)
  static Future<http.Response> proposePrice({
    required int tripId,
    required int userId,
    required double proposedPrice,
    required String token,
  }) {
    return http.post(
      Uri.parse('$baseUrl/trips/propose-price'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body:
          '{"trip_id": $tripId, "user_id": $userId, "proposed_price": $proposedPrice}',
    );
  }

  static const String baseUrl =
      'http://192.168.3.20:3001/api'; // Utiliser l'IP locale du PC pour accès mobile

  // Login
  static Future<http.Response> login(String phone, String password) {
    return http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: '{"phone": "$phone", "password": "$password"}',
    );
  }

  // Register
  static Future<http.Response> register(String phone, String password) {
    return http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: {'Content-Type': 'application/json'},
      body: '{"phone": "$phone", "password": "$password"}',
    );
  }

  // Récupérer les trajets d'un utilisateur
  static Future<http.Response> getTrips(
      {required int userId, required String token}) {
    return http.get(
      Uri.parse('$baseUrl/trips/user/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  // Créer un trajet
  static Future<http.Response> createTrip({
    required int userId,
    required String origin,
    required double originLat,
    required double originLng,
    required String destination,
    required double destLat,
    required double destLng,
    required String vehicleType,
    required String token,
  }) {
    return http.post(
      Uri.parse('$baseUrl/trips/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body:
          '{"user_id": $userId, "origin": "$origin", "origin_lat": $originLat, "origin_lng": $originLng, "destination": "$destination", "dest_lat": $destLat, "dest_lng": $destLng, "vehicle_type": "$vehicleType"}',
    );
  }
}
