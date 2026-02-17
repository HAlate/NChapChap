import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../utils/constants.dart';
import '../../../../services/trip_service.dart';
import '../../../../services/no_show_service.dart';
import '../../../../services/call_service.dart';
import '../../../../services/chat_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../trip/presentation/screens/trip_screen.dart';
import '../widgets/message_popup.dart';
import 'call_screen.dart';

// --- Providers ---
final tripServiceProvider = Provider((ref) => TripService());
final callServiceProvider = Provider((ref) => CallService());
final chatServiceProvider = Provider((ref) => ChatService());

final tripStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, tripId) {
  return ref.watch(tripServiceProvider).watchTrip(tripId);
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

final driverLocationStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, driverId) {
  print('[RIDER_TRACKING] Setting up driver location stream for: $driverId');
  return Supabase.instance.client
      .from('driver_profiles')
      .stream(primaryKey: ['id'])
      .eq('id', driverId)
      .map((profiles) {
        print(
            '[RIDER_TRACKING] Stream received profiles: ${profiles.length} items');
        if (profiles.isEmpty) {
          print('[RIDER_TRACKING] No driver profile found for: $driverId');
          throw Exception('Driver profile not found');
        }
        final profile = profiles.first;
        print(
            '[RIDER_TRACKING] Driver profile update - Lat: ${profile['current_lat']}, Lng: ${profile['current_lng']}');
        return profile;
      });
});

enum TripStatus {
  driverEnRoute,
  driverArrived,
  tripStarted,
  tripCompleted,
}

class RiderTrackingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;
  final String departure;
  final String destination;
  final int price;
  final String tripId;
  final double departureLat;
  final double departureLng;
  final double driverLatAtOffer;
  final double driverLngAtOffer;
  final double destinationLat;
  final double destinationLng;

  const RiderTrackingScreen({
    super.key,
    required this.driver,
    required this.price,
    String? departure,
    String? destination,
    required this.tripId,
    required this.departureLat,
    required this.departureLng,
    required this.driverLatAtOffer,
    required this.driverLngAtOffer,
    required this.destinationLat,
    required this.destinationLng,
  })  : departure = departure ?? '',
        destination = destination ?? '';

  @override
  ConsumerState<RiderTrackingScreen> createState() =>
      _RiderTrackingScreenState();
}

class _RiderTrackingScreenState extends ConsumerState<RiderTrackingScreen> {
  GoogleMapController? _mapController;

  // La position du chauffeur est maintenant nullable pour gérer l'état de chargement initial.
  LatLng? _driverPosition;
  late LatLng _pickupPosition;
  late LatLng _destinationPosition;
  BitmapDescriptor? _carIcon;

  // Pour suivre si la notification a déjà été affichée
  String? _lastNotificationTime;

  // Nom de l'utilisateur pour les appels
  String? _riderName;

  // Pour surveiller les nouveaux messages et éviter d'afficher plusieurs fois le même popup
  final Set<String> _seenMessageIds = {};

  @override
  void initState() {
    super.initState();
    // Logs de débogage pour diagnostiquer les problèmes d'affichage
    print('[RIDER_TRACKING] ========== INITIALIZING ==========');
    print('[RIDER_TRACKING] Departure: ${widget.departure}');
    print(
        '[RIDER_TRACKING] Departure coords: (${widget.departureLat}, ${widget.departureLng})');
    print('[RIDER_TRACKING] Destination: ${widget.destination}');
    print(
        '[RIDER_TRACKING] Destination coords: (${widget.destinationLat}, ${widget.destinationLng})');
    print('[RIDER_TRACKING] Price: ${widget.price}');
    print('[RIDER_TRACKING] TripId: ${widget.tripId}');
    print('[RIDER_TRACKING] Driver object: ${widget.driver}');
    print('[RIDER_TRACKING] Driver keys: ${widget.driver.keys.toList()}');
    print('[RIDER_TRACKING] Driver ID: ${widget.driver['id']}');
    print('[RIDER_TRACKING] Driver name: ${widget.driver['full_name']}');
    print('[RIDER_TRACKING] Driver rating: ${widget.driver['rating']}');
    print('[RIDER_TRACKING] Driver trips: ${widget.driver['total_trips']}');
    print('[RIDER_TRACKING] Driver plate: ${widget.driver['vehicle_plate']}');
    print(
        '[RIDER_TRACKING] Driver position: (${widget.driverLatAtOffer}, ${widget.driverLngAtOffer})');
    print('[RIDER_TRACKING] ===================================');

    // Initialiser les positions avec les vraies coordonnées
    _pickupPosition = LatLng(widget.departureLat, widget.departureLng);
    _destinationPosition = LatLng(widget.destinationLat, widget.destinationLng);
    // La position initiale du chauffeur est maintenant passée directement, plus besoin de la fetch.
    _driverPosition = LatLng(widget.driverLatAtOffer, widget.driverLngAtOffer);

    _loadCarIcon();
    _loadRiderName();
  }

