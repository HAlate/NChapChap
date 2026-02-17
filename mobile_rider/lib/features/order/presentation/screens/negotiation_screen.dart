import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/place.dart';
import '../../../../services/trip_service.dart';

// --- Providers ---

final tripServiceProvider = Provider((ref) => TripService());

final tripOffersProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tripId) {
  return ref.watch(tripServiceProvider).watchTripOffers(tripId);
});

class NegotiationScreen extends ConsumerStatefulWidget {
  final Place departure;
  final Place destination;
  final String vehicleType;
  final String tripId;

  const NegotiationScreen({
    super.key,
    required this.departure,
    required this.destination,
    required this.vehicleType,
    required this.tripId,
  });

  @override
  ConsumerState<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends ConsumerState<NegotiationScreen> {
  String _getVehicleLabel() {
    switch (widget.vehicleType) {
      case 'moto-taxi':
        return 'Moto';
      case 'tricycle':
        return 'Tricycle';
      case 'taxi':
        return 'Voiture';
      default:
        return 'Véhicule';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final offersAsync = ref.watch(tripOffersProvider(widget.tripId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Offres des chauffeurs (${_getVehicleLabel()})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Annuler la recherche',
            onPressed: () async {
              // TODO: Ajouter la logique pour annuler la course
              context.go('/home');
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Animate(
                effects: const [
                  FadeEffect(),
                  SlideEffect(begin: Offset(0, -0.1))
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppTheme.primaryOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.departure.address,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.destination.address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Expanded(
              child: offersAsync.when(
                data: (offers) {
                  if (offers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            'Recherche de chauffeurs...',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '${offers.length} offre${offers.length > 1 ? 's' : ''} disponible${offers.length > 1 ? 's' : ''}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn().scale(),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: offers.length,
                          itemBuilder: (context, index) {
                            final offer = offers[index];
                            final driver =
                                offer['driver'] as Map<String, dynamic>?;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Material(
                                elevation: isDark ? 0 : 2,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () {
                                    ref
                                        .read(tripServiceProvider)
                                        .selectOffer(offerId: offer['id']);
                                    context.push(
                                      '/negotiation-detail/${offer['id']}',
                                      extra: {
                                        'offer': offer,
                                        'tripId': widget.tripId,
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.surfaceDark
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: isDark
                                          ? Border.all(color: Colors.grey[800]!)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryOrange
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            size: 30,
                                            color: AppTheme.primaryOrange,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      driver?['full_name'] ??
                                                          'Chauffeur',
                                                      style: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.star,
                                                          color: Colors.amber,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          '${(driver?['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A'}',
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${(driver?['total_trips'] as int?) ?? 0} trajets',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.textTheme
                                                      .bodySmall?.color,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color:
                                                        AppTheme.primaryOrange,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${offer['eta_minutes']} min',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: AppTheme
                                                          .primaryOrange,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    '${offer['offered_price']} F',
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppTheme
                                                          .primaryOrange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: (100 + index * 100).ms)
                                  .slideY(begin: 0.3, end: 0),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
