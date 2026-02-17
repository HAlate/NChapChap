import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> login(String phone, String password) async {
    try {
      // Nettoyer le téléphone (garder uniquement les chiffres)
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final email = 'driver_$cleanPhone@uumo.app';

      print('🔐 Tentative de connexion driver avec: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } catch (e) {
      print('❌ Erreur de connexion: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
    required String vehicleType,
    required String vehiclePlate,
    String? licenseNumber,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final email = 'driver_$cleanPhone@uumo.app';

      // Créer l'utilisateur dans Supabase Auth avec métadonnées
      // Le trigger handle_new_user() créera automatiquement l'entrée dans users
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'phone': phone,
          'full_name': fullName,
          'user_type': 'driver',
        },
      );

      if (authResponse.user == null) {
        throw Exception('Erreur lors de la création du compte');
      }

      final userId = authResponse.user!.id;

      // Attendre que la session soit établie
      await Future.delayed(const Duration(milliseconds: 500));

      // Créer le profil driver
      await _supabase.from('driver_profiles').insert({
        'id': userId,
        'vehicle_type': vehicleType,
        'vehicle_plate': vehiclePlate,
        'license_number': licenseNumber,
        'is_available': false,
        'rating_average': 5.0,
        'total_trips': 0,
        'total_deliveries': 0,
      });

      return true;
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  String? getUserId() {
    return _supabase.auth.currentUser?.id;
  }

  bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