  Future<void> _loadRiderName() async {
    try {
      print('[RIDER_TRACKING] 🔍 Chargement du nom du rider...');
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      print('[RIDER_TRACKING] User ID: $currentUserId');

      if (currentUserId == null) {
        print('[RIDER_TRACKING] ❌ User ID null');
        return;
      }

      final userProfile = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name')
          .eq('id', currentUserId)
          .maybeSingle();

      print('[RIDER_TRACKING] Profile récupéré: $userProfile');

      if (mounted && userProfile != null) {
        final firstName = userProfile['first_name'];
        final lastName = userProfile['last_name'];
        print('[RIDER_TRACKING] first_name: $firstName, last_name: $lastName');

        setState(() {
          _riderName = firstName != null
              ? '${firstName} ${lastName ?? ''}'.trim()
              : null;
        });

        print('[RIDER_TRACKING] ✅ Nom du rider chargé: $_riderName');
      } else {
        print('[RIDER_TRACKING] ⚠️ Profile null ou widget not mounted');
      }
    } catch (e) {
      print('[RIDER_TRACKING] Erreur chargement nom rider: $e');
    }
  }

  Future<void> _loadCarIcon() async {
    // Utiliser une icône triangulaire cyan/turquoise pour une meilleure visibilité
    print('[RIDER_TRACKING] Using cyan triangle marker for driver vehicle');
    _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    if (mounted) {
      setState(() {});
    }
  }

