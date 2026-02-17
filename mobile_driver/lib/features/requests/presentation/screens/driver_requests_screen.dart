import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_driver/core/theme/app_theme.dart';
import 'package:mobile_driver/services/driver_offer_service.dart';
import 'package:mobile_driver/services/tracking_service.dart';
import 'package:mobile_driver/widgets/buy_tokens_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_driver/features/requests/presentation/screens/make_offer_screen.dart';

// --- Providers ---

final driverOfferServiceProvider = Provider((ref) => DriverOfferService());
final trackingServiceProvider = Provider((ref) => TrackingService());

// Provider pour surveiller les courses disponibles pour un type de véhicule donné.
// CORRECTION: Le provider ne dépend plus que du type de véhicule.
// La gestion de la position est maintenant interne au service.
final availableTripsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, vehicleType) {
  return ref
      .watch(driverOfferServiceProvider)
      .watchAvailableTrips(vehicleType, ref);
});

// Provider pour récupérer le profil du chauffeur connecté (et donc son type de véhicule)
final driverProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non authentifié');
  }
  final response = await Supabase.instance.client
      .from('driver_profiles')
      .select('vehicle_type')
      .eq('id', userId)
      .maybeSingle();
  return response;
});

class DriverRequestsScreen extends ConsumerStatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  ConsumerState<DriverRequestsScreen> createState() =>
      _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends ConsumerState<DriverRequestsScreen> {
  // État local pour gérer les courses masquées
  final Set<String> _hiddenTripIds = {};

  // Cache pour la position du driver (évite de recalculer à chaque rebuild)
  Position? _cachedDriverPosition;
  DateTime? _lastPositionUpdate;

  @override
  void initState() {
    super.initState();
    _loadDriverPosition();
  }

  // Charge la position une fois et la cache
  Future<void> _loadDriverPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          _cachedDriverPosition = position;
          _lastPositionUpdate = DateTime.now();
        });
      }
    } catch (e) {
      // Position non disponible
    }
  }

  @override
  Widget build(BuildContext context) {
    // On récupère d'abord le profil du chauffeur
    // CORRECTION: On n'a plus besoin de `driverPositionProvider` ici.
    final profileAsync = ref.watch(driverProfileProvider);
    final balanceAsync = ref.watch(tokenBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de courses'),
        centerTitle: true,
        actions: [
          // Affichage du solde de jetons
          balanceAsync.when(
            data: (balance) => GestureDetector(
              onTap: () {
                // Afficher les détails ou naviguer vers l'écran d'achat
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Solde: ${balance.tokensAvailable} jetons disponibles\n'
                      'Total: ${balance.totalTokens} | Utilisés: ${balance.tokensUsed}',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.toll,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${balance.tokensAvailable}',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => Container(
              margin: const EdgeInsets.only(right: 16),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, s) => GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Erreur de chargement du solde: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Réessayer',
                      textColor: Colors.white,
                      onPressed: () {
                        // Force le rechargement du provider
                        ref.invalidate(tokenBalanceProvider);
                      },
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.error_outline, color: Colors.red, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur de chargement du profil: $error'),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
                child: Text(
                    'Profil chauffeur non trouvé. Veuillez compléter votre inscription.'));
          }
          final vehicleType = profile['vehicle_type'] as String?;
          if (vehicleType == null) {
            return const Center(
                child: Text('Type de véhicule non défini sur votre profil.'));
          }

          // Une fois qu'on a le type de véhicule, on écoute les courses disponibles.
          final tripsAsync = ref.watch(availableTripsProvider(vehicleType));

          return tripsAsync.when(
            data: (trips) {
              print(
                  '[DRIVER_REQUESTS] Received ${trips.length} trips from stream');
              // On filtre les courses pour n'afficher que les pertinentes
              final visibleTrips = trips.where((trip) {
                // Condition 1: La course ne doit pas être masquée manuellement
                if (_hiddenTripIds.contains(trip['id'])) {
                  return false;
                }

                // NOTE: Le filtrage par âge est déjà fait dans la vue SQL
                // Pas besoin de filtrer à nouveau ici
                return true;
              }).toList();

              print(
                  '[DRIVER_REQUESTS] After filtering: ${visibleTrips.length} visible trips');

              if (visibleTrips.isEmpty) {
                return const _EmptyTripsView();
              }
              return ListView.builder(
                itemCount: visibleTrips.length,
                // Optimisation: utiliser une clé stable pour éviter les rebuilds inutiles
                itemBuilder: (context, index) {
                  final trip = visibleTrips[index];
                  return _TripRequestCard(
                    key: ValueKey(trip['id']),
                    trip: trip,
                    driverPosition: _cachedDriverPosition,
                    onHide: () =>
                        setState(() => _hiddenTripIds.add(trip['id'])),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Erreur de chargement des courses: $error')),
          );
        },
      ),
    );
  }
}

// Widget statique pour l'état vide
class _EmptyTripsView extends StatelessWidget {
  const _EmptyTripsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune demande disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les nouvelles demandes apparaîtront ici automatiquement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRequestCard extends ConsumerWidget {
  final Map<String, dynamic> trip;
  final Position? driverPosition;
  final VoidCallback onHide;

  const _TripRequestCard({
    super.key,
    required this.trip,
    this.driverPosition,
    required this.onHide,
  });

  void _navigateToMakeOffer(BuildContext context) {
    // Navigation vers l'écran de création d'offre avec la carte
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MakeOfferScreen(
          trip: trip,
          driverPosition: driverPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La fonction SQL retourne maintenant directement 'rider_full_name'
    final fullName = trip['rider_full_name'] as String?;
    final phone = trip['rider_phone'] as String?;
    final riderName = fullName?.isNotEmpty == true
        ? fullName!
        : (phone?.isNotEmpty == true ? phone! : 'Client');
    final theme = Theme.of(context);

    // --- Calcul du temps écoulé ---
    String getTimeAgo(String? createdAtStr) {
      if (createdAtStr == null) return '';
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null) return '';

      final difference = DateTime.now().difference(createdAt);

      if (difference.inSeconds < 60) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return 'Il y a ${difference.inDays}j';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            getTimeAgo(trip['created_at']),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // --- Bouton pour masquer ---
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                      icon: const Icon(Icons.visibility_off_outlined,
                          color: Colors.grey, size: 20),
                      onPressed: onHide),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildTripDetailRow(
              icon: Icons.my_location,
              label: 'Départ',
              value: trip['departure'] ?? 'N/A',
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 12),
            _buildTripDetailRow(
              icon: Icons.location_on,
              label: 'Destination',
              value: trip['destination'] ?? 'N/A',
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToMakeOffer(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Faire une offre',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
