import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';

/// Service pour utiliser l'API Mapbox Geocoding
class MapboxGeocodingService {
  final String _accessToken;
  static const String _baseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';

  MapboxGeocodingService(this._accessToken);

  /// Recherche d'adresses (forward geocoding)
  Future<List<Place>> searchPlaces(
    String query, {
    LatLng? proximity,
    String language = 'fr',
    int limit = 5,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      String url =
          '$_baseUrl/${Uri.encodeComponent(query)}.json?access_token=$_accessToken&language=$language&limit=$limit';

      // Ajouter la proximité pour des résultats plus pertinents
      if (proximity != null) {
        url += '&proximity=${proximity.longitude},${proximity.latitude}';
      }

      print('[MapboxGeocoding] Search URL: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((feature) {
          final geometry = feature['geometry'];
          final coordinates = geometry['coordinates'];
          final placeName = feature['place_name'] ?? '';
          final text = feature['text'] ?? '';

          return Place(
            placeId: feature['id'] ?? '',
            name: text,
            address: placeName,
            latitude: coordinates[1] as double,
            longitude: coordinates[0] as double,
          );
        }).toList();
      } else {
        throw Exception('Mapbox Geocoding error: ${response.statusCode}');
      }
    } catch (e) {
      print('[MapboxGeocoding] Search error: $e');
      return [];
    }
  }

  /// Reverse geocoding - Obtenir l'adresse à partir de coordonnées
  Future<Place> reverseGeocode({
    required double latitude,
    required double longitude,
    String language = 'fr',
  }) async {
    try {
      final String url =
          '$_baseUrl/$longitude,$latitude.json?access_token=$_accessToken&language=$language';

      print('[MapboxGeocoding] Reverse URL: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        if (features.isNotEmpty) {
          final feature = features[0];
          final placeName = feature['place_name'] ?? '';
          final text = feature['text'] ?? '';

          // Utiliser place_name qui est plus complet
          final displayName = placeName.isNotEmpty ? placeName : text;

          return Place(
            placeId: feature['id'] ?? '${longitude}_${latitude}',
            name:
                displayName.isNotEmpty ? displayName : 'Position sélectionnée',
            address: placeName,
            latitude: latitude,
            longitude: longitude,
          );
        }
      }

      // Valeur par défaut avec coordonnées formatées
      final coordsName =
          'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
      return Place(
        placeId: '${longitude}_${latitude}',
        name: coordsName,
        address: coordsName,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      print('[MapboxGeocoding] Reverse error: $e');
      final coordsName =
          'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
      return Place(
        placeId: '${longitude}_${latitude}',
        name: coordsName,
        address: coordsName,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  /// Calcule la distance entre deux points (utilise l'API Directions de Mapbox)
  Future<String> getDistance(Place origin, Place destination) async {
    try {
      final String coordinates =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final String url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates?access_token=$_accessToken&overview=false';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final distance = data['routes'][0]['distance'] as double;

          if (distance < 1000) {
            return '${distance.round()} m';
          } else {
            return '${(distance / 1000).toStringAsFixed(1)} km';
          }
        }
      }
      return 'N/A';
    } catch (e) {
      print('[MapboxGeocoding] Distance error: $e');
      return 'N/A';
    }
  }
}
