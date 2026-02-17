import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers/user_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../services/places_service.dart';
import '../../../../services/trip_service.dart';
import '../../../../core/constants/booking_types.dart';
import '../../../../models/place.dart';
import '../../../../widgets/booking_type_selector.dart';
import '../../../../widgets/scheduled_time_picker.dart';

// --- Providers ---
final tripServiceProvider = Provider((ref) => TripService());

final apiKeyProvider = FutureProvider<String>((ref) async {
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('GOOGLE_MAPS_API_KEY not found or is empty in .env file');
  }
  return apiKey;
});

final placesServiceProvider = Provider.family<PlacesService, String>(
    (ref, apiKey) => PlacesService(apiKey));

final userPositionProvider = FutureProvider<Position>((ref) {
  return LocationService.getCurrentLocation();
});

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

final departureProvider = StateProvider<Place?>((ref) => null);
final destinationProvider = StateProvider<Place?>((ref) => null);

class HomeScreenNew extends ConsumerStatefulWidget {
  const HomeScreenNew({super.key});

  @override
  ConsumerState<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends ConsumerState<HomeScreenNew> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  String? _sessionToken;
  bool _hasShownDragInfo = false;
  bool _hasShownSnackBar = false;
  BookingType _selectedBookingType = BookingType.immediate;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _destinationFocusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveTrip();
      ref.read(departureProvider.notifier).state = null;
      ref.read(destinationProvider.notifier).state = null;
      _destinationController.clear();
    });

    // Initialiser la position de départ avec la localisation de l'utilisateur
    _initializeDepartureWithUserLocation();
  }

  void _initializeDepartureWithUserLocation() {
    Future.wait([
      ref.read(apiKeyProvider.future),
      ref.read(userPositionProvider.future)
    ]).then((results) async {
      final apiKey = results[0] as String;
      final position = results[1] as Position;

      final placesService = ref.read(placesServiceProvider(apiKey));
      final place = await placesService.getPlaceDetailsFromLatLng(
          latitude: position.latitude, longitude: position.longitude);
      if (mounted) {
        ref.read(departureProvider.notifier).state = place;
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'obtenir la position: $e")),
        );
      }
    });
  }

  void _onFocusChange() {
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

  Future<void> _checkActiveTrip() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('trips')
          .select('*, driver:driver_profiles(*)')
          .eq('user_id', userId)
          .inFilter('status', ['accepted', 'started', 'completed'])
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty && mounted) {
        final trip = response.first;
        final status = trip['status'];

        if (status == 'completed' && trip['driver_rating'] == null ||
            status == 'accepted' ||
            status == 'started') {
          final driver = trip['driver'];
          context.push('/rider-tracking', extra: {
            'tripId': trip['id'],
            'driver': {
              'id': driver['id'],
              'full_name': driver['full_name'],
              'phone': driver['phone'],
              'rating': driver['rating'],
            },
            'price': trip['price'],
          });
        }
      }
    } catch (e) {
      debugPrint('[RIDER_HOME] Error checking active trip: $e');
    }
  }

  Future<void> _onPlaceSelected(Place place) async {
    _destinationFocusNode.unfocus();
    _destinationController.text = place.name;
    ref.read(destinationProvider.notifier).state = place;

    final mapController = await _mapController.future;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16.0),
    );

    ref.read(placeSearchProvider.notifier).clear();

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
              backgroundColor: AppTheme.primaryOrange,
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
    final isDark = theme.brightness == Brightness.dark;
    final userAsync = ref.watch(userDataProvider);
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final userPositionAsync = ref.watch(userPositionProvider);
    final searchResults = ref.watch(placeSearchProvider);
    final departure = ref.watch(departureProvider);
    final destination = ref.watch(destinationProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: userPositionAsync.when(
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
                  infoWindow: InfoWindow(
                      title: 'Destination', snippet: destination.name),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                  draggable: true,
                  onDragEnd: (newPosition) async {
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
                    padding: const EdgeInsets.only(bottom: 300, top: 200),
                    onTap: (latLng) async {
                      final tappedPlace =
                          await placesService.getPlaceDetailsFromLatLng(
                        latitude: latLng.latitude,
                        longitude: latLng.longitude,
                      );
                      _onPlaceSelected(tappedPlace);
                    },
                  ),
                  _buildHeader(theme, isDark, userAsync),
                  _buildSearchUI(theme, searchResults, position),
                  if (destination != null && !_hasShownDragInfo)
                    Positioned(
                      top: 120,
                      left: 20,
                      right: 20,
                      child: IgnorePointer(
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primaryOrange,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.touch_app,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Déplacez le marqueur OU touchez la carte pour ajuster',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .then()
                            .fadeOut(delay: 3000.ms)
                            .callback(
                                duration: 3500.ms,
                                callback: (_) {
                                  if (mounted) {
                                    setState(() {
                                      _hasShownDragInfo = true;
                                    });
                                  }
                                }),
                      ),
                    ),
                  _buildConfirmationPanel(theme, departure, destination),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Erreur: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Erreur: $error')),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark,
      AsyncValue<Map<String, dynamic>?> userAsync) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu Button
          Material(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            elevation: isDark ? 0 : 2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Scaffold.of(context).openDrawer(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white : AppTheme.primaryOrange,
                ),
              ),
            ),
          ),

          // User Info
          userAsync.when(
            data: (user) => Material(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              elevation: isDark ? 0 : 2,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          user?['full_name'] ?? 'Utilisateur',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?['phone'] ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                      child: Text(
                        (user?['full_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Icon(Icons.error),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchUI(ThemeData theme, AsyncValue<List<Place>> searchResults,
      Position position) {
    return Positioned(
      top: 70,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                TextField(
                  controller: _destinationController,
                  focusNode: _destinationFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Où allez-vous ?',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
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
                  onChanged: (value) {
                    if (value.isNotEmpty && _sessionToken != null) {
                      ref.read(placeSearchProvider.notifier).search(
                          value,
                          _sessionToken!,
                          position.latitude,
                          position.longitude);
                    } else {
                      ref.read(placeSearchProvider.notifier).clear();
                    }
                  },
                ),
              ],
            ),
          ),
          // Résultats de recherche
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
                                        strokeWidth: 2));
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
                  BookingTypeSelector(
                    selectedType: _selectedBookingType,
                    onTypeChanged: (type) {
                      setState(() {
                        _selectedBookingType = type;
                        if (type.isImmediate) {
                          _scheduledTime = null;
                        }
                      });
                    },
                  ),
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
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                  child:
                                      CupertinoActivityIndicator(radius: 16)),
                            );

                            try {
                              final trip = await ref
                                  .read(tripServiceProvider)
                                  .createTrip(
                                    departure: departure!,
                                    destination: destination!,
                                    vehicleType:
                                        'any', // Accepter tous les types de véhicules
                                    bookingType: _selectedBookingType.value,
                                    scheduledTime: _scheduledTime,
                                  );

                              final tripId = trip['id'];
                              if (context.mounted) {
                                context.go('/waiting-offers/$tripId');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                context.pop();
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
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canSubmit(Place? departure, Place? destination) {
    if (departure == null || destination == null) return false;
    if (_selectedBookingType.isScheduled && _scheduledTime == null) {
      return false;
    }
    return true;
  }
}

class PlaceSearchNotifier extends StateNotifier<AsyncValue<List<Place>>> {
  final PlacesService? _placesService;
  Timer? _debounce;

  PlaceSearchNotifier(this._placesService,
      {AsyncValue<List<Place>>? initialState})
      : super(initialState ?? const AsyncValue.data([]));

  void search(
      String query, String sessionToken, double latitude, double longitude) {
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
