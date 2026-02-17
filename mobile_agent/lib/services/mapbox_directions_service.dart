import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Service pour utiliser l'API Mapbox Directions
class MapboxDirectionsService {
  final String _accessToken;
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  MapboxDirectionsService(this._accessToken);

  /// Obtient l'itinéraire entre deux points
  /// Retourne une Map contenant distance, duration et les points de la polyline
  Future<Map<String, dynamic>> getRoute({
    required LatLng origin,
    required LatLng destination,
    String profile =
        'driving-traffic', // driving, driving-traffic, walking, cycling
  }) async {
    try {
      final String coordinates =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final String url =
          '$_baseUrl/$profile/$coordinates?access_token=$_accessToken&geometries=geojson&overview=full&steps=true';

      print('[MapboxDirections] Request URL: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final legs = route['legs'][0];

          // Convertir les coordonnées GeoJSON en LatLng
          final List<dynamic> coordinates = geometry['coordinates'];
          final List<LatLng> polylinePoints = coordinates
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();

          return {
            'distance': legs['distance'], // en mètres
            'duration': legs['duration'], // en secondes
            'distance_text': _formatDistance(legs['distance']),
            'duration_text': _formatDuration(legs['duration']),
            'polyline_points': polylinePoints,
            'steps': legs['steps'], // Instructions détaillées
          };
        } else {
          throw Exception('No route found: ${data['code']}');
        }
      } else {
        throw Exception(
            'Mapbox API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[MapboxDirections] Error: $e');
      rethrow;
    }
  }

  /// Obtient plusieurs itinéraires alternatifs
  Future<List<Map<String, dynamic>>> getAlternativeRoutes({
    required LatLng origin,
    required LatLng destination,
    int alternatives = 2,
  }) async {
    try {
      final String coordinates =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final String url =
          '$_baseUrl/driving-traffic/$coordinates?access_token=$_accessToken&geometries=geojson&overview=full&alternatives=$alternatives';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null) {
          return (data['routes'] as List).map((route) {
            final geometry = route['geometry'];
            final legs = route['legs'][0];
            final List<dynamic> coordinates = geometry['coordinates'];
            final List<LatLng> polylinePoints = coordinates
                .map((coord) => LatLng(coord[1] as double, coord[0] as double))
                .toList();

            return {
              'distance': legs['distance'],
              'duration': legs['duration'],
              'distance_text': _formatDistance(legs['distance']),
              'duration_text': _formatDuration(legs['duration']),
              'polyline_points': polylinePoints,
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('[MapboxDirections] Error getting alternatives: $e');
      return [];
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double seconds) {
    final int minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final int hours = minutes ~/ 60;
      final int remainingMinutes = minutes % 60;
      return '$hours h $remainingMinutes min';
    }
  }
}