  void _fitAllMarkers() {
    if (_mapController == null || _driverPosition == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        [
          _driverPosition!.latitude,
          _pickupPosition.latitude,
          _destinationPosition.latitude
        ].reduce((a, b) => a < b ? a : b),
        [
          _driverPosition!.longitude,
          _pickupPosition.longitude,
          _destinationPosition.longitude
        ].reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [
          _driverPosition!.latitude,
          _pickupPosition.latitude,
          _destinationPosition.latitude
        ].reduce((a, b) => a > b ? a : b),
        [
          _driverPosition!.longitude,
          _pickupPosition.longitude,
          _destinationPosition.longitude
        ].reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _showCompletionDialog(String status) {
    print('[RIDER_TRACKING] _showCompletionDialog called with status: $status');
    if (status != 'completed') {
      print('[RIDER_TRACKING] Status is not completed, returning');
      return;
    }
    print('[RIDER_TRACKING] Showing completion dialog/bottom sheet');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompletionSheet(
        driver: widget.driver,
        price: widget.price,
        tripId: widget.tripId,
      ),
    );
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
            Expanded(child: Text('Signaler un No Show')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le chauffeur ne s\'est pas présenté ou a disparu ?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '• La course sera automatiquement annulée\n'
              '• Le chauffeur perdra 1 jeton\n'
              '• Vous serez remboursé(e) si applicable',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                hintText: 'Ex: Pas de nouvelles depuis 15 minutes',
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
      final riderId = Supabase.instance.client.auth.currentUser?.id;
      if (riderId == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final driverId = widget.driver['id'];
      if (driverId == null) {
        throw Exception('ID chauffeur non trouvé');
      }

      await NoShowService.reportNoShow(
        tripId: widget.tripId,
        reportedBy: riderId,
        reportedUser: driverId,
        userType: 'driver',
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

        // Retour à l'écran d'accueil
        context.go('/home');
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

  /// Fonction pour notifier l'arrivée du chauffeur avec son et notification visuelle
  void _notifyDriverArrived() {
    // Jouer un son système (ding ding)
    SystemSound.play(SystemSoundType.alert);
    // Petit délai puis rejouer pour faire "ding ding"
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemSound.play(SystemSoundType.alert);
    });

    // Afficher une notification visuelle
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: AppTheme.primaryOrange, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Votre chauffeur est arrivé !',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '${widget.driver['full_name']} vous attend au point de départ.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Afficher le popup de message reçu
  void _showReceivedMessagePopup(Map<String, dynamic> message) {
    // Jouer un son de notification
    SystemSound.play(SystemSoundType.click);

    final senderName = widget.driver['full_name']?.toString() ??
        widget.driver['name']?.toString() ??
        'Chauffeur';
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
                  tripId: widget.tripId,
                  senderId: currentUserId,
                  receiverId: widget.driver['id'],
                  senderType: 'rider',
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

  /// Ouvre Waze avec la destination
  Future<void> _openWaze() async {
    final targetLat = widget.destinationLat;
    final targetLng = widget.destinationLng;
    final targetName = widget.destination;

    final encodedName = Uri.encodeComponent(targetName);
    final url = 'waze://?ll=$targetLat,$targetLng&q=$encodedName&navigate=yes';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _openGoogleMaps();
      }
    } catch (e) {
      print('[RIDER_TRACKING] Error opening Waze: $e');
      _openGoogleMaps();
    }
  }

  /// Ouvre Google Maps avec la destination
  Future<void> _openGoogleMaps() async {
    final targetLat = widget.destinationLat;
    final targetLng = widget.destinationLng;
    final targetName = widget.destination;

    String url = 'https://www.google.com/maps/dir/?api=1';

    // Ajouter le point de départ (position actuelle du passager)
    url += '&origin=${widget.departureLat},${widget.departureLng}';

    // Ajouter la destination
    url += '&destination=$targetLat,$targetLng';

    // Ajouter le nom du lieu
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
      print('[RIDER_TRACKING] Error opening Google Maps: $e');
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

  /// Ouvre Apple Maps avec la destination (compatible CarPlay)
  Future<void> _openAppleMaps() async {
    final targetLat = widget.destinationLat;
    final targetLng = widget.destinationLng;
    final targetName = widget.destination;

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
        _openGoogleMaps();
      }
    } catch (e) {
      print('[RIDER_TRACKING] Error opening Apple Maps: $e');
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Chauffeur en route';
      case 'arrived':
        return 'Chauffeur arrivé';
      case 'started':
        return 'Course en cours';
      case 'completed':
        return 'Course terminée';
      default:
        return 'En attente...';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.green;
      case 'started':
        return AppTheme.primaryOrange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Debug: Afficher les données du chauffeur reçues
    print('[RIDER_TRACKING] Driver data received: ${widget.driver}');
    final driverId = widget.driver['id'] as String?;
    print('[RIDER_TRACKING] Extracted driverId: $driverId');

    // Watch la position du chauffeur pour l'affichage de l'ETA
    final driverPositionAsync = driverId != null && driverId.isNotEmpty
        ? ref.watch(driverLocationStreamProvider(driverId))
        : const AsyncValue<Map<String, dynamic>>.loading();

    // Obtenir le tripAsync et le statut en premier pour l'utiliser dans les listeners
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));
    final status = tripAsync.value?['status'] as String?;
    final canCancel =
        status != 'completed' && status != 'cancelled' && status != null;

    // Écouter la position du chauffeur pour mettre à jour la carte
    if (driverId != null && driverId.isNotEmpty) {
      print('[RIDER_TRACKING] Setting up listener for driver: $driverId');
      ref.listen<AsyncValue<Map<String, dynamic>>>(
          driverLocationStreamProvider(driverId), (prev, next) {
        print('[RIDER_TRACKING] Driver location listener triggered');
        next.when(
          data: (locationData) {
            print('[RIDER_TRACKING] Driver location update received');
            print('[RIDER_TRACKING] Location data keys: ${locationData.keys}');
            print(
                '[RIDER_TRACKING] current_lat: ${locationData['current_lat']}');
            print(
                '[RIDER_TRACKING] current_lng: ${locationData['current_lng']}');
            print(
                '[RIDER_TRACKING] Previous _driverPosition: $_driverPosition');

            if (locationData['current_lat'] != null && mounted) {
              final newPosition = LatLng(
                  locationData['current_lat'], locationData['current_lng']);
              print(
                  '[RIDER_TRACKING] Updating _driverPosition to: $newPosition');
              setState(() {
                _driverPosition = newPosition;
              });
              print('[RIDER_TRACKING] _driverPosition updated successfully');
            } else {
              print(
                  '[RIDER_TRACKING] WARNING: current_lat is null or widget not mounted');
            }
          },
          loading: () => print('[RIDER_TRACKING] Loading driver location...'),
          error: (e, s) {
            print('[RIDER_TRACKING] ERROR loading driver location: $e');
            print('[RIDER_TRACKING] Stack trace: $s');
          },
        );
      });
    } else {
      print('[RIDER_TRACKING] WARNING: driverId is null or empty!');
      print(
          '[RIDER_TRACKING] Full driver map keys: ${widget.driver.keys.toList()}');
      print('[RIDER_TRACKING] Full driver map: ${widget.driver}');
    }

    ref.listen<AsyncValue<Map<String, dynamic>>>(
        tripStreamProvider(widget.tripId), (prev, next) {
      print('[RIDER_TRACKING] ===== TRIP UPDATE RECEIVED =====');
      print('[RIDER_TRACKING] Previous value: ${prev?.value}');
      print('[RIDER_TRACKING] Next value: ${next.value}');

      _showCompletionDialog(next.value?['status'] ?? '');

      // Détecter si le chauffeur a envoyé une notification d'arrivée
      final notificationTime =
          next.value?['driver_arrived_notification'] as String?;
      print(
          '[RIDER_TRACKING] Notification check: $notificationTime (last: $_lastNotificationTime)');
      print(
          '[RIDER_TRACKING] Comparison: notificationTime != null? ${notificationTime != null}');
      print(
          '[RIDER_TRACKING] Comparison: notificationTime != _lastNotificationTime? ${notificationTime != _lastNotificationTime}');
      print('[RIDER_TRACKING] Comparison: mounted? $mounted');

      if (notificationTime != null &&
          notificationTime != _lastNotificationTime &&
          mounted) {
        print('[RIDER_TRACKING] 🔔 TRIGGERING driver arrived notification!');
        _lastNotificationTime = notificationTime;
        _notifyDriverArrived();
      } else {
        print(
            '[RIDER_TRACKING] ❌ Notification NOT triggered - Condition failed');
      }
    });

    // Écouter les nouveaux messages et afficher automatiquement un popup
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
        messagesStreamProvider(widget.tripId),
        (prev, next) {
          next.whenData((messages) {
            for (final message in messages) {
              final messageId = message['id'] as String;
              final receiverId = message['receiver_id'] as String?;

              // Si c'est un nouveau message pour moi que je n'ai pas encore vu
              if (receiverId == currentUserId &&
                  !_seenMessageIds.contains(messageId) &&
                  mounted) {
                _seenMessageIds.add(messageId);

                // Afficher le popup après un court délai
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _showReceivedMessagePopup(message);
                  }
                });
              }
            }
          });
        },
      );

      // Écouter les accusés de réception (quand l'autre lit nos messages)
      ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
        readReceiptsProvider((tripId: widget.tripId, userId: currentUserId)),
        (prev, next) {
          next.whenData((readMessages) {
            // Comparer avec les messages précédents pour voir s'il y en a de nouveaux lus
            final prevMessages = prev?.valueOrNull ?? [];
            final newReadMessages = readMessages.where((msg) {
              return !prevMessages.any((prevMsg) => prevMsg['id'] == msg['id']);
            }).toList();

            // Afficher une notification discrète pour chaque nouveau message lu
            if (newReadMessages.isNotEmpty && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.done_all, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Le chauffeur a lu votre message'),
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
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Affiche un loader tant que la position du chauffeur n'est pas connue.
            if (_driverPosition == null)
              const Center(child: CircularProgressIndicator())
            else
              GoogleMap(
                initialCameraPosition: CameraPosition(
                    target: _pickupPosition, // Centre la carte sur le départ
                    zoom: 15),
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Ajuste la caméra pour afficher tous les marqueurs après un petit délai
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _fitAllMarkers();
                  });
                },
                markers: {
                  // Pin bleu pour le chauffeur
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: _driverPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue),
                    infoWindow: InfoWindow(
                      title: (widget.driver['name'] ??
                              widget.driver['full_name'] ??
                              'Chauffeur')
                          .toString(),
                      snippet: tripAsync.when(
                          data: (t) => _getStatusText(t['status']),
                          loading: () => '...',
                          error: (e, s) => 'Erreur'),
                    ),
                  ),
                  // Pin vert pour le point de départ
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _pickupPosition,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: InfoWindow(
                      title: 'Point de départ',
                      snippet: widget.departure,
                    ),
                  ),
                  // Pin rouge pour la destination
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: _destinationPosition,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: InfoWindow(
                      title: 'Destination',
                      snippet: widget.destination,
                    ),
                  ),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            Positioned(
              top: 16,
              left: 16,
              child: Semantics(
                label: 'Retour',
                button: true,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: tripAsync.when(
                  data: (trip) {
                    final status = trip['status'] as String;
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ).animate().fadeIn().scale(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink()),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.35,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 35,
                              color: AppTheme.primaryOrange,
                            ),
                          ).animate().scale(delay: 200.ms),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.driver['full_name']?.toString() ??
                                      widget.driver['name']?.toString() ??
                                      'Chauffeur',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ).animate().fadeIn(delay: 300.ms),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.driver['rating']?.toString() ?? '5.0'} • ${widget.driver['total_trips']?.toString() ?? '0'} trajets',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ).animate().fadeIn(delay: 400.ms),
                                const SizedBox(height: 4),
                                Text(
                                  widget.driver['vehicle_plate']?.toString() ??
                                      widget.driver['vehicleNumber']
                                          ?.toString() ??
                                      '-',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ).animate().fadeIn(delay: 500.ms),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Semantics(
                                label: 'Appeler le chauffeur',
                                button: true,
                                child: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.primaryOrange.withOpacity(0.1),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.phone,
                                      color: AppTheme.primaryOrange,
                                    ),
                                    onPressed: () async {
                                      final currentUserId = Supabase
                                          .instance.client.auth.currentUser?.id;
                                      if (currentUserId == null) return;

                                      // Vérifier le statut du trip avant d'initier l'appel
                                      final tripAsync = ref.read(
                                          tripStreamProvider(widget.tripId));
                                      final tripData = tripAsync.valueOrNull;

                                      if (tripData == null) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Impossible de récupérer les informations de la course'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      final status =
                                          tripData['status'] as String?;

                                      // Autoriser l'appel uniquement si le trip est actif
                                      if (status != 'accepted' &&
                                          status != 'arrived' &&
                                          status != 'started') {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'L\'appel n\'est pas disponible pour cette course'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      try {
                                        // Utiliser le nom déjà chargé ou valeur par défaut
                                        final callerName =
                                            _riderName ?? 'Passager';

                                        print(
                                            '[RIDER_TRACKING] 📞 Initiation appel avec nom: $callerName');
                                        print(
                                            '[RIDER_TRACKING] 📊 Trip status: $status');

                                        // Initier l'appel
                                        final callId = await ref
                                            .read(callServiceProvider)
                                            .initiateCall(
                                              tripId: widget.tripId,
                                              callerId: currentUserId,
                                              receiverId: widget.driver['id'],
                                              callerType: 'rider',
                                              callerName: callerName,
                                            );

                                        if (mounted) {
                                          // Naviguer vers l'écran d'appel
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => CallScreen(
                                                tripId: widget.tripId,
                                                receiverId: widget.driver['id'],
                                                receiverName: widget
                                                        .driver['full_name']
                                                        ?.toString() ??
                                                    widget.driver['name']
                                                        ?.toString() ??
                                                    'Chauffeur',
                                                receiverType: 'driver',
                                                callId: callId,
                                                isIncoming: false,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Erreur: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ).animate().scale(delay: 600.ms),
                              const SizedBox(height: 8),
                              Semantics(
                                label: 'Envoyer un message',
                                button: true,
                                child: Consumer(
                                  builder: (context, ref, child) {
                                    final currentUserId = Supabase
                                        .instance.client.auth.currentUser?.id;
                                    final unreadAsync = currentUserId != null
                                        ? ref.watch(unreadMessagesProvider((
                                            tripId: widget.tripId,
                                            userId: currentUserId
                                          )))
                                        : const AsyncValue<int>.data(0);

                                    final unreadCount =
                                        unreadAsync.valueOrNull ?? 0;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppTheme
                                              .primaryOrange
                                              .withOpacity(0.1),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.message,
                                              color: AppTheme.primaryOrange,
                                            ),
                                            onPressed: () {
                                              final currentUserId = Supabase
                                                  .instance
                                                  .client
                                                  .auth
                                                  .currentUser
                                                  ?.id;
                                              if (currentUserId == null) return;

                                              // Afficher popup pour composer un message
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    ComposeMessageDialog(
                                                  receiverName: widget
                                                          .driver['full_name']
                                                          ?.toString() ??
                                                      widget.driver['name']
                                                          ?.toString() ??
                                                      'Chauffeur',
                                                  onSend: (message) async {
                                                    await ref
                                                        .read(
                                                            chatServiceProvider)
                                                        .sendMessage(
                                                          tripId: widget.tripId,
                                                          senderId:
                                                              currentUserId,
                                                          receiverId: widget
                                                              .driver['id'],
                                                          senderType: 'rider',
                                                          message: message,
                                                        );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 20,
                                                minHeight: 20,
                                              ),
                                              child: Text(
                                                unreadCount > 9
                                                    ? '9+'
                                                    : unreadCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ).animate().scale(delay: 700.ms),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // CORRECTION: On utilise tripAsync pour afficher la bonne carte d'information
                      // en fonction du statut réel de la course.
                      tripAsync.when(
                        data: (trip) {
                          final status = trip['status'] as String;
                          if (status == 'accepted') {
                            // Calcul de l'ETA en temps réel
                            String etaText = 'Arrivée imminente';

                            driverPositionAsync.whenData((locationData) {
                              final lat = locationData['current_lat'] as num?;
                              final lng = locationData['current_lng'] as num?;

                              if (lat != null && lng != null) {
                                final driverPos =
                                    LatLng(lat.toDouble(), lng.toDouble());
                                final tripService =
                                    ref.read(tripServiceProvider);
                                final eta = tripService.calculateEtaMinutes(
                                  driverPos,
                                  _pickupPosition,
                                );
                                etaText = 'Arrivée dans $eta min';
                              }
                            });

                            return Column(
                              children: [
                                _InfoCard(
                                  icon: Icons.access_time,
                                  title: 'Chauffeur en route',
                                  value: etaText,
                                  color: Colors.blue,
                                )
                                    .animate()
                                    .fadeIn(delay: 800.ms)
                                    .slideX(begin: -0.2),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showNoShowDialog(context),
                                    icon: const Icon(Icons.report_problem,
                                        size: 24),
                                    label: const Text(
                                      'Signaler chauffeur absent',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                          color: Colors.red, width: 2),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(delay: 900.ms)
                                    .slideX(begin: -0.2),
                              ],
                            );
                          }
                          if (status == 'arrived') {
                            return _InfoCard(
                              icon: Icons.check_circle,
                              title: 'Chauffeur arrivé',
                              value: 'Prêt à partir',
                              color: Colors.green,
                            ).animate().fadeIn().scale();
                          }
                          // Bouton de navigation externe si la course est démarrée
                          if (status == 'started') {
                            return Column(
                              children: [
                                _InfoCard(
                                  icon: Icons.drive_eta,
                                  title: 'Course en cours',
                                  value: 'En route vers la destination',
                                  color: AppTheme.primaryOrange,
                                ).animate().fadeIn().scale(),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _chooseNavigationApp,
                                    icon:
                                        const Icon(Icons.navigation, size: 24),
                                    label: const Text(
                                      'Ouvrir la navigation',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryOrange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 6,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 100.ms).scale(),
                              ],
                            );
                          }
                          return const SizedBox
                              .shrink(); // Ne rien afficher pour les autres statuts
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      _TripDetailRow(
                        icon: Icons.location_on,
                        iconColor: AppTheme.primaryOrange,
                        label: 'Départ',
                        value: widget.departure,
                      ).animate().fadeIn(delay: 900.ms),
                      const Divider(height: 24),
                      _TripDetailRow(
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        label: 'Destination',
                        value: widget.destination,
                      ).animate().fadeIn(delay: 1000.ms),
                      const Divider(height: 24),
                      _TripDetailRow(
                        icon: Icons.payments,
                        iconColor: Colors.green,
                        label: 'Prix',
                        value: '${widget.price} F',
                      ).animate().fadeIn(delay: 1100.ms),
                      const SizedBox(height: 24),
                      // Bouton d'annulation désactivé pour éviter les annulations intempestives
                      Semantics(
                        label: 'Annuler la course',
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: null, // Bouton toujours désactivé
                          icon: const Icon(Icons.cancel),
                          label: const Text('Annuler la course'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ).animate().fadeIn(delay: 1200.ms).scale(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la course?'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette course? Des frais d\'annulation peuvent s\'appliquer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              _cancelTrip();
            },
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip() async {
    Navigator.of(context).pop(); // Ferme la boîte de dialogue
    try {
      await ref.read(tripServiceProvider).cancelTrip(widget.tripId);
      if (mounted) {
        // Réinitialiser les providers de départ et destination
        ref.read(departureProvider.notifier).state = null;
        ref.read(destinationProvider.notifier).state = null;

        context.goNamed('home'); // Retour à l'accueil
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La course a été annulée.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'annulation: $e')),
        );
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
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
                  color: theme.textTheme.bodySmall?.color,
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

class _CompletionSheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final int price;
  final String tripId;

  const _CompletionSheet({
    required this.driver,
    required this.price,
    required this.tripId,
  });

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  int? _selectedRating; // Note sélectionnée par l'utilisateur

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ).animate().scale(duration: 500.ms),
              const SizedBox(height: 16),
              Text(
                'Course terminée!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Merci d\'avoir utilisé nos services',
                style: theme.textTheme.bodyMedium,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prix de la course',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          '${widget.price} F',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).scale(),
              const SizedBox(height: 24),
              Text(
                'Notez votre chauffeur',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) {
                    final starValue = index + 1;
                    return Semantics(
                      label: 'Note $starValue étoile${index > 0 ? 's' : ''}',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          _selectedRating != null &&
                                  starValue <= _selectedRating!
                              ? Icons.star
                              : Icons.star_border,
                          size: 40,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedRating = starValue;
                          });
                        },
                      ).animate().scale(delay: (600 + index * 50).ms),
                    );
                  },
                ),
              ),
              if (_selectedRating == null)
                const Text(
                  'Évaluation obligatoire avant de continuer',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Retour à l\'accueil',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedRating != null
                        ? () async {
                            print(
                                '[RIDER_TRACKING] Rider clicked Valider with rating: $_selectedRating');
                            // Sauvegarder la note dans la base de données
                            try {
                              await Supabase.instance.client
                                  .from('trips')
                                  .update({
                                'driver_rating': _selectedRating
                              }).eq('id', widget.tripId);

                              print(
                                  '[RIDER_TRACKING] Rating saved: $_selectedRating');
                              if (mounted) {
                                print(
                                    '[RIDER_TRACKING] Closing bottom sheet and navigating to home');
                                // Fermer d'abord le bottom sheet d'évaluation
                                Navigator.of(context).pop();
                                // Attendre un instant pour que le bottom sheet se ferme complètement
                                await Future.delayed(
                                    const Duration(milliseconds: 100));
                                // Ensuite fermer l'écran de tracking et naviguer vers home
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  context.goNamed('home');
                                }
                              }
                            } catch (e) {
                              print('[RIDER_TRACKING] Error saving rating: $e');
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
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text('Valider'),
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }
}
