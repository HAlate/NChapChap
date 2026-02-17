import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

/// Provider pour activer/désactiver le mode test
final testModeProvider = StateProvider<bool>((ref) => false);

/// Provider pour la position de test simulée
final testPositionProvider = StateProvider<Position?>((ref) => null);

/// Provider pour les coordonnées de test du pickup
final testPickupProvider = StateProvider<Map<String, double>?>((ref) => null);

/// Provider pour les coordonnées de test de la destination
final testDestinationProvider =
    StateProvider<Map<String, double>?>((ref) => null);

/// Classe utilitaire pour générer des positions GPS fictives
class TestPositionGenerator {
  /// Génère une position GPS fictive
  static Position createTestPosition({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    double altitude = 0.0,
    double heading = 0.0,
    double speed = 0.0,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: altitude,
      heading: heading,
      speed: speed,
      speedAccuracy: 1.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
  }

  /// Simule un déplacement progressif entre deux points
  static Position moveTowards({
    required Position current,
    required double targetLat,
    required double targetLng,
    double stepMeters = 50.0, // Distance de déplacement par étape
  }) {
    // Calculer la direction
    final deltaLat = targetLat - current.latitude;
    final deltaLng = targetLng - current.longitude;
    final distance = _calculateDistance(
      current.latitude,
      current.longitude,
      targetLat,
      targetLng,
    );

    // Si on est proche de la destination, retourner la destination exacte
    if (distance < stepMeters) {
      return createTestPosition(
        latitude: targetLat,
        longitude: targetLng,
        speed: 5.0, // ~18 km/h
      );
    }

    // Calculer le nouveau point en se déplaçant de stepMeters vers la cible
    final ratio = stepMeters / distance;
    final newLat = current.latitude + (deltaLat * ratio);
    final newLng = current.longitude + (deltaLng * ratio);

    return createTestPosition(
      latitude: newLat,
      longitude: newLng,
      speed: 5.0, // ~18 km/h
    );
  }

  /// Calcule la distance entre deux points en mètres
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // en mètres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }
}
