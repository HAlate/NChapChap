import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/trip_offer.dart';
import '../../../../services/rider_offer_service.dart';

class WaitingOffersScreen extends ConsumerStatefulWidget {
  final String tripId;

  const WaitingOffersScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<WaitingOffersScreen> createState() =>
      _WaitingOffersScreenState();
}

class _WaitingOffersScreenState extends ConsumerState<WaitingOffersScreen> {
  final RiderOfferService _offersService = RiderOfferService();
  String? _selectedVehicleTypeFilter; // null = tous les véhicules

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripOffer>>(
      stream: _offersService.watchOffersForTrip(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final allOffers = snapshot.data ?? [];

        // Filtrer les offres selon le type de véhicule sélectionné
        // On filtre par le type de véhicule du DRIVER, pas du trip
        final filteredOffers = _selectedVehicleTypeFilter == null
            ? allOffers
            : allOffers
                .where((offer) =>
                    offer.driverVehicleType == _selectedVehicleTypeFilter)
                .toList();

        print(
            'DEBUG WaitingOffers: Received ${allOffers.length} offers, showing ${filteredOffers.length} after filter');

        // DEBUG: Affiche les coordonnées du passager (point de départ du trajet)
        if (allOffers.isNotEmpty) {
          final firstOffer = allOffers.first;
          print(
              '[DEBUG] Passenger coordinates (Trip Origin): Lat=${firstOffer.departureLat}, Lng=${firstOffer.departureLng}');
        }

        return _buildOffersScreen(filteredOffers, allOffers.length);
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres de chauffeurs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres de chauffeurs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erreur: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersScreen(List<TripOffer> offers, int totalOffers) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres de chauffeurs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          _buildVehicleFilter(totalOffers),
          const SizedBox(width: 8),
        ],
      ),
      body: offers.isEmpty ? _buildEmptyState() : _buildOffersList(offers),
    );
  }

  Widget _buildVehicleFilter(int totalOffers) {
    final vehicleTypes = [
      {
        'value': null,
        'label': 'Tous ($totalOffers)',
        'icon': Icons.filter_list
      },
      {'value': 'moto', 'label': 'Moto', 'icon': Icons.two_wheeler},
      {
        'value': 'car_economy',
        'label': 'Économique',
        'icon': Icons.directions_car
      },
      {
        'value': 'car_standard',
        'label': 'Standard',
        'icon': Icons.directions_car_outlined
      },
      {'value': 'car_premium', 'label': 'Premium', 'icon': Icons.drive_eta},
      {'value': 'suv', 'label': 'SUV', 'icon': Icons.airport_shuttle},
      {'value': 'minibus', 'label': 'Minibus', 'icon': Icons.directions_bus},
    ];

    return PopupMenuButton<String?>(
      icon: Icon(
        _selectedVehicleTypeFilter == null
            ? Icons.filter_list
            : Icons.filter_list_alt,
        color: _selectedVehicleTypeFilter == null
            ? Colors.black
            : AppTheme.primaryOrange,
      ),
      tooltip: 'Filtrer par véhicule',
      onSelected: (value) {
        setState(() {
          _selectedVehicleTypeFilter = value;
        });
      },
      itemBuilder: (context) => vehicleTypes.map((type) {
        final isSelected = _selectedVehicleTypeFilter == type['value'];
        return PopupMenuItem<String?>(
          value: type['value'] as String?,
          child: Row(
            children: [
              Icon(
                type['icon'] as IconData,
                size: 20,
                color: isSelected ? AppTheme.primaryOrange : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(
                type['label'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryOrange : Colors.black,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                const Icon(Icons.check,
                    color: AppTheme.primaryOrange, size: 20),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'En attente d\'offres...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les chauffeurs à proximité vont bientôt voir votre demande',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildOffersList(List<TripOffer> offers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return _OfferCard(
          offer: offer,
          onTap: () => _navigateToNegotiation(offer),
          timeAgo: _getTimeAgo(offer.createdAt),
        ).animate().fadeIn(delay: (100 * index).ms);
      },
    );
  }

  void _handleSelectDriver(TripOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmationModal(
        offer: offer,
        onAccept: () => _acceptOffer(offer),
        onNegotiate: () => _navigateToNegotiation(offer),
      ),
    );
  }

  Future<void> _acceptOffer(TripOffer offer) async {
    try {
      // Debug: Afficher toutes les informations de l'offre
      print('[WAITING_OFFERS] Accepting offer with data:');
      print('[WAITING_OFFERS] - driverId: ${offer.driverId}');
      print('[WAITING_OFFERS] - driverName: ${offer.driverName}');
      print('[WAITING_OFFERS] - driverRating: ${offer.driverRating}');
      print('[WAITING_OFFERS] - driverTotalTrips: ${offer.driverTotalTrips}');
      print(
          '[WAITING_OFFERS] - driverVehiclePlate: ${offer.driverVehiclePlate}');
      print('[WAITING_OFFERS] - offeredPrice: ${offer.offeredPrice}');

      await _offersService.acceptOffer(
        offer.id,
        tripId: offer.tripId,
        agreedPrice: offer.offeredPrice,
      );

      if (mounted) {
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Offre acceptée avec succès! Le chauffeur a été notifié.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Naviguer vers l'écran de tracking avec toutes les informations
        final trackingData = {
          'driver': {
            'id': offer.driverId,
            'full_name': offer.driverName ?? 'Chauffeur',
            'rating': offer.driverRating ?? 5.0,
            'total_trips': offer.driverTotalTrips ?? 0,
            'vehicle_plate': offer.driverVehiclePlate ?? '-',
          },
          'departure': offer.departure ?? '',
          'destination': offer.destination ?? '',
          'price': offer.offeredPrice,
          'tripId': offer.tripId,
          'departure_lat': offer.departureLat ?? 0.0,
          'departure_lng': offer.departureLng ?? 0.0,
          'driverLatAtOffer': offer.driverLatAtOffer ?? 0.0,
          'driverLngAtOffer': offer.driverLngAtOffer ?? 0.0,
          'destination_lat': offer.destinationLat ?? 0.0,
          'destination_lng': offer.destinationLng ?? 0.0,
        };

        print(
            '[WAITING_OFFERS] Navigating to tracking with data: $trackingData');
        context.go('/tracking', extra: trackingData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToNegotiation(TripOffer offer) {
    context.push(
      '/negotiation/${offer.id}',
      extra: {
        'trip_id': widget.tripId,
        'offered_price': offer.offeredPrice,
        'counter_price': offer.counterPrice,
        'final_price': offer.finalPrice,
        'status': offer.status,
        'eta_minutes': offer.etaMinutes,
        'driver_id': offer.driverId,
        'driver': {
          'id': offer.driverId,
          'full_name': offer.driverName,
          'rating': offer.driverRating ?? 5.0,
          'total_trips': offer.driverTotalTrips ?? 0,
          'vehicle_type': offer.vehicleType,
        },
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}

class _OfferCard extends StatelessWidget {
  final TripOffer offer;
  final VoidCallback onTap;
  final String timeAgo;

  const _OfferCard({
    required this.offer,
    required this.onTap,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primaryOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.driverName ?? 'Chauffeur',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${offer.driverRating?.toStringAsFixed(1) ?? '5.0'}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '• ${offer.driverTotalTrips ?? 0} courses',
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${offer.offeredPrice} F',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Arrivée dans ${offer.etaMinutes} min',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offer.vehicleType ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sélectionner',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationModal extends StatelessWidget {
  final TripOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onNegotiate;

  const _ConfirmationModal({
    required this.offer,
    required this.onAccept,
    required this.onNegotiate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confirmer le chauffeur?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primaryOrange,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName ?? 'Chauffeur',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${offer.driverRating?.toStringAsFixed(1) ?? '5.0'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${offer.driverTotalTrips ?? 0} courses',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prix proposé:',
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      '${offer.offeredPrice}F CFA',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Arrivée estimée:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${offer.etaMinutes} minutes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAccept();
              },
              icon: const Icon(Icons.check_circle),
              label: Text('Accepter ${offer.offeredPrice}F'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onNegotiate();
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Contre-proposer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                side: const BorderSide(color: AppTheme.primaryOrange, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
