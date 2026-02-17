import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/location_service.dart';
import '../../../../services/places_service.dart';
import '../../../../services/trip_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/booking_types.dart';
import '../../../../models/place.dart';
import '../../../../widgets/booking_type_selector.dart';
import '../../../../widgets/scheduled_time_picker.dart';

// --- Providers ---

/// Provider pour le service de création de trajet
final tripServiceProvider = Provider((ref) => TripService());

/// Provider asynchrone pour charger la clé API depuis .env
final apiKeyProvider = FutureProvider<String>((ref) async {
  // On s'assure que dotenv est chargé. Normalement fait dans main.dart, mais c'est une sécurité supplémentaire.
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('GOOGLE_MAPS_API_KEY not found or is empty in .env file');
  }
  return apiKey;
});

/// Provider pour le service Google Places
/// Il dépend maintenant de apiKeyProvider pour obtenir la clé de manière asynchrone et sûre.
final placesServiceProvider = Provider.family<PlacesService, String>(
    (ref, apiKey) => PlacesService(apiKey));

/// Provider pour la position actuelle de l'utilisateur
final userPositionProvider = FutureProvider<Position>((ref) {
  return LocationService.getCurrentLocation();
});

/// État pour la recherche de lieux (destination)
final placeSearchProvider = StateNotifierProvider.autoDispose<
    PlaceSearchNotifier, AsyncValue<List<Place>>>((ref) {
  final apiKeyAsync = ref.watch(apiKeyProvider);
  return apiKeyAsync.when(
      data: (apiKey) =>
          PlaceSearchNotifier(ref.watch(placesServiceProvider(apiKey))),
      error: (e, s) =>
          PlaceSearchNotifier(null, initialState: AsyncValue.error(e, s)),
      loading: () =>
          PlaceSearchNotifier(null, initialState: const AsyncValue.loading()));
});

/// État pour le lieu de départ sélectionné
final departureProvider = StateProvider<Place?>((ref) => null);

/// État pour le lieu de destination sélectionné
final destinationProvider = StateProvider<Place?>((ref) => null);

class TripScreen extends ConsumerStatefulWidget {
  final String vehicleType;
  const TripScreen({super.key, required this.vehicleType});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  // Session token pour Google Places API pour regrouper les requêtes
  String? _sessionToken;
  bool _hasShownDragInfo = false; // Pour afficher l'info une seule fois
  bool _hasShownSnackBar = false; // Pour le SnackBar seulement

  // État pour le type de réservation et l'heure planifiée
  BookingType _selectedBookingType = BookingType.immediate;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _destinationFocusNode.addListener(_onFocusChange);

