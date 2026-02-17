import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  static const String baseUrl = 'http://192.168.3.20:3001/api';

  Future<AuthResult> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuthResult.success(
          token: data['token'],
          userId: data['user']['id'],
        );
      } else {
        return AuthResult.failure('Identifiants incorrects');
      }
    } catch (e) {
      return AuthResult.failure('Erreur de connexion: $e');
    }
  }

  Future<AuthResult> register({
    required String phone,
    required String password,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phone,
          'password': password,
          'role': 'rider',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return AuthResult.success(
          token: data['token'],
          userId: data['user']['id'],
        );
      } else {
        final error = json.decode(response.body)['error'] ?? 'Erreur';
        return AuthResult.failure(error);
      }
    } catch (e) {
      return AuthResult.failure('Erreur de connexion: $e');
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? token;
  final int? userId;
  final String? error;

  AuthResult._({
    required this.isSuccess,
    this.token,
    this.userId,
    this.error,
  });

  factory AuthResult.success({required String token, required int userId}) {
    return AuthResult._(
      isSuccess: true,
      token: token,
      userId: userId,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
}
