import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show cos, sin, sqrt, asin;
import 'mapbox_directions_service.dart';
import 'route_cache_service.dart';

class TripService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final MapboxDirectionsService _mapboxDirections;
  late final RouteCacheService _routeCache;

  // Vitesse moyenne de déplacement en km/h (pour calcul ETA)
  static const double _averageSpeedKmH = 10.0;

  TripService() {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken == null) {
      throw Exception("Clé Mapbox non trouvée dans le fichier .env");
    }
    _mapboxDirections = MapboxDirectionsService(mapboxToken);
    _routeCache = RouteCacheService();
  }

  Future<Map<String, dynamic>> createTrip({
    required Place departure,
    required Place destination,
    required String vehicleType,
    double? distanceKm,
    String? bookingType,
    DateTime? scheduledTime,
  }) async {
    try {
      // Préparer les paramètres de base
      final params = {
        'p_departure': departure.address,
        'p_departure_lat': departure.latitude,
        'p_departure_lng': departure.longitude,
        'p_destination': destination.address,
        'p_destination_lat': destination.latitude,
        'p_destination_lng': destination.longitude,
        'p_vehicle_type': vehicleType,
        'p_distance_km': distanceKm,
      };

      // Ajouter booking_type si spécifié
      if (bookingType != null) {
        params['p_booking_type'] = bookingType;
      }

      // Ajouter scheduled_time si spécifié
      if (scheduledTime != null) {
        params['p_scheduled_time'] = scheduledTime.toIso8601String();
      }

      // On appelle la fonction RPC `create_new_trip` au lieu d'une insertion directe.
      // Cela permet de contourner les problèmes de RLS pour les triggers.
      final response =
          await _supabase.rpc('create_new_trip', params: params).single();

      return response;
    } catch (e) {
      throw Exception('Erreur lors de la création de la course: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTripOffers(String tripId) async {
    try {
      final response = await _supabase.from('trip_offers').select('''
            *,
            driver:users!trip_offers_driver_id_fkey (
              id,
              full_name,
              phone,
              email
            )
          ''').eq('trip_id', tripId).order('offered_price', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch trip offers: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchTripOffers(String tripId) {
    return _supabase
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('offered_price', ascending: true);
  }

  Future<void> selectOffer({
    required String offerId,
    int? counterPrice,
    String? message,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': 'selected',
      };

      if (counterPrice != null) {
        updates['counter_price'] = counterPrice;
      }

      await _supabase.from('trip_offers').update(updates).eq('id', offerId);

      await _supabase
          .from('trip_offers')
          .update({'status': 'not_selected'})
          .eq(
              'trip_id',
              (await _supabase
                  .from('trip_offers')
                  .select('trip_id')
                  .eq('id', offerId)
                  .single())['trip_id'])
          .neq('id', offerId)
          .eq('status', 'pending');
    } catch (e) {
      throw Exception('Failed to select offer: $e');
    }
  }

  Future<void> acceptOffer({
    required String offerId,
    required String tripId,
    required int finalPrice,
  }) async {
    try {
      // Utilisation d'une fonction RPC pour une transaction atomique et plus sûre.
      await _supabase.rpc('accept_offer_and_update_trip', params: {
        'p_offer_id': offerId,
        'p_trip_id': tripId,
        'p_final_price': finalPrice,
      });
    } catch (e) {
      // L'erreur de Supabase est déjà assez descriptive.
      throw Exception('Erreur lors de l\'acceptation de l\'offre: $e');
    }
  }

  Future<void> rejectOffer(String offerId) async {
    try {
      await _supabase
          .from('trip_offers')
          .update({'status': 'rejected'}).eq('id', offerId);
    } catch (e) {
      throw Exception('Failed to reject offer: $e');
    }
  }

  Future<Map<String, dynamic>> getTrip(String tripId) async {
    try {
      final response = await _supabase.from('trips').select('''
            *,
            driver:users!trips_driver_id_fkey (
              id,
              full_name,
              phone,
              email
            )
          ''').eq('id', tripId).single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch trip: $e');
    }
  }

  Future<void> startTrip(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'started',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to start trip: $e');
    }
  }

  Future<void> completeTrip(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to complete trip: $e');
    }
  }

  Future<void> cancelTrip(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to cancel trip: $e');
    }
  }

  Future<Map<String, dynamic>> getTripById(String tripId) async {
    try {
      final response =
          await _supabase.from('trips').select('*').eq('id', tripId).single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch trip: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRiderTrips() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.from('trips').select('''
            *,
            driver:users!trips_driver_id_fkey (
              id,
              full_name,
              phone,
              email
            )
          ''').eq('rider_id', userId).order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch rider trips: $e');
    }
  }

  /// Surveille les changements sur un trajet spécifique.
  Stream<Map<String, dynamic>> watchTrip(String tripId) {
    print('[TRIP_SERVICE] 👀 Setting up stream for trip: $tripId');
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((maps) {
          print(
              '[TRIP_SERVICE] 🔄 Stream update received: ${maps.length} items');
          if (maps.isEmpty) {
            print('[TRIP_SERVICE] ❌ No trip found with id: $tripId');
            throw Exception('Trip with id $tripId not found.');
          }
          print('[TRIP_SERVICE] Trip data: ${maps.first}');
          return maps.first;
        });
  }

  /// Surveiller une offre spécifique pour voir les mises à jour (contre-contre-offre du driver)
  Stream<Map<String, dynamic>?> watchOffer(String offerId) {
    return _supabase
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('id', offerId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  /// Récupère les points de l'itinéraire entre deux coordonnées (avec cache).
  Future<List<LatLng>> getPolylinePoints(
      LatLng origin, LatLng destination) async {
    try {
      print('[TripService] Getting polyline from $origin to $destination');

      // Vérifier le cache d'abord
      final cachedRoute = await _routeCache.getFromCache(
        origin,
        destination,
      );

      if (cachedRoute != null && cachedRoute['polyline_points'] != null) {
        final points = cachedRoute['polyline_points'] as List<LatLng>;
        print('[TripService] Using cached route with ${points.length} points');
        return points;
      }

      // Sinon, appeler Mapbox
      print('[TripService] Cache miss, calling Mapbox API');
      final route = await _mapboxDirections.getRoute(
        origin: origin,
        destination: destination,
      );

      if (route['polyline_points'] != null) {
        final points = route['polyline_points'] as List<LatLng>;
        print('[TripService] Got ${points.length} points from Mapbox');

        // Sauvegarder dans le cache
        await _routeCache.saveToCache(
          origin,
          destination,
          route,
        );

        return points;
      }

      print('[TripService] No polyline points received from Mapbox');
    } catch (e) {
      debugPrint('[TripService] ERROR getting polyline: $e');
    }
    return [];
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
