import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../models/place.dart';

/// Service de cache pour le geocoding - adapté à la structure existante
class GeocodeCacheService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Génère une clé de cache unique basée sur la requête
  String _generateCacheKey(String query, {double? lat, double? lng}) {
    final input = 'geocode:$query:${lat ?? ''}:${lng ?? ''}';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Récupère un lieu depuis le cache (recherche forward)
  Future<Place?> getFromCache(String query) async {
    try {
      final cacheKey = _generateCacheKey(query);

      final response = await _supabase
          .from('geocode_cache')
          .select()
          .eq('cache_key', cacheKey)
          .eq('cache_type', 'forward')
          .maybeSingle();

      if (response == null) {
        print('[GeocodeCacheService] Cache miss for: $query');
        return null;
      }

      print('[GeocodeCacheService] Cache hit for: $query');

      // Incrémenter le compteur
      _incrementHitCount(cacheKey);

      return Place(
        placeId: response['place_id'] ?? '',
        name: response['name'] ?? '',
        address: response['formatted_address'] ?? '',
        latitude: response['latitude'] ?? 0.0,
        longitude: response['longitude'] ?? 0.0,
      );
    } catch (e) {
      print('[GeocodeCacheService] Error reading cache: $e');
      return null;
    }
  }

  /// Sauvegarde un lieu dans le cache (recherche forward)
  Future<void> saveToCache(String query, Place place) async {
    try {
      final cacheKey = _generateCacheKey(query);

      await _supabase.from('geocode_cache').upsert(
        {
          'cache_key': cacheKey,
          'cache_type': 'forward',
          'latitude': place.latitude,
          'longitude': place.longitude,
          'place_id': place.placeId,
          'name': place.name,
          'formatted_address': place.address,
          'hit_count': 1,
          'last_accessed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'cache_key',
      );

      print('[GeocodeCacheService] Saved to cache: $query');
    } catch (e) {
      print('[GeocodeCacheService] Error saving cache: $e');
    }
  }

  /// Récupère un lieu depuis le cache par reverse geocoding
  Future<Place?> getReverseGeocodeFromCache(
      double latitude, double longitude) async {
    try {
      // Arrondir les coordonnées à 3 décimales (~111m de précision)
      final roundedLat = (latitude * 1000).round() / 1000;
      final roundedLng = (longitude * 1000).round() / 1000;

      final cacheKey =
          _generateCacheKey('reverse', lat: roundedLat, lng: roundedLng);

      final response = await _supabase
          .from('geocode_cache')
          .select()
          .eq('cache_key', cacheKey)
          .eq('cache_type', 'reverse')
          .maybeSingle();

      if (response == null) {
        print(
            '[GeocodeCacheService] Reverse geocode cache miss: $latitude,$longitude');
        return null;
      }

      print(
          '[GeocodeCacheService] Reverse geocode cache hit: $latitude,$longitude');

      // Incrémenter le compteur
      _incrementHitCount(cacheKey);

      return Place(
        placeId: response['place_id'] ?? '',
        name: response['name'] ?? '',
        address: response['formatted_address'] ?? '',
        latitude: response['latitude'] ?? 0.0,
        longitude: response['longitude'] ?? 0.0,
      );
    } catch (e) {
      print('[GeocodeCacheService] Error reading reverse geocode cache: $e');
      return null;
    }
  }

  /// Sauvegarde un lieu dans le cache (reverse geocoding)
  Future<void> saveReverseGeocodeToCache(
      double latitude, double longitude, Place place) async {
    try {
      // Arrondir les coordonnées
      final roundedLat = (latitude * 1000).round() / 1000;
      final roundedLng = (longitude * 1000).round() / 1000;

      final cacheKey =
          _generateCacheKey('reverse', lat: roundedLat, lng: roundedLng);

      await _supabase.from('geocode_cache').upsert(
        {
          'cache_key': cacheKey,
          'cache_type': 'reverse',
          'latitude': roundedLat,
          'longitude': roundedLng,
          'place_id': place.placeId,
          'name': place.name,
          'formatted_address': place.address,
          'hit_count': 1,
          'last_accessed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'cache_key',
      );

      print(
          '[GeocodeCacheService] Saved reverse geocode to cache: $latitude,$longitude');
    } catch (e) {
      print('[GeocodeCacheService] Error saving reverse geocode cache: $e');
    }
  }

  /// Incrémente le compteur d'utilisation d'une entrée de cache
  Future<void> _incrementHitCount(String cacheKey) async {
    try {
      await _supabase.rpc('increment_geocode_cache_hit', params: {
        'cache_key_param': cacheKey,
      });
    } catch (e) {
      print('[GeocodeCacheService] Error incrementing hit count: $e');
    }
  }

  /// Nettoie les entrées anciennes du cache (> 30 jours)
  Future<void> cleanOldCache() async {
    try {
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      await _supabase
          .from('geocode_cache')
          .delete()
          .lt('last_accessed_at', thirtyDaysAgo);

      print('[GeocodeCacheService] Cleaned old cache entries');
    } catch (e) {
      print('[GeocodeCacheService] Error cleaning cache: $e');
    }
  }

  /// Obtient les statistiques du cache
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final response = await _supabase.rpc('get_geocode_cache_stats');
      return response as Map<String, dynamic>;
    } catch (e) {
      print('[GeocodeCacheService] Error getting cache stats: $e');
      return {'total_entries': 0, 'total_hits': 0};
    }
  }
}
