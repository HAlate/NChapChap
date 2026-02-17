import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour le service de localisation.
final locationServiceProvider = Provider((ref) => LocationService(ref));

/// Provider qui expose la position actuelle du chauffeur.
/// Les autres parties de l'application peuvent écouter ce provider.
final driverPositionProvider = StateProvider<Position?>((ref) => null);

class LocationService {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationService(this._ref);

  bool get isTracking => _positionStreamSubscription != null;

  Future<void> startTracking() async {
    if (isTracking) {
      print('[LocationService] Tracking is already active.');
      return;
    }

    // 1. Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Permission de localisation refusée.');
      }
    }

    // 2. Tenter d'obtenir une position initiale rapidement pour un démarrage plus réactif.
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (isTracking)
        return; // Vérifie si stopTracking a été appelé pendant l'attente
      print(
          '[LocationService] Initial position obtained: ${initialPosition.latitude}');
      _ref.read(driverPositionProvider.notifier).state = initialPosition;
      _updateDriverLocationInDb(initialPosition);
    } catch (e) {
      print(
          '[LocationService] Could not get initial position quickly: $e. Waiting for stream.');
    }

    print('[LocationService] Starting location tracking...');
    // 3. Démarrer le stream de positions pour les mises à jour continues.
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Mise à jour tous les 50 mètres
      ),
    ).listen((position) {
      print(
          '[LocationService] New position: ${position.latitude}, ${position.longitude}');
      // 4. Mettre à jour le provider d'état global
      _ref.read(driverPositionProvider.notifier).state = position;
      // 5. Mettre à jour la base de données
      _updateDriverLocationInDb(position);
    });
  }

  void stopTracking() {
    print('[LocationService] Stopping location tracking.');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _ref.read(driverPositionProvider.notifier).state = null;
  }

  Future<void> _updateDriverLocationInDb(Position position) async {
    final driverId = _supabase.auth.currentUser?.id;
    if (driverId == null) return;

    await _supabase.from('driver_profiles').update({
      'current_lat': position.latitude,
      'current_lng': position.longitude,
      'location_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);
  }
}
