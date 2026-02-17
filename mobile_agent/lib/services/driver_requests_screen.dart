import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../models/trip.dart';
import 'trip_providers.dart';

// Provider pour la position actuelle du chauffeur en temps réel
final driverPositionProvider = StreamProvider<Position>((ref) async* {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Le service de localisation est désactivé.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Les permissions de localisation sont refusées.');
    }
  }

  yield* Geolocator.getPositionStream();
});

class DriverRequestsScreen extends ConsumerWidget {
  // Le type de véhicule du chauffeur connecté.
  // Ceci devrait provenir du profil du chauffeur.
  final String vehicleType = 'moto'; // Exemple: 'moto', 'voiture', etc.

  const DriverRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On récupère la position en temps réel du chauffeur
    final asyncDriverPosition = ref.watch(driverPositionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelles demandes'),
        centerTitle: true,
      ),
      // On attend que la position soit disponible avant de chercher les courses
      body: asyncDriverPosition.when(
        data: (driverPosition) {
          // Une fois la position obtenue, on écoute le StreamProvider des courses
          // en lui passant les deux paramètres requis.
          final asyncTrips =
              ref.watch(availableTripsStreamProvider(vehicleType));

          return asyncTrips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Erreur de chargement des courses: $error'),
            ),
            data: (trips) {
              if (trips.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_off_outlined,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune demande pour le moment',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vous serez notifié des nouvelles courses.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Affichage de la liste des courses
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final tripData = trips[index];
                  return TripRequestCard(trip: Trip.fromJson(tripData));
                },
              );
            },
          );
        },
        // État de chargement initial
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Recherche de courses...'),
            ],
          ),
        ),
        // État d'erreur
        error: (error, stack) => Center(
          child: Text('Erreur de localisation: $error'),
        ),
      ),
    );
  }
}

class TripRequestCard extends StatelessWidget {
  final Trip trip;

  const TripRequestCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Naviguer vers l'écran de détail pour faire une offre
          print('Tapped on trip ID: ${trip.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course vers: ${trip.destination}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Départ: ${trip.origin}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Prix suggéré:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${trip.proposedPrice?.toStringAsFixed(0) ?? 'N/A'}F CFA',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
