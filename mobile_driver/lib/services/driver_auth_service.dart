import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DriverAuthService {
  static const _storage = FlutterSecureStorage();
  static const String baseUrl = 'http://10.0.2.2:3001/api';

  static Future<bool> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('baseUrl/users/login'),
      headers: {'Content-Type': 'application/json'},
      body:
          json.encode({'phone': phone, 'password': password, 'role': 'driver'}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['token'] != null) {
        await _storage.write(key: 'driver_token', value: data['token']);
        return true;
      }
    }
    return false;
  }

  static Future<bool> register(String phone, String password) async {
    final response = await http.post(
      Uri.parse('baseUrl/users/register'),
      headers: {'Content-Type': 'application/json'},
      body:
          json.encode({'phone': phone, 'password': password, 'role': 'driver'}),
    );
    return response.statusCode == 200;
  }

  static Future<int?> getUserIdFromToken(String token) async {
    // Décoder le JWT (non sécurisé, pour démo)
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = json.decode(payload);
      return data['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'driver_token');
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'driver_token');
  }
}
