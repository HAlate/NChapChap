import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/tracking_service.dart';
import '../../../../services/no_show_service.dart';
import '../../../../services/call_service.dart';
import '../../../../services/chat_service.dart';
import '../../../../core/providers/test_mode_provider.dart';
import '../../../../utils/constants.dart';
import '../widgets/message_popup.dart';
import 'call_screen.dart';

// Provider pour le service de tracking
final trackingServiceProvider = Provider((ref) => TrackingService());
final callServiceProvider = Provider((ref) => CallService());
final chatServiceProvider = Provider((ref) => ChatService());

// Provider pour écouter le statut du trajet
final tripStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, tripId) {
  return ref.watch(trackingServiceProvider).watchTrip(tripId);
});

// Provider pour surveiller le nombre de messages non lus
final unreadMessagesProvider =
    StreamProvider.family<int, ({String tripId, String userId})>(
  (ref, params) {
    return ref
        .watch(chatServiceProvider)
        .watchUnreadCount(tripId: params.tripId, userId: params.userId);
  },
);

// Provider pour surveiller les messages d'un trip
final messagesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, tripId) {
    return ref.watch(chatServiceProvider).watchMessages(tripId);
  },
);

// Provider pour surveiller les accusés de réception (messages lus)
final readReceiptsProvider = StreamProvider.family<List<Map<String, dynamic>>,
    ({String tripId, String userId})>(
  (ref, params) {
    return ref.watch(chatServiceProvider).watchReadReceipts(
          tripId: params.tripId,
          userId: params.userId,
        );
  },
);

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> tripData;

  const DriverNavigationScreen({
    super.key,
    required this.tripData,
  });

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;

  late double _pickupLat;
  late double _pickupLng;
  late double _destinationLat;
  late double _destinationLng;

  // Variables pour la logique des boutons
  bool _isNavigating = false; // true quand "Allez vers..." est cliqué
  Timer? _testModeTimer; // Timer pour simuler le mouvement en mode test
  bool _isDetailsExpanded = false; // Contrôle l'expansion du panneau de détails
  DateTime?
      _arrivalTime; // Heure d'arrivée au point de départ pour calcul du temps d'attente
  bool _isReportingNoShow = false; // État du signalement en cours

  // Pour surveiller les nouveaux messages et éviter d'afficher plusieurs fois le même popup
  final Set<String> _seenMessageIds = {};

  @override
  void initState() {
    super.initState();

    print('[DRIVER_NAV] ===== INIT STATE =====');
    print('[DRIVER_NAV] Trip data: ${widget.tripData}');

    _pickupLat = (widget.tripData['departure_lat'] as num?)?.toDouble() ?? 0.0;
    _pickupLng = (widget.tripData['departure_lng'] as num?)?.toDouble() ?? 0.0;
    _destinationLat =
        (widget.tripData['destination_lat'] as num?)?.toDouble() ?? 0.0;
    _destinationLng =
        (widget.tripData['destination_lng'] as num?)?.toDouble() ?? 0.0;

    print('[DRIVER_NAV] Pickup: $_pickupLat, $_pickupLng');
    print('[DRIVER_NAV] Destination: $_destinationLat, $_destinationLng');

    _loadCarIcon();
    _startLocationTracking();
  }

  Future<void> _loadCarIcon() async {
    print('[DRIVER_NAV] Loading driver marker');
    // Utiliser un marqueur bleu simple pour la position du driver
    _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startLocationTracking() async {
    // Vérifier si le mode test est activé
    final isTestMode = ref.read(testModeProvider);

    if (isTestMode) {
      // Mode test : simuler une position initiale immédiatement
      print('[DRIVER_NAV] Test mode detected - initializing test position');
      _startTestMode();
      return;
    }

    print('[DRIVER_NAV] Real GPS mode - requesting permissions');
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10m
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });

      // Mettre à jour la position du chauffeur dans la base
      ref.read(trackingServiceProvider).updateDriverLocation(position);

      // Mettre à jour uniquement le marqueur du chauffeur
      _updateDriverMarkerOnly();

      // Mettre à jour la caméra pour suivre le chauffeur
      _updateCamera(position);
    });
  }

  void _startTestMode() {
    print('[DRIVER_NAV] ===== STARTING TEST MODE =====');
    // Position initiale : 500m avant le pickup
    final testLat = _pickupLat - 0.005; // ~500m au sud
    final testLng = _pickupLng;

    _currentPosition = TestPositionGenerator.createTestPosition(
      latitude: testLat,
      longitude: testLng,
    );

    print('[DRIVER_NAV] Test position initialized: $_currentPosition');
    ref.read(testPositionProvider.notifier).state = _currentPosition;

    // Mettre à jour la position dans la base
    ref.read(trackingServiceProvider).updateDriverLocation(_currentPosition!);

    if (mounted) {
      setState(() {});
      _updateCamera(_currentPosition!);
      _updateMarkers();
    }
    print('[DRIVER_NAV] Test mode initialization complete');
  }

  void _startTestMovement() {
    print('[DRIVER_NAV] Starting test movement');
    final tripAsync = ref.read(tripStreamProvider(widget.tripData['tripId']));
    final status = tripAsync.value?['status'] ?? 'accepted';
    final driverArrived =
        tripAsync.value?['driver_arrived_notification'] != null;

    // Déterminer la destination selon le statut
    double targetLat, targetLng;
    if (status == 'accepted' && !driverArrived) {
      targetLat = _pickupLat;
      targetLng = _pickupLng;
    } else if (status == 'started') {
      targetLat = _destinationLat;
      targetLng = _destinationLng;
    } else {
      return;
    }

    // Annuler le timer précédent s'il existe
    _testModeTimer?.cancel();

    // Créer un timer qui simule le mouvement toutes les 2 secondes
    _testModeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _currentPosition == null) {
        timer.cancel();
        return;
      }

      // Se déplacer vers la cible
      final newPosition = TestPositionGenerator.moveTowards(
        current: _currentPosition!,
        targetLat: targetLat,
        targetLng: targetLng,
        stepMeters: 50.0,
      );

      setState(() {
        _currentPosition = newPosition;
      });

      // Mettre à jour dans la base
      ref.read(trackingServiceProvider).updateDriverLocation(newPosition);

      // Mettre à jour uniquement le marqueur du chauffeur
      _updateDriverMarkerOnly();

      // Mettre à jour la caméra
      _updateCamera(newPosition);
    });
  }

  Future<void> _updateCamera(Position position) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16.0,
      ),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    print('[DRIVER_NAV] ===== MAP CREATED =====');
    _mapController = controller;

    // Ajouter les marqueurs
    await _updateMarkers();

    // Centrer la caméra
    if (_currentPosition != null) {
      _updateCamera(_currentPosition!);
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_pickupLat, _pickupLng),
          14.0,
        ),
      );
    }
  }

  /// Met à jour uniquement la position du marker du driver (optimisé)
  void _updateDriverMarkerOnly() {
    if (_currentPosition == null || _carIcon == null) return;

    // Créer une copie des markers existants
    final updatedMarkers = Set<Marker>.from(_markers);

    // Retirer l'ancien marker du driver s'il existe
    updatedMarkers.removeWhere((m) => m.markerId.value == 'driver');

    // Ajouter le nouveau marker du driver à la position actuelle
    updatedMarkers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: _carIcon!,
        anchor: const Offset(0.5, 0.5),
        rotation: _currentPosition!.heading,
        infoWindow: const InfoWindow(
          title: 'Votre position',
        ),
      ),
    );

    setState(() {
      _markers = updatedMarkers;
    });
  }

  Future<void> _updateMarkers() async {
    print('[DRIVER_NAV] _updateMarkers called');
    print('[DRIVER_NAV] _currentPosition: $_currentPosition');
    print('[DRIVER_NAV] _carIcon: $_carIcon');

    // Obtenir le statut actuel
    final tripAsync = ref.read(tripStreamProvider(widget.tripData['tripId']));
    final status = tripAsync.value?['status'] ?? 'accepted';

    final markers = <Marker>{};

    // Marqueur du chauffeur (voiture) - position actuelle
    if (_currentPosition != null && _carIcon != null) {
      print(
          '[DRIVER_NAV] Adding driver marker at ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: _carIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _currentPosition!.heading,
          infoWindow: const InfoWindow(
            title: 'Votre position',
          ),
        ),
      );
    } else {
      print(
          '[DRIVER_NAV] Cannot add driver marker: position=${_currentPosition != null}, icon=${_carIcon != null}');
    }

    // Marqueur de départ (orange)
    print('[DRIVER_NAV] Adding pickup marker at $_pickupLat, $_pickupLng');
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(_pickupLat, _pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Point de départ',
          snippet: widget.tripData['departure'],
        ),
      ),
    );

    // Marqueur de destination (rouge) - toujours affiché
    print(
        '[DRIVER_NAV] Adding destination marker at $_destinationLat, $_destinationLng');
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(_destinationLat, _destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: widget.tripData['destination'],
        ),
      ),
    );

    print('[DRIVER_NAV] Total markers: ${markers.length}');

    setState(() {
      _markers = markers;
    });

    print('[DRIVER_NAV] Markers updated in state');
  }

  Future<void> _handleArrivedAtPickup() async {
    try {
      // NE PAS changer le statut à 'arrived' car il n'existe pas dans l'enum
      // On utilise seulement le champ driver_arrived_notification

      // Envoyer la notification au passager
      await ref
          .read(trackingServiceProvider)
          .notifyRiderDriverArrived(widget.tripData['tripId']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification envoyée : Arrivé au point de départ'),
            backgroundColor: Colors.green,
          ),
        );
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

  /// Vérifie si le driver est arrivé à destination via GPS
  bool _isAtDestination() {
    if (_currentPosition == null) return false;

    // Calculer la distance entre la position actuelle et la destination
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destinationLat,
      _destinationLng,
    );

    print(
        '[DRIVER_NAV] Distance to destination: ${distanceInMeters.toStringAsFixed(1)}m');

    // Considérer arrivé si à moins de 50m de la destination
    return distanceInMeters < 50;
  }

  Future<void> _handleTripCompleted() async {
    print('[DRIVER_NAV] _handleTripCompleted called');
    print('[DRIVER_NAV] _currentPosition: $_currentPosition');

    try {
      // Vérifier que la position actuelle est disponible
      if (_currentPosition == null) {
        print('[DRIVER_NAV] WARNING: _currentPosition is null!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Position GPS non disponible. Veuillez réessayer.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('[DRIVER_NAV] Position available, checking distance...');
      // Vérifier que le driver est bien arrivé à destination
      if (!_isAtDestination()) {
        if (mounted) {
          final distanceInMeters = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _destinationLat,
            _destinationLng,
          );

          // Afficher un dialogue avec options
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Distance de la destination'),
              content: Text(
                'Vous êtes à ${distanceInMeters.toStringAsFixed(0)}m de la destination prévue.\n\n'
                'La destination a-t-elle changé pendant la course ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('report_change'),
                  child: const Text(
                    'Signaler un changement',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('continue'),
                  child: const Text('Terminer quand même'),
                ),
              ],
            ),
          );

          if (result == 'report_change') {
            // Signaler un changement de destination
            await _reportDestinationChange();
            return;
          } else if (result == 'cancel') {
            return;
          }
          // Si 'continue', on poursuit la fin de course
        }
      }

      // Mettre à jour le statut
      await ref.read(trackingServiceProvider).updateTripStatus(
            widget.tripData['tripId'],
            'completed',
          );

      if (mounted) {
        // Afficher un dialogue de confirmation de fin de course avec évaluation obligatoire
        int? selectedRating; // Variable pour stocker la note sélectionnée

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(20),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Course terminée !',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'La course a été terminée avec succès.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Montant de la course:'),
                              Text(
                                '${widget.tripData['price']} F',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Passager:'),
                              Text(
                                widget.tripData['rider_name'] ?? 'Client',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Notez votre passager',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Icon(
                              selectedRating != null &&
                                      starValue <= selectedRating!
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 28,
                              color: Colors.amber,
                            ),
                            onPressed: () {
                              setState(() {
                                selectedRating = starValue;
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    if (selectedRating == null)
                      const Center(
                        child: Text(
                          'Évaluation obligatoire',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: selectedRating != null
                      ? () async {
                          // Sauvegarder la note dans la base de données
                          try {
                            await Supabase.instance.client
                                .from('trips')
                                .update({'rider_rating': selectedRating}).eq(
                                    'id', widget.tripData['tripId']);

                            print('[DRIVER_NAV] Rating saved: $selectedRating');
                            if (mounted) {
                              // Fermer le dialog d'évaluation
                              Navigator.of(context).pop();
                              // Attendre que le dialog se ferme
                              await Future.delayed(
                                  const Duration(milliseconds: 100));
                              // Fermer l'écran de navigation et retourner à home
                              if (mounted) {
                                context.go(
                                    '/home'); // Remplace tout le stack par home
                              }
                            }
                          } catch (e) {
                            print('[DRIVER_NAV] Error saving rating: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la sauvegarde de l\'évaluation'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text(
                    'Valider',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
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

  /// Signale un changement de destination pendant la course
  Future<void> _reportDestinationChange() async {
    try {
      // Enregistrer la nouvelle position comme destination
      final newDestinationLat = _currentPosition!.latitude;
      final newDestinationLng = _currentPosition!.longitude;

      // Mettre à jour dans la base de données
      await Supabase.instance.client.from('trips').update({
        'destination_lat': newDestinationLat,
        'destination_lng': newDestinationLng,
        'destination_changed': true,
        'destination_changed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.tripData['tripId']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changement de destination signalé.\n'
                'La nouvelle position a été enregistrée.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Mettre à jour les variables locales
        setState(() {
          _destinationLat = newDestinationLat;
          _destinationLng = newDestinationLng;
        });

        // Recharger les marqueurs
        await _updateMarkers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du signalement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ouvre Waze avec la destination actuelle
  Future<void> _openWaze() async {
    final tripAsync = ref.read(tripStreamProvider(widget.tripData['tripId']));
    final status = tripAsync.value?['status'] ?? 'accepted';
    final driverArrived =
        tripAsync.value?['driver_arrived_notification'] != null;

    // Déterminer la destination et son nom
    double targetLat, targetLng;
    String targetName;
    if (status == 'accepted' && !driverArrived) {
      targetLat = _pickupLat;
      targetLng = _pickupLng;
      targetName = widget.tripData['departure'] ?? 'Point de départ';
    } else {
      targetLat = _destinationLat;
      targetLng = _destinationLng;
      targetName = widget.tripData['destination'] ?? 'Destination';
    }

    // Encoder le nom pour l'URL (remplacer espaces par +)
    final encodedName = Uri.encodeComponent(targetName);
    final url = 'waze://?ll=$targetLat,$targetLng&q=$encodedName&navigate=yes';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fallback vers Google Maps si Waze n'est pas installé
        _openGoogleMaps();
      }
    } catch (e) {
      print('[DRIVER_NAV] Error opening Waze: $e');
      _openGoogleMaps();
    }
  }

  /// Ouvre Google Maps avec la destination actuelle
  Future<void> _openGoogleMaps() async {
    final tripAsync = ref.read(tripStreamProvider(widget.tripData['tripId']));
    final status = tripAsync.value?['status'] ?? 'accepted';
    final driverArrived =
        tripAsync.value?['driver_arrived_notification'] != null;

    // Déterminer la destination et son nom
    double targetLat, targetLng;
    String targetName;
    if (status == 'accepted' && !driverArrived) {
      targetLat = _pickupLat;
      targetLng = _pickupLng;
      targetName = widget.tripData['departure'] ?? 'Point de départ';
    } else {
      targetLat = _destinationLat;
      targetLng = _destinationLng;
      targetName = widget.tripData['destination'] ?? 'Destination';
    }

    // Construire l'URL avec le point de départ (position actuelle) et le nom du lieu
    String url = 'https://www.google.com/maps/dir/?api=1';

    // Ajouter le point de départ si disponible (position GPS actuelle)
    if (_currentPosition != null) {
      url +=
          '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }

    // Ajouter la destination avec ses coordonnées
    url += '&destination=$targetLat,$targetLng';

    // Ajouter le nom du lieu en paramètre de recherche pour l'affichage
    final encodedName = Uri.encodeComponent(targetName);
    url += '&destination_place_name=$encodedName';

    url += '&travelmode=driving';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir la navigation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[DRIVER_NAV] Error opening Google Maps: $e');
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

  /// Ouvre Apple Maps avec la destination actuelle (compatible CarPlay)
  Future<void> _openAppleMaps() async {
    final tripAsync = ref.read(tripStreamProvider(widget.tripData['tripId']));
    final status = tripAsync.value?['status'] ?? 'accepted';
    final driverArrived =
        tripAsync.value?['driver_arrived_notification'] != null;

    // Déterminer la destination
    double targetLat, targetLng;
    String targetName;
    if (status == 'accepted' && !driverArrived) {
      targetLat = _pickupLat;
      targetLng = _pickupLng;
      targetName = widget.tripData['departure'] ?? 'Point de départ';
    } else {
      targetLat = _destinationLat;
      targetLng = _destinationLng;
      targetName = widget.tripData['destination'] ?? 'Destination';
    }

    // URL scheme pour Apple Maps (compatible CarPlay)
    final encodedName = Uri.encodeComponent(targetName);
    final url =
        'http://maps.apple.com/?daddr=$targetLat,$targetLng&q=$encodedName&dirflg=d';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apple Maps non disponible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Fallback vers Google Maps
        _openGoogleMaps();
      }
    } catch (e) {
      print('[DRIVER_NAV] Error opening Apple Maps: $e');
      _openGoogleMaps();
    }
  }

  /// Affiche un dialogue pour choisir l'app de navigation
  Future<void> _chooseNavigationApp() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir la navigation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quelle application souhaitez-vous utiliser ?'),
            const SizedBox(height: 8),
            Text(
              '🚗 Compatible Android Auto / CarPlay',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('waze'),
            icon: const Icon(Icons.navigation),
            label: const Text('Waze'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF33CCFF),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('google_maps'),
            icon: const Icon(Icons.map),
            label: const Text('Google Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('apple_maps'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Apple Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );

    if (result == 'waze') {
      _openWaze();
    } else if (result == 'google_maps') {
      _openGoogleMaps();
    } else if (result == 'apple_maps') {
      _openAppleMaps();
    }
  }

  /// Afficher le dialogue de signalement No Show
  Future<void> _showNoShowDialog(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Signaler un No Show'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le passager ne s\'est pas présenté au point de départ ?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '• La course sera automatiquement annulée\n'
              '• Le passager recevra un avertissement\n'
              '• Vous ne perdrez pas de jeton',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                hintText: 'Ex: Pas de réponse après 5 minutes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer le No Show'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _reportNoShow(reasonController.text);
    }
  }

  /// Signaler le No Show via l'API
  Future<void> _reportNoShow(String reason) async {
    try {
      final driverId = Supabase.instance.client.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final riderId =
          widget.tripData['rider']?['id'] ?? widget.tripData['rider_id'];
      if (riderId == null) {
        throw Exception('ID passager non trouvé');
      }

      await NoShowService.reportNoShow(
        tripId: widget.tripData['tripId'],
        reportedBy: driverId,
        reportedUser: riderId,
        userType: 'rider',
        reason: reason.isNotEmpty ? reason : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No Show signalé avec succès. La course a été annulée.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Retour à l'écran précédent
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du signalement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Affiche un dialogue pour composer un message
  Future<void> _showComposeMessageDialog(BuildContext context) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final rider = widget.tripData['rider'];
    final senderName = rider?['full_name']?.toString() ??
        rider?['name']?.toString() ??
        'Passager';

    // Afficher le popup de composition
    showDialog(
      context: context,
      builder: (context) => ComposeMessageDialog(
        receiverName: senderName,
        onSend: (message) async {
          await ref.read(chatServiceProvider).sendMessage(
                tripId: widget.tripData['tripId'],
                senderId: currentUserId,
                receiverId: rider?['id'] ?? widget.tripData['rider_id'],
                senderType: 'driver',
                message: message,
              );
        },
      ),
    );
  }

  /// Affiche un dialogue pour afficher un message reçu
  Future<void> _showReceivedMessageDialog(
      BuildContext context, Map<String, dynamic> message) async {
    final rider = widget.tripData['rider'];
    final senderName = rider?['full_name']?.toString() ??
        rider?['name']?.toString() ??
        'Passager';
    final messageText = message['message'] as String;
    final timestamp = DateTime.parse(message['created_at'] as String);
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    String timeText;
    if (diff.inMinutes < 1) {
      timeText = 'À l\'instant';
    } else if (diff.inHours < 1) {
      timeText = 'Il y a ${diff.inMinutes} min';
    } else {
      timeText = 'Il y a ${diff.inHours}h';
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Marquer comme lu
    ref.read(chatServiceProvider).markAsRead(message['id']);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => ReceivedMessageDialog(
          senderName: senderName,
          message: messageText,
          timestamp: timeText,
          onSend: (replyMessage) async {
            await ref.read(chatServiceProvider).sendMessage(
                  tripId: widget.tripData['tripId'],
                  senderId: currentUserId,
                  receiverId: rider?['id'] ?? widget.tripData['rider_id'],
                  senderType: 'driver',
                  message: replyMessage,
                );
          },
          onClose: () {
            // Le dialog se ferme automatiquement
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _testModeTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripData['tripId']));

    // Écouter les nouveaux messages et afficher automatiquement un popup
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      print('[DRIVER_NAV] 📱 Listening for messages as driver: $currentUserId');
      print('[DRIVER_NAV] 🆔 Trip ID: ${widget.tripData['tripId']}');

      ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
        messagesStreamProvider(widget.tripData['tripId']),
        (prev, next) {
          next.whenData((messages) {
            print('[DRIVER_NAV] 📨 Received ${messages.length} total messages');

            for (final message in messages) {
              final messageId = message['id'] as String;
              final receiverId = message['receiver_id'] as String?;
              final senderId = message['sender_id'] as String?;
              final senderType = message['sender_type'] as String?;
              final messageText = message['message'] as String?;

              print('[DRIVER_NAV] ━━━━━━━━━━━━━━━━━━━━━━━━━━');
              print('[DRIVER_NAV] 📩 Message ID: $messageId');
              print('[DRIVER_NAV] 👤 Sender: $senderId ($senderType)');
              print('[DRIVER_NAV] 🎯 Receiver: $receiverId');
              print('[DRIVER_NAV] 💬 Text: $messageText');
              print('[DRIVER_NAV] ✅ Current user: $currentUserId');
              print(
                  '[DRIVER_NAV] 🔍 Is for me: ${receiverId == currentUserId}');
              print(
                  '[DRIVER_NAV] 👁️ Already seen: ${_seenMessageIds.contains(messageId)}');
              print('[DRIVER_NAV] 📱 Mounted: $mounted');

              // Si c'est un nouveau message pour moi que je n'ai pas encore vu
              if (receiverId == currentUserId &&
                  !_seenMessageIds.contains(messageId) &&
                  mounted) {
                print(
                    '[DRIVER_NAV] ✨✨✨ NEW MESSAGE FOR DRIVER! Showing popup...');
                _seenMessageIds.add(messageId);

                // Afficher le popup après un court délai
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    print('[DRIVER_NAV] 🔔 Displaying message dialog now');
                    _showReceivedMessageDialog(context, message);
                  } else {
                    print(
                        '[DRIVER_NAV] ⚠️ Widget no longer mounted, skipping dialog');
                  }
                });
              } else {
                if (receiverId != currentUserId) {
                  print(
                      '[DRIVER_NAV] ⏭️ Message not for me (for: $receiverId)');
                } else if (_seenMessageIds.contains(messageId)) {
                  print('[DRIVER_NAV] ⏭️ Message already seen');
                } else if (!mounted) {
                  print('[DRIVER_NAV] ⏭️ Widget not mounted');
                }
              }
            }
          });
        },
      );

      // Écouter les accusés de réception (quand l'autre lit nos messages)
      ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
        readReceiptsProvider(
            (tripId: widget.tripData['tripId'], userId: currentUserId)),
        (prev, next) {
          next.whenData((readMessages) {
            // Comparer avec les messages précédents pour voir s'il y en a de nouveaux lus
            final prevMessages = prev?.valueOrNull ?? [];
            final newReadMessages = readMessages.where((msg) {
              return !prevMessages.any((prevMsg) => prevMsg['id'] == msg['id']);
            }).toList();

            // Afficher une notification discrète pour chaque nouveau message lu
            if (newReadMessages.isNotEmpty && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.done_all, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Le passager a lu votre message'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin:
                      const EdgeInsets.only(bottom: 80, left: 20, right: 20),
                ),
              );
            }
          });
        },
      );
    } else {
      print('[DRIVER_NAV] ⚠️ No current user ID - cannot listen to messages');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          // Bouton mode test
          Consumer(
            builder: (context, ref, child) {
              final isTestMode = ref.watch(testModeProvider);
              return IconButton(
                icon: Icon(
                  Icons.bug_report,
                  color: isTestMode ? Colors.orange : Colors.grey,
                ),
                onPressed: () {
                  ref.read(testModeProvider.notifier).state = !isTestMode;
                  if (!isTestMode) {
                    // Activer le mode test
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mode test activé - GPS simulé'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    _startTestMode();
                  } else {
                    // Désactiver le mode test
                    _testModeTimer?.cancel();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mode test désactivé'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Badge de statut
                tripAsync.when(
                  data: (trip) {
                    final status = trip['status'] as String;
                    final driverArrived =
                        trip['driver_arrived_notification'] != null;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status, driverArrived),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getStatusText(status, driverArrived),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // Bouton de navigation externe
                ElevatedButton.icon(
                  onPressed: _chooseNavigationApp,
                  icon: const Icon(Icons.navigation, size: 28),
                  label: const Text(
                    'Ouvrir la navigation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                  ),
                ),

                const SizedBox(height: 32),

                // Panneau de détails du voyage (collapsible)
                Consumer(
                  builder: (context, ref, child) {
                    return _TripDetailsCard(
                      tripData: widget.tripData,
                      isExpanded: _isDetailsExpanded,
                      onToggle: () {
                        setState(() {
                          _isDetailsExpanded = !_isDetailsExpanded;
                        });
                      },
                      ref: ref,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Infos et boutons de contrôle
                tripAsync.when(
                  data: (trip) {
                    final theme = Theme.of(context);
                    final status = trip['status'] as String;
                    final driverArrived =
                        trip['driver_arrived_notification'] != null;

                    print('[DRIVER_NAV] ===== STATUS CHECK =====');
                    print('[DRIVER_NAV] Current status: $status');
                    print(
                        '[DRIVER_NAV] Driver arrived notification: ${trip['driver_arrived_notification']}');
                    print('[DRIVER_NAV] driverArrived flag: $driverArrived');
                    print('[DRIVER_NAV] _isNavigating: $_isNavigating');
                    print('[DRIVER_NAV] _arrivalTime: $_arrivalTime');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Infos destination
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                status == 'started'
                                    ? Icons.flag
                                    : Icons.location_on,
                                color: status == 'started'
                                    ? Colors.red
                                    : AppTheme.primaryGreen,
                                size: 40,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status == 'started'
                                          ? 'Destination'
                                          : 'Point de départ',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      status == 'started'
                                          ? widget.tripData['destination'] ?? ''
                                          : widget.tripData['departure'] ?? '',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Boutons d'action selon le statut
                        if (status == 'accepted' && !driverArrived) ...[
                          ElevatedButton.icon(
                            onPressed: !_isNavigating
                                ? () {
                                    setState(() {
                                      _isNavigating = true;
                                    });
                                    // Démarrer la simulation de mouvement en mode test
                                    if (ref.read(testModeProvider)) {
                                      _startTestMovement();
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.directions_car, size: 24),
                            label: const Text(
                              'Allez vers le point de départ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isNavigating
                                ? () async {
                                    print(
                                        '[DRIVER_NAV] 🔘 Button "Je suis arrivé" clicked');
                                    // Approche APPZEDGO: NE PAS changer le statut, juste envoyer la notification
                                    // Le statut reste 'accepted', driver_arrived_notification est rempli
                                    await _handleArrivedAtPickup();
                                    setState(() {
                                      _arrivalTime = DateTime.now();
                                      _isNavigating = false;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Arrivée confirmée. En attente du passager.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.check_circle, size: 24),
                            label: const Text(
                              'Je suis arrivé au point de départ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                        ] else if (status == 'accepted' && driverArrived) ...[
                          // Afficher le temps d'attente
                          if (trip['driver_arrived_notification'] != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    'En attente depuis ${DateTime.now().difference(DateTime.parse(trip['driver_arrived_notification'])).inMinutes} min',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Allez vers la destination = démarrer la course (statut 'started')
                              try {
                                await ref
                                    .read(trackingServiceProvider)
                                    .updateTripStatus(
                                      widget.tripData['tripId'],
                                      'started',
                                    );
                                setState(() {
                                  _isNavigating = true;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Navigation vers la destination activée.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.navigation, size: 24),
                            label: const Text(
                              'Allez vers la destination',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Bouton No Show disponible immédiatement
                          OutlinedButton.icon(
                            onPressed: () => _showNoShowDialog(context),
                            icon: const Icon(Icons.person_off, size: 24),
                            label: const Text(
                              'Signaler passager absent',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side:
                                  const BorderSide(color: Colors.red, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                        ] else if (status == 'started') ...[
                          ElevatedButton.icon(
                            onPressed: !_isNavigating
                                ? () {
                                    setState(() {
                                      _isNavigating = true;
                                    });
                                    // Démarrer la simulation de mouvement en mode test
                                    if (ref.read(testModeProvider)) {
                                      _startTestMovement();
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.directions_car, size: 24),
                            label: const Text(
                              'Allez vers la destination',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed:
                                _isNavigating ? _handleTripCompleted : null,
                            icon: const Icon(Icons.flag, size: 24),
                            label: const Text(
                              'Je suis arrivé à destination',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showNoShowDialog(context),
                            icon: const Icon(Icons.person_off, size: 24),
                            label: const Text(
                              'Signaler passager absent',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side:
                                  const BorderSide(color: Colors.red, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                        ]
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text(
                      'Erreur de chargement',
                      style: TextStyle(color: Colors.red.shade700),
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

  Color _getStatusColor(String status, bool driverArrived) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'started':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, bool driverArrived) {
    switch (status) {
      case 'accepted':
        return driverArrived
            ? 'En attente du passager'
            : 'En attente au point de départ';
      case 'started':
        return 'En route vers la destination';
      case 'completed':
        return 'Course terminée';
      default:
        return 'Statut inconnu';
    }
  }
}

class _TripDetailsCard extends StatelessWidget {
  final Map<String, dynamic> tripData;
  final bool isExpanded;
  final VoidCallback onToggle;
  final WidgetRef ref;

  const _TripDetailsCard({
    required this.tripData,
    required this.isExpanded,
    required this.onToggle,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Détails du voyage',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripDetailRow(
                    icon: Icons.person,
                    iconColor: Colors.blue,
                    label: 'Passager',
                    value: tripData['rider']?['full_name']?.toString() ??
                        tripData['rider']?['name']?.toString() ??
                        tripData['rider_name'] ??
                        'Inconnu',
                  ),
                  const Divider(height: 24),
                  _TripDetailRow(
                    icon: Icons.location_on,
                    iconColor: AppTheme.primaryGreen,
                    label: 'Point de départ',
                    value: tripData['departure'] ?? 'Inconnu',
                  ),
                  const Divider(height: 24),
                  _TripDetailRow(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    label: 'Destination',
                    value: tripData['destination'] ?? 'Inconnu',
                  ),
                  const Divider(height: 24),
                  _TripDetailRow(
                    icon: Icons.straighten,
                    iconColor: Colors.orange,
                    label: 'Distance',
                    value:
                        '${tripData['distance']?.toStringAsFixed(1) ?? '0.0'} km',
                  ),
                  const Divider(height: 24),
                  _TripDetailRow(
                    icon: Icons.access_time,
                    iconColor: Colors.purple,
                    label: 'Durée estimée',
                    value: '${tripData['duration']?.toString() ?? '0'} min',
                  ),
                  const Divider(height: 24),
                  _TripDetailRow(
                    icon: Icons.payments,
                    iconColor: Colors.green,
                    label: 'Prix',
                    value: '${tripData['price']?.toString() ?? '0'} F',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Appeler le passager',
                        button: true,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppTheme.primaryGreen.withOpacity(0.1),
                          child: IconButton(
                            icon: const Icon(
                              Icons.phone,
                              color: AppTheme.primaryGreen,
                            ),
                            onPressed: () async {
                              final currentUserId =
                                  Supabase.instance.client.auth.currentUser?.id;
                              if (currentUserId == null) return;

                              final rider = tripData['rider'];
                              final riderName =
                                  rider?['full_name']?.toString() ??
                                      rider?['name']?.toString() ??
                                      'Passager';

                              try {
                                final callId = await ref
                                    .read(callServiceProvider)
                                    .initiateCall(
                                      tripId: tripData['tripId'],
                                      callerId: currentUserId,
                                      receiverId:
                                          rider?['id'] ?? tripData['rider_id'],
                                      callerType: 'driver',
                                      callerName: 'Chauffeur',
                                    );

                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => CallScreen(
                                        tripId: tripData['tripId'],
                                        receiverId: rider?['id'] ??
                                            tripData['rider_id'],
                                        receiverName: riderName,
                                        receiverType: 'rider',
                                        callId: callId,
                                        isIncoming: false,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Semantics(
                        label: 'Envoyer un message',
                        button: true,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppTheme.primaryGreen.withOpacity(0.1),
                          child: IconButton(
                            icon: const Icon(
                              Icons.message,
                              color: AppTheme.primaryGreen,
                            ),
                            onPressed: () {
                              final currentUserId =
                                  Supabase.instance.client.auth.currentUser?.id;
                              if (currentUserId == null) return;

                              final rider = tripData['rider'];
                              final senderName =
                                  rider?['full_name']?.toString() ??
                                      rider?['name']?.toString() ??
                                      'Passager';

                              showDialog(
                                context: context,
                                builder: (context) => ComposeMessageDialog(
                                  receiverName: senderName,
                                  onSend: (message) async {
                                    await ref
                                        .read(chatServiceProvider)
                                        .sendMessage(
                                          tripId: tripData['tripId'],
                                          senderId: currentUserId,
                                          receiverId: rider?['id'] ??
                                              tripData['rider_id'],
                                          senderType: 'driver',
                                          message: message,
                                        );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _TripDetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
