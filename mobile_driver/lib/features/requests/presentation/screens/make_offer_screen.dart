import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_driver/core/theme/app_theme.dart';
import 'package:mobile_driver/services/driver_offer_service.dart';
import 'package:mobile_driver/services/tracking_service.dart';

// --- Providers ---
final driverOfferServiceProvider = Provider((ref) => DriverOfferService());
final trackingServiceProvider = Provider((ref) => TrackingService());

/// Écran pour faire une offre sur une course avec visualisation sur une carte
class MakeOfferScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> trip;
  final Position? driverPosition;

  const MakeOfferScreen({
    super.key,
    required this.trip,
    this.driverPosition,
  });

  @override
  ConsumerState<MakeOfferScreen> createState() => _MakeOfferScreenState();
}

class _MakeOfferScreenState extends ConsumerState<MakeOfferScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _etaController = TextEditingController();
  bool _isLoading = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeOffer();
  }

  /// Initialise les données de l'offre (ETA automatique)
  void _initializeOffer() {
    final passengerLat = widget.trip['departure_lat'] as double?;
    final passengerLng = widget.trip['departure_lng'] as double?;
    int estimatedEta = 5; // Valeur par défaut

    // Calculer l'ETA si on a les coordonnées
    if (widget.driverPosition != null &&
        passengerLat != null &&
        passengerLng != null) {
      final trackingService = ref.read(trackingServiceProvider);
      estimatedEta = trackingService.calculateEtaFromCoordinates(
        driverLat: widget.driverPosition!.latitude,
        driverLng: widget.driverPosition!.longitude,
        passengerLat: passengerLat,
        passengerLng: passengerLng,
      );
    }

    _etaController.text = estimatedEta.toString();
    _setupMapMarkers();
  }

  /// Configure les marqueurs sur la carte
  void _setupMapMarkers() {
    final markers = <Marker>{};

    // Marqueur du point de départ
    final departureLat = widget.trip['departure_lat'] as double?;
    final departureLng = widget.trip['departure_lng'] as double?;
    if (departureLat != null && departureLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('departure'),
          position: LatLng(departureLat, departureLng),
          infoWindow: InfoWindow(
            title: 'Départ',
            snippet: widget.trip['departure'] ?? '',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Marqueur de la destination
    final destinationLat = widget.trip['destination_lat'] as double?;
    final destinationLng = widget.trip['destination_lng'] as double?;
    if (destinationLat != null && destinationLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destinationLat, destinationLng),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.trip['destination'] ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Marqueur de la position du chauffeur
    if (widget.driverPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            widget.driverPosition!.latitude,
            widget.driverPosition!.longitude,
          ),
          infoWindow: const InfoWindow(
            title: 'Votre position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  /// Soumet l'offre
  Future<void> _submitOffer() async {
    final price = int.tryParse(_priceController.text);
    final eta = int.tryParse(_etaController.text);

    if (price == null || eta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Utiliser la position cachée ou la récupérer si nécessaire
      Position? currentDriverPosition = widget.driverPosition;

      // Si la position cachée n'existe pas, essayer de la rafraîchir
      if (currentDriverPosition == null) {
        try {
          // Vérifier d'abord les permissions
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            currentDriverPosition = await Geolocator.getCurrentPosition(
              timeLimit: const Duration(seconds: 3),
            );
          } else {
            // Permission refusée, essayer la dernière position connue
            currentDriverPosition = await Geolocator.getLastKnownPosition();
          }
        } catch (e) {
          // En cas d'erreur, essayer la dernière position connue
          try {
            currentDriverPosition = await Geolocator.getLastKnownPosition();
          } catch (e2) {
            // Ignorer, on utilisera les coordonnées du trip
            print('Impossible d\'obtenir la position: $e2');
          }
        }
      }

      // Si on n'a toujours pas de position, on utilise les coordonnées du trip comme approximation
      final driverLat = currentDriverPosition?.latitude ??
          widget.trip['departure_lat'] ??
          0.0;
      final driverLng = currentDriverPosition?.longitude ??
          widget.trip['departure_lng'] ??
          0.0;

      final newOffer = await ref.read(driverOfferServiceProvider).createOffer(
            tripId: widget.trip['id'],
            offeredPrice: price,
            etaMinutes: eta,
            driverLat: driverLat,
            driverLng: driverLng,
          );

      if (mounted) {
        print(
            '[DRIVER_DEBUG] makeOffer: Offer created ${newOffer['id']}, navigating to negotiation screen');
        // Navigation directe vers l'écran de négociation (sans pop d'abord)
        context.go('/negotiation/${newOffer['id']}', extra: newOffer);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _etaController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderName = widget.trip['rider_full_name'] as String? ?? 'Client';
    final departureLat = widget.trip['departure_lat'] as double?;
    final departureLng = widget.trip['departure_lng'] as double?;

    // Définir la position de la caméra initiale
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(
        departureLat ?? 0.0,
        departureLng ?? 0.0,
      ),
      zoom: 13.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faire une offre'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Section Carte (prend 40% de l'écran)
          Expanded(
            flex: 4,
            child: GoogleMap(
              initialCameraPosition: initialPosition,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
                // Ajuster la caméra pour afficher tous les marqueurs
                if (_markers.isNotEmpty) {
                  _fitMarkersInView();
                }
              },
            ),
          ),

          // Section Formulaire (prend 60% de l'écran)
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations du client
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryGreen.withOpacity(0.1),
                          radius: 30,
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.primaryGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                riderName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Demande de course',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Informations sur la course
                    _buildTripInfo(),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Champs de saisie
                    Text(
                      'Votre offre',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Champ Prix
                    TextField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Votre prix (F CFA)',
                        prefixIcon: const Icon(Icons.attach_money,
                            color: AppTheme.primaryGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),

                    // Champ ETA
                    TextField(
                      controller: _etaController,
                      decoration: InputDecoration(
                        labelText: 'Temps d\'arrivée (min)',
                        prefixIcon: const Icon(Icons.timer,
                            color: AppTheme.primaryGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 24),

                    // Bouton Soumettre
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitOffer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Envoyer l\'offre',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher les informations de la course
  Widget _buildTripInfo() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.my_location,
          label: 'Départ',
          value: widget.trip['departure'] ?? 'N/A',
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.location_on,
          label: 'Destination',
          value: widget.trip['destination'] ?? 'N/A',
          color: Colors.red,
        ),
      ],
    );
  }

  /// Widget pour afficher une ligne d'information
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ajuste la caméra pour afficher tous les marqueurs
  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (var marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }
}
