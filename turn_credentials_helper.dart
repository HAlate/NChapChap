// ⚠️ FICHIER DE DOCUMENTATION/EXEMPLE - NE PAS EXÉCUTER DIRECTEMENT
// Ce fichier est une référence pour la configuration TURN future.
// Pour l'utiliser, copiez-le dans mobile_driver/lib/ ou mobile_rider/lib/
// et ajoutez 'crypto: ^3.0.3' dans pubspec.yaml

/// Helper pour générer les credentials TURN côté client
/// À UTILISER UNIQUEMENT POUR LES TESTS
/// En production, utilisez l'Edge Function Supabase

// ignore_for_file: unused_import, directives_ordering
import 'dart:convert';
// import 'package:crypto/crypto.dart'; // Décommenter si copié dans un projet Flutter

class TurnCredentialsHelper {
  /// Secret partagé avec le serveur TURN
  /// ⚠️ NE JAMAIS mettre en dur en production!
  /// Utilisez une Edge Function Supabase à la place
  static const String turnSecret = 'VOTRE_SECRET_ICI';

  /// Adresse de votre serveur TURN
  static const String turnServer = 'VOTRE_IP_OU_DOMAINE';

  /// Génère un username avec timestamp (valide 24h)
  static String generateUsername() {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000).floor() + 86400;
    return '$timestamp:user';
  }

  /// Génère le mot de passe HMAC-SHA1
  static String generatePassword(String username) {
    // Décommenter quand crypto est installé:
    // final key = utf8.encode(turnSecret);
    // final message = utf8.encode(username);
    // final hmac = Hmac(sha1, key);
    // final digest = hmac.convert(message);
    // return base64.encode(digest.bytes);

    throw UnimplementedError('Installer crypto package d\'abord');
  }

  /// Retourne la configuration ICE servers complète
  static Map<String, dynamic> getIceServers() {
    final username = generateUsername();
    final password = generatePassword(username);

    return {
      'iceServers': [
        // STUN servers (backup)
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },
        // Votre serveur TURN
        {
          'urls': [
            'turn:$turnServer:3478',
            'turn:$turnServer:3478?transport=tcp',
          ],
          'username': username,
          'credential': password,
        },
        // TURN sur TLS (si SSL configuré)
        {
          'urls': 'turns:$turnServer:5349',
          'username': username,
          'credential': password,
        },
      ],
      'sdpSemantics': 'unified-plan',
    };
  }

  /// Configuration pour tests sur même WiFi (STUN seulement)
  static Map<String, dynamic> getLocalTestConfig() {
    return {
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
          ],
        },
      ],
      'sdpSemantics': 'unified-plan',
    };
  }
}

// Exemple d'utilisation dans WebRTCService:

/*
class WebRTCService {
  late Map<String, dynamic> _configuration;
  
  Future<void> initialize({bool useLocalTest = false}) async {
    // Pour tests sur même WiFi
    if (useLocalTest) {
      _configuration = TurnCredentialsHelper.getLocalTestConfig();
    } 
    // Pour production avec votre serveur TURN
    else {
      _configuration = TurnCredentialsHelper.getIceServers();
    }
    
    _peerConnection = await createPeerConnection(_configuration);
    // ... reste du code
  }
}
*/

// SOLUTION PRODUCTION RECOMMANDÉE:
// Créez une Edge Function Supabase pour générer les credentials

/*
class WebRTCService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Future<void> initialize() async {
    // Récupérer credentials depuis le backend (sécurisé)
    try {
      final response = await _supabase.functions.invoke('get-turn-credentials');
      
      if (response.status == 200) {
        final turnData = response.data as Map<String, dynamic>;
        
        _configuration = {
          'iceServers': [
            {'urls': ['stun:stun.l.google.com:19302']},
            {
              'urls': turnData['uris'],
              'username': turnData['username'],
              'credential': turnData['credential'],
            },
          ],
          'sdpSemantics': 'unified-plan',
        };
      } else {
        // Fallback sur STUN seulement
        _configuration = TurnCredentialsHelper.getLocalTestConfig();
      }
    } catch (e) {
      print('[WebRTC] Erreur récupération TURN credentials: $e');
      _configuration = TurnCredentialsHelper.getLocalTestConfig();
    }
    
    _peerConnection = await createPeerConnection(_configuration);
  }
}
*/
