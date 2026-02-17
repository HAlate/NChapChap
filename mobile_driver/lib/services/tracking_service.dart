import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show cos, sin, sqrt, asin;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'mapbox_directions_service.dart';
import 'route_cache_service.dart';

class TrackingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final MapboxDirectionsService _mapboxDirections;
  late final RouteCacheService _routeCache;

  // Vitesse moyenne de déplacement en km/h (pour calcul ETA)
  static const double _averageSpeedKmH = 10.0;

  TrackingService() {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken == null) {
      throw Exception("Clé Mapbox non trouvée dans le fichier .env");
    }
    _mapboxDirections = MapboxDirectionsService(mapboxToken);
    _routeCache = RouteCacheService();
  }

  /// Met à jour la position actuelle du chauffeur dans la base de données.
  Future<void> updateDriverLocation(Position position) async {
    final driverId = _supabase.auth.currentUser?.id;
    if (driverId == null) {
      print('[TrackingService] WARNING: No user ID, cannot update location');
      return;
    }

    print(
        '[TrackingService] Updating driver location: Lat=${position.latitude}, Lng=${position.longitude}');

    try {
      await _supabase.from('driver_profiles').update({
        'current_lat': position.latitude,
        'current_lng': position.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', driverId);

      print('[TrackingService] Location updated successfully in database');
    } catch (e) {
      print('[TrackingService] ERROR updating location: $e');
    }
  }

  /// Met à jour le statut de la course.
  Future<void> updateTripStatus(String tripId, String status) async {
    await _supabase.from('trips').update({
      'status': status,
    }).eq('id', tripId);
  }

  /// Démarre la course et déduit un jeton au chauffeur
  Future<void> startTripWithTokenDeduction(String tripId) async {
    print(
        '[TrackingService] startTripWithTokenDeduction called with tripId: $tripId');

    final driverId = _supabase.auth.currentUser?.id;
    if (driverId == null) {
      print('[TrackingService] ERROR: Driver not authenticated');
      throw Exception('Driver not authenticated');
    }

    print('[TrackingService] Driver ID: $driverId');
    print('[TrackingService] Calling Edge Function...');

    try {
      final response = await _supabase.functions.invoke(
        'trip',
        body: {
          'action': 'start',
          'trip_id': tripId,
          'driver_id': driverId,
        },
      );

      print('[TrackingService] Response status: ${response.status}');
      print('[TrackingService] Response data: ${response.data}');

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Failed to start trip';
        print('[TrackingService] ERROR: $error');
        throw Exception(error);
      }

      print('[TrackingService] Trip started successfully');
    } catch (e) {
      print('[TrackingService] ERROR: $e');
      rethrow;
    }
  }

  /// Notifie le passager que le chauffeur est arrivé (notification manuelle).
  /// Met à jour le champ 'driver_arrived_notification' dans la base de données.
  Future<void> notifyRiderDriverArrived(String tripId) async {
    print(
        '[TRACKING_SERVICE] 📢 Sending driver arrived notification for trip: $tripId');
    final timestamp = DateTime.now().toIso8601String();
    print('[TRACKING_SERVICE] Timestamp: $timestamp');

    await _supabase.from('trips').update({
      'driver_arrived_notification': timestamp,
    }).eq('id', tripId);

    print('[TRACKING_SERVICE] ✅ Notification sent successfully');
  }

  /// Écoute les changements de statut d'une course.
  Stream<Map<String, dynamic>> watchTrip(String tripId) {
    print('[TRACKING_SERVICE] 👀 Setting up stream for trip: $tripId');
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((maps) {
          print(
              '[TRACKING_SERVICE] 🔄 Stream update received: ${maps.length} items');
          if (maps.isNotEmpty) {
            print('[TRACKING_SERVICE] Trip data: ${maps.first}');
          }
          return maps.first;
        });
  }

  /// Surveille en temps réel les nouvelles courses disponibles (statut 'pending').
  Stream<List<Map<String, dynamic>>> watchAvailableTrips() {
    // TODO: Ajouter un filtre par type de véhicule si nécessaire.
    // Par exemple: .eq('vehicle_type', driver.vehicleType)
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  /// Récupère les points de l'itinéraire entre deux coordonnées (utilise Mapbox avec cache).
  Future<List<LatLng>> getPolylinePoints(
      LatLng origin, LatLng destination) async {
    try {
      // Vérifier le cache d'abord
      final cachedRoute = await _routeCache.getFromCache(
        origin,
        destination,
      );

      if (cachedRoute != null) {
        print('[TrackingService] Using cached route');
        return cachedRoute['polyline_points'] as List<LatLng>;
      }

      // Sinon, appeler Mapbox
      final route = await _mapboxDirections.getRoute(
        origin: origin,
        destination: destination,
      );

      if (route['polyline_points'] != null) {
        // Sauvegarder dans le cache
        await _routeCache.saveToCache(
          origin,
          destination,
          route,
        );

        return route['polyline_points'] as List<LatLng>;
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'itinéraire Mapbox: $e');
    }
    return [];
  }

  /// Récupère la route complète avec les instructions de navigation
  Future<Map<String, dynamic>> getRouteWithInstructions(
      LatLng origin, LatLng destination) async {
    try {
      // Vérifier le cache d'abord
      final cachedRoute = await _routeCache.getFromCache(
        origin,
        destination,
      );

      if (cachedRoute != null) {
        print('[TrackingService] Using cached route with instructions');
        return cachedRoute;
      }

      // Sinon, appeler Mapbox
      final route = await _mapboxDirections.getRoute(
        origin: origin,
        destination: destination,
      );

      // Sauvegarder dans le cache
      await _routeCache.saveToCache(
        origin,
        destination,
        route,
      );

      return route;
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération de la route avec instructions: $e');
      return {};
    }
  }

  /// Calcule la distance à vol d'oiseau entre deux coordonnées (formule de Haversine).
  /// Retourne la distance en kilomètres.
  double calculateDistanceKm(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    final double lat1Rad = point1.latitude * (3.14159265359 / 180.0);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180.0);
    final double deltaLat =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180.0);
    final double deltaLng =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180.0);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadiusKm * c;
  }

  /// Calcule l'ETA (temps estimé d'arrivée) en minutes entre deux positions.
  /// Utilise la distance à vol d'oiseau et une vitesse moyenne de 10 km/h.
  int calculateEtaMinutes(LatLng driverPosition, LatLng passengerPosition) {
    final double distanceKm =
        calculateDistanceKm(driverPosition, passengerPosition);

    // Temps = Distance / Vitesse (en heures)
    final double timeHours = distanceKm / _averageSpeedKmH;

    // Convertir en minutes et arrondir
    final int timeMinutes = (timeHours * 60).round();

    // Minimum 1 minute pour éviter de retourner 0
    return timeMinutes < 1 ? 1 : timeMinutes;
  }

  /// Version alternative avec coordonnées séparées (pour compatibilité).
  int calculateEtaFromCoordinates({
    required double driverLat,
    required double driverLng,
    required double passengerLat,
    required double passengerLng,
  }) {
    return calculateEtaMinutes(
      LatLng(driverLat, driverLng),
      LatLng(passengerLat, passengerLng),
    );
  }
}
