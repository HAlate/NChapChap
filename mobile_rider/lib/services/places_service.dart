import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place.dart';
import 'mapbox_geocoding_service.dart';
import 'geocode_cache_service.dart';

/// Un service pour interagir avec Mapbox Geocoding (avec cache).
class PlacesService {
  final String _apiKey;
  late final MapboxGeocodingService _mapboxGeocoding;
  late final GeocodeCacheService _cache;

  PlacesService(this._apiKey) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken == null) {
      throw Exception("Clé Mapbox non trouvée dans le fichier .env");
    }
    _mapboxGeocoding = MapboxGeocodingService(mapboxToken);
    _cache = GeocodeCacheService();
  }

  /// Récupère les suggestions d'autocomplétion pour une requête donnée (utilise Mapbox avec cache).
  Future<List<Place>> getAutocomplete(String query, String sessionToken,
      {double? latitude, double? longitude}) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Vérifier le cache d'abord (une seule place pour forward geocoding)
      final cachedPlace = await _cache.getFromCache(query);

      if (cachedPlace != null) {
        print('[PlacesService] Using cached autocomplete result');
        return [cachedPlace];
      }

      // Sinon, appeler Mapbox
      LatLng? proximity;
      if (latitude != null && longitude != null) {
        proximity = LatLng(latitude, longitude);
      }

      final results = await _mapboxGeocoding.searchPlaces(
        query,
        proximity: proximity,
        language: 'fr',
        limit: 5,
      );

      // Sauvegarder le premier résultat dans le cache
      if (results.isNotEmpty) {
        await _cache.saveToCache(query, results.first);
      }

      return results;
    } catch (e) {
      print('[PlacesService] Autocomplete error: $e');
      throw Exception('Failed to load place suggestions: $e');
    }
  }

  /// Récupère les détails d'un lieu (y compris les coordonnées) à partir de son placeId (utilise Mapbox).
  Future<Place> getPlaceDetails(String placeId, String sessionToken) async {
    // Avec Mapbox, le placeId contient déjà toutes les informations
    // Cette méthode peut être simplifiée ou maintenue pour la compatibilité
    // Nous retournons directement le lieu si déjà complet via autocomplete

    // Si nécessaire, on pourrait implémenter une recherche par ID Mapbox
    // Pour l'instant, on suppose que les infos sont déjà disponibles
    throw UnimplementedError(
        'getPlaceDetails with Mapbox: Use searchPlaces directly or store complete Place data');
  }

  /// Trouve le nom d'un lieu à partir de ses coordonnées (Reverse Geocoding - utilise Mapbox avec cache).
  Future<Place> getPlaceDetailsFromLatLng(
      {required double latitude, required double longitude}) async {
    try {
      // Vérifier le cache d'abord
      final cachedPlace = await _cache.getReverseGeocodeFromCache(
        latitude,
        longitude,
      );

      if (cachedPlace != null) {
        print('[PlacesService] Using cached reverse geocode result');
        return cachedPlace;
      }

      // Sinon, appeler Mapbox
      final place = await _mapboxGeocoding.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
        language: 'fr',
      );

      // Sauvegarder dans le cache si valide
      if (place.placeId.isNotEmpty) {
        await _cache.saveReverseGeocodeToCache(latitude, longitude, place);
      }

      return place;
    } catch (e) {
      print('[PlacesService] Reverse geocode error: $e');
      throw Exception('Failed to get place from coordinates: $e');
    }
  }

  /// Calcule la distance entre deux lieux (utilise Mapbox).
  Future<String> getDistance(Place origin, Place destination) async {
    try {
      return await _mapboxGeocoding.getDistance(origin, destination);
    } catch (e) {
      print('[PlacesService] Distance error: $e');
      return "N/A";
    }
  }
}
