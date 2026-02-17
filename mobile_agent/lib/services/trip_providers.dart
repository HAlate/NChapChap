import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/driver_offer_service.dart';

// 1. Provider pour le service
final tripOfferServiceProvider = Provider((ref) => DriverOfferService());

// 2. StreamProvider pour observer les courses disponibles à proximité
// CORRECTION: Le provider ne dépend plus que du `vehicleType`.
// La position est gérée par le service lui-même.
final availableTripsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, vehicleType) {
  final tripOfferService = ref.watch(tripOfferServiceProvider);
  // On passe la `ref` du provider au service pour qu'il puisse écouter d'autres providers.
  return tripOfferService.watchAvailableTrips(vehicleType, ref);
});