    // Réinitialiser les providers de départ et destination
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(departureProvider.notifier).state = null;
      ref.read(destinationProvider.notifier).state = null;
      _destinationController.clear();
    });

    // Initialiser la position de départ avec la localisation de l'utilisateur
    _initializeDepartureWithUserLocation();
  }

  void _initializeDepartureWithUserLocation() {
    // On attend que la clé API et la position soient prêtes
    Future.wait([
      ref.read(apiKeyProvider.future),
      ref.read(userPositionProvider.future)
    ]).then((results) async {
      final apiKey = results[0] as String;
      final position = results[1] as Position;

      final placesService = ref.read(placesServiceProvider(apiKey));
      final place = await placesService.getPlaceDetailsFromLatLng(
          latitude: position.latitude, longitude: position.longitude);
      // Met à jour le provider de départ
      if (mounted) {
        ref.read(departureProvider.notifier).state = place;
      }
    }).catchError((e) {
      // Gérer l'erreur si la localisation ne peut pas être obtenue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'obtenir la position: $e")),
        );
      }
    });
  }

  void _onFocusChange() {
    // Génère un nouveau session token quand l'utilisateur commence une recherche
    if (_destinationFocusNode.hasFocus) {
      setState(() {
        _sessionToken = const Uuid().v4();
      });
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _destinationFocusNode.removeListener(_onFocusChange);
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onPlaceSelected(Place place) async {
    // Cache le clavier
    _destinationFocusNode.unfocus();

    // Avec Mapbox, le place contient déjà toutes les infos (pas besoin de getPlaceDetails)
    // Met à jour le champ de texte et le provider de destination directement
    _destinationController.text = place.name;
    ref.read(destinationProvider.notifier).state = place;

    // Centre la carte sur la nouvelle destination
    final mapController = await _mapController.future;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16.0),
    );

    // Efface les résultats de recherche
    ref.read(placeSearchProvider.notifier).clear();

    // Afficher le SnackBar informatif (une seule fois)
    if (!_hasShownSnackBar && mounted) {
      _hasShownSnackBar = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Astuce : Maintenez et déplacez le marqueur rouge pour ajuster la destination',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final userPositionAsync = ref.watch(userPositionProvider);
    final searchResults = ref.watch(placeSearchProvider);
    final departure = ref.watch(departureProvider);
    final destination = ref.watch(destinationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Planifier votre trajet"),
        centerTitle: true,
      ),
      body: userPositionAsync.when(
        data: (position) => apiKeyAsync.when(
          data: (apiKey) {
            final placesService = ref.read(placesServiceProvider(apiKey));

            final initialCameraPosition = CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            );

            final markers = <Marker>{};
            if (departure != null) {
              markers.add(Marker(
                markerId: const MarkerId('departure'),
                position: LatLng(departure.latitude, departure.longitude),
                infoWindow:
                    InfoWindow(title: 'Départ', snippet: departure.name),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
              ));
            }
            if (destination != null) {
              markers.add(Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(destination.latitude, destination.longitude),
                infoWindow:
                    InfoWindow(title: 'Destination', snippet: destination.name),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                draggable: true, // Permet de déplacer le marqueur
                onDragEnd: (newPosition) async {
                  // Met à jour la destination quand le marqueur est déplacé
                  final updatedPlace =
                      await placesService.getPlaceDetailsFromLatLng(
                    latitude: newPosition.latitude,
                    longitude: newPosition.longitude,
                  );
                  _destinationController.text = updatedPlace.name;
                  ref.read(destinationProvider.notifier).state = updatedPlace;
                },
              ));
            }

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  onMapCreated: (controller) =>
                      _mapController.complete(controller),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: markers,
                  padding: const EdgeInsets.only(
                      bottom: 300,
                      top: 200), // Padding augmenté pour améliorer l'auto-pan
                  onTap: (latLng) async {
                    // Permet de sélectionner/affiner la destination en touchant la carte
                    final tappedPlace =
                        await placesService.getPlaceDetailsFromLatLng(
                      latitude: latLng.latitude,
                      longitude: latLng.longitude,
                    );
                    _onPlaceSelected(tappedPlace);
                  },
                ),
                _buildSearchUI(theme, searchResults, position),
                // Bulle d'info pour le déplacement du marqueur
                if (destination != null && !_hasShownDragInfo)
                  Positioned(
                    top: 120,
                    left: 20,
                    right: 20,
                    child: IgnorePointer(
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.primaryGreen,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.touch_app,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Déplacez le marqueur OU touchez la carte pour ajuster',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                ignoring: false,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _hasShownDragInfo = true;
                                    });
                                  },
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildConfirmationPanel(theme, departure, destination),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text("Erreur de clé API: $error")),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text("Erreur de localisation: $error")),
      ),
    );
  }

  Widget _buildSearchUI(ThemeData theme, AsyncValue<List<Place>> searchResults,
      Position currentPosition) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Champ de départ (non éditable pour l'instant)
                TextField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: ref.watch(departureProvider)?.address ??
                          "Position actuelle"),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.my_location,
                        color: AppTheme.primaryGreen),
                    labelText: "Départ",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const Divider(height: 1),
                // Champ de destination
                TextField(
                  controller: _destinationController,
                  focusNode: _destinationFocusNode,
                  onChanged: (query) {
                    if (query.isNotEmpty && _sessionToken != null) {
                      ref.read(placeSearchProvider.notifier).search(
                          query,
                          _sessionToken!,
                          currentPosition.latitude,
                          currentPosition.longitude);
                    } else {
                      ref.read(placeSearchProvider.notifier).clear();
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on,
                        color: AppTheme.primaryOrange),
                    labelText: "Destination",
                    hintText: "Quartier, commerce, bâtiment...",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon: _destinationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _destinationController.clear();
                              ref.read(destinationProvider.notifier).state =
                                  null;
                              ref.read(placeSearchProvider.notifier).clear();
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          // Affichage des résultats de recherche
          if (_destinationFocusNode.hasFocus)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Material(
                elevation: 4,
                child: searchResults.when(
                  data: (places) {
                    if (places.isEmpty &&
                        _destinationController.text.isNotEmpty) {
                      return const ListTile(
                        title: Text("Aucun résultat"),
                        leading: Icon(Icons.error_outline),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: places.length,
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          leading: const Icon(Icons.pin_drop_outlined),
                          title: Text(place.name),
                          subtitle: Text(place.address),
                          onTap: () => _onPlaceSelected(place),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(),
                  )),
                  error: (e, st) => ListTile(
                    title: Text("Erreur de recherche: $e"),
                    leading: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationPanel(
      ThemeData theme, Place? departure, Place? destination) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (destination != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      "Vous pouvez déplacer le marqueur rouge sur la carte pour affiner la destination.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (destination != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Distance estimée",
                          style: TextStyle(fontSize: 16)),
                      Consumer(
                        builder: (context, ref, child) {
                          final apiKey =
                              ref.watch(apiKeyProvider).asData?.value;
                          if (apiKey == null) return const Text("...");
                          return FutureBuilder<String>(
                            future: ref
                                .read(placesServiceProvider(apiKey))
                                .getDistance(departure!, destination),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ));
                              }
                              if (snapshot.hasError) {
                                return const Text("N/A",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold));
                              }
                              return Text(
                                snapshot.data ?? "N/A",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                if (destination != null) ...[
                  const SizedBox(height: 20),
                  // Sélecteur de type de réservation
                  BookingTypeSelector(
                    selectedType: _selectedBookingType,
                    onTypeChanged: (type) {
                      setState(() {
                        _selectedBookingType = type;
                        // Réinitialiser l'heure si on passe en immédiat
                        if (type.isImmediate) {
                          _scheduledTime = null;
                        }
                      });
                    },
                  ),
                  // DateTimePicker pour les courses réservées
                  if (_selectedBookingType.isScheduled) ...[
                    const SizedBox(height: 12),
                    ScheduledTimePicker(
                      selectedDateTime: _scheduledTime,
                      onDateTimeChanged: (dateTime) {
                        setState(() {
                          _scheduledTime = dateTime;
                        });
                      },
                      minDateTime:
                          DateTime.now().add(const Duration(minutes: 30)),
                      maxDateTime: DateTime.now().add(const Duration(days: 7)),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit(departure, destination)
                        ? () async {
                            // Affiche un loader
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                  child:
                                      CupertinoActivityIndicator(radius: 16)),
                            );

                            try {
                              // 1. Crée la demande de course via le service
                              final trip = await ref
                                  .read(tripServiceProvider)
                                  .createTrip(
                                    departure: departure!,
                                    destination: destination!,
                                    vehicleType: widget.vehicleType,
                                    bookingType: _selectedBookingType.value,
                                    scheduledTime: _scheduledTime,
                                  );

                              final tripId = trip['id'];
                              if (context.mounted) {
                                // 2. Navigue vers l'écran d'attente des offres avec l'ID du trajet
                                context.go('/waiting-offers/$tripId');
                              }
                            } catch (e) {
                              // En cas d'erreur, ferme le loader et affiche un message
                              if (context.mounted) {
                                context.pop(); // Ferme le dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Erreur: Impossible de créer la course. $e")),
                                );
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: Text(
                      _selectedBookingType.isScheduled
                          ? "Réserver pour plus tard"
                          : "Trouver un chauffeur",
                    ),
                  ),
                ),
                SizedBox(
                    height: MediaQuery.of(context)
                        .viewPadding
                        .bottom), // Pour le safe area en bas
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vérifie si le formulaire peut être soumis
  bool _canSubmit(Place? departure, Place? destination) {
    if (departure == null || destination == null) return false;

    // Si c'est une course réservée, l'heure doit être sélectionnée
    if (_selectedBookingType.isScheduled && _scheduledTime == null) {
      return false;
    }

    return true;
  }
}

/// Notifier pour gérer l'état de la recherche de lieux
class PlaceSearchNotifier extends StateNotifier<AsyncValue<List<Place>>> {
  final PlacesService? _placesService;
  Timer? _debounce;

  PlaceSearchNotifier(this._placesService,
      {AsyncValue<List<Place>>? initialState})
      : super(initialState ?? const AsyncValue.data([]));

  void search(
      String query, String sessionToken, double latitude, double longitude) {
    // Ne rien faire si le service n'est pas encore prêt (clé API en chargement)
    if (_placesService == null) {
      return;
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      state = const AsyncValue.loading();
      try {
        final results = await _placesService!.getAutocomplete(
            query, sessionToken,
            latitude: latitude, longitude: longitude);
        state = AsyncValue.data(results);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  void clear() {
    state = const AsyncValue.data([]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
