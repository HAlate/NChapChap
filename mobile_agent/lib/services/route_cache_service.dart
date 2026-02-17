import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service de cache pour les itinéraires - adapté à la structure existante
class RouteCacheService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Génère une clé de cache unique basée sur origine/destination
  String _generateCacheKey(LatLng origin, LatLng destination,
      {String profile = 'driving-traffic'}) {
    // Arrondir les coordonnées à 4 décimales (~11m de précision)
    final originLat = (origin.latitude * 10000).round() / 10000;
    final originLng = (origin.longitude * 10000).round() / 10000;
    final destLat = (destination.latitude * 10000).round() / 10000;
    final destLng = (destination.longitude * 10000).round() / 10000;

    final input = 'route:$originLat,$originLng:$destLat,$destLng:$profile';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Récupère une route depuis le cache
  Future<Map<String, dynamic>?> getFromCache(
    LatLng origin,
    LatLng destination, {
    String profile = 'driving-traffic',
  }) async {
    try {
      final cacheKey = _generateCacheKey(origin, destination, profile: profile);
      final fiveMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 5));

      final response = await _supabase
          .from('route_cache')
          .select()
          .eq('cache_key', cacheKey)
          .gte('last_accessed_at', fiveMinutesAgo.toIso8601String())
          .maybeSingle();

      if (response == null) {
        print('[RouteCacheService] Cache miss for route');
        return null;
      }

      print('[RouteCacheService] Cache hit for route');

      // Incrémenter le compteur
      _incrementHitCount(cacheKey);

      // Décoder la polyline
      final polylineString = response['polyline'] as String?;
      final List<LatLng>? polylinePoints =
          polylineString != null ? _decodePolyline(polylineString) : null;

      return {
        'polyline_points': polylinePoints,
        'distance': response['distance_meters'] ?? 0.0,
        'duration': response['duration_seconds'] ?? 0.0,
      };
    } catch (e) {
      print('[RouteCacheService] Error reading cache: $e');
      return null;
    }
  }

  /// Sauvegarde une route dans le cache
  Future<void> saveToCache(
    LatLng origin,
    LatLng destination,
    Map<String, dynamic> routeData, {
    String profile = 'driving-traffic',
  }) async {
    try {
      final cacheKey = _generateCacheKey(origin, destination, profile: profile);

      // Encoder la polyline
      final List<LatLng>? points = routeData['polyline_points'];
      final String? polylineString =
          points != null ? _encodePolyline(points) : null;

      await _supabase.from('route_cache').upsert(
        {
          'cache_key': cacheKey,
          'origin_lat': origin.latitude,
          'origin_lng': origin.longitude,
          'destination_lat': destination.latitude,
          'destination_lng': destination.longitude,
          'profile': profile,
          'polyline': polylineString,
          'distance_meters': routeData['distance'] ?? 0.0,
          'duration_seconds': routeData['duration'] ?? 0.0,
          'hit_count': 1,
          'last_accessed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'cache_key',
      );

      print('[RouteCacheService] Saved route to cache');
    } catch (e) {
      print('[RouteCacheService] Error saving cache: $e');
    }
  }

  /// Incrémente le compteur d'utilisation
  Future<void> _incrementHitCount(String cacheKey) async {
    try {
      await _supabase.rpc('increment_route_cache_hit', params: {
        'cache_key_param': cacheKey,
      });
    } catch (e) {
      print('[RouteCacheService] Error incrementing hit count: $e');
    }
  }

  /// Encode une liste de LatLng en polyline string (JSON simple)
  String _encodePolyline(List<LatLng> points) {
    return json.encode(points.map((p) => [p.latitude, p.longitude]).toList());
  }

  /// Decode une polyline string en liste de LatLng
  List<LatLng> _decodePolyline(String polylineString) {
    try {
      final List<dynamic> decoded = json.decode(polylineString);
      return decoded
          .map((p) => LatLng(p[0] as double, p[1] as double))
          .toList();
    } catch (e) {
      print('[RouteCacheService] Error decoding polyline: $e');
      return [];
    }
  }

  /// Nettoie les entrées anciennes du cache (> 1 jour)
  Future<void> cleanOldCache() async {
    try {
      final oneDayAgo =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      await _supabase
          .from('route_cache')
          .delete()
          .lt('last_accessed_at', oneDayAgo);

      print('[RouteCacheService] Cleaned old cache entries');
    } catch (e) {
      print('[RouteCacheService] Error cleaning cache: $e');
    }
  }

  /// Obtient les statistiques du cache
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final response = await _supabase.rpc('get_route_cache_stats');
      return response as Map<String, dynamic>;
    } catch (e) {
      print('[RouteCacheService] Error getting cache stats: $e');
      return {'total_entries': 0, 'total_hits': 0};
    }
  }
}
