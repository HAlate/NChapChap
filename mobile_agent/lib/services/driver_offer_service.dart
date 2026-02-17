import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class DriverOfferService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAvailableTrips(
      String vehicleType) async {
    try {
      print('DEBUG SERVICE: Fetching trips for vehicle type: $vehicleType');
      final response = await _supabase
          .from('trips')
          .select('''
            *,
            rider:users!trips_rider_id_fkey (
              id,
              full_name,
              phone
            )
          ''')
          .eq('status', 'pending')
          .or('vehicle_type.eq.$vehicleType,vehicle_type.eq.any')
          .order('created_at', ascending: false);

      print('DEBUG SERVICE: Response: $response');
      print('DEBUG SERVICE: Response type: ${response.runtimeType}');
      final trips = List<Map<String, dynamic>>.from(response);
      print('DEBUG SERVICE: Trips count: ${trips.length}');
      return trips;
    } catch (e, stackTrace) {
      print('DEBUG SERVICE: Error: $e');
      print('DEBUG SERVICE: Stack trace: $stackTrace');
      throw Exception('Failed to fetch available trips: $e');
    }
  }

  /// Surveille les nouvelles demandes de courses disponibles en temps réel.
  /// Filtre automatiquement les courses dans un rayon de 5 km.
  Stream<List<Map<String, dynamic>>> watchAvailableTrips(
      String vehicleType, Ref ref) {
    print('[OfferService] ========== STREAM INITIALIZED ==========');
    print('[OfferService] Vehicle type: $vehicleType');
    final controller = StreamController<List<Map<String, dynamic>>>();

    // Fonction pour récupérer les trips depuis la vue et filtrer par distance
    Future<void> fetcher() async {
      try {
        print('[OfferService] ========== FETCHING TRIPS ==========');

        // Récupérer l'ID du driver actuel
        final driverId = _supabase.auth.currentUser?.id;
        if (driverId == null) {
          controller.add([]);
          return;
        }

        // Récupérer la position actuelle du chauffeur (désactivé temporairement)
        Position? driverPosition;
        // NOTE: Filtrage par distance désactivé pour déboguer
        // print('[OfferService] ⚠ GPS filtering disabled - showing all trips');
        driverPosition = null;

        // Essayer d'abord avec la vue (si elle existe)
        try {
          print('[OfferService] Querying available_trips_with_riders_view...');
          final response = await _supabase
              .from('available_trips_with_riders_view')
              .select()
              .or('vehicle_type.eq.$vehicleType,vehicle_type.eq.any')
              .order('created_at', ascending: false);

          var trips = List<Map<String, dynamic>>.from(response);
          print('[OfferService] ✓ View returned ${trips.length} trip(s)');

          // Filtrer les trips où ce driver a déjà une offre 'rejected'
          final rejectedOffers = await _supabase
              .from('trip_offers')
              .select('trip_id')
              .eq('driver_id', driverId)
              .eq('status', 'rejected');

          final rejectedTripIds = (rejectedOffers as List)
              .map((offer) => offer['trip_id'] as String)
              .toSet();

          trips = trips.where((trip) {
            return !rejectedTripIds.contains(trip['id']);
          }).toList();

          // print('[OfferService] ✓ After filtering rejected: ${trips.length} trip(s)');

          // Afficher les détails des trips
          // for (var trip in trips) {
          //   print(
          //       '[OfferService]   - Trip ${trip['id']}: ${trip['departure']} → ${trip['destination']}');
          // }

          // Filtrer par distance si on a la position du chauffeur
          if (driverPosition != null) {
            // print(
            //     '[OfferService] Filtering trips by 5km radius from driver...');
            trips = trips.where((trip) {
              final pickupLat = trip['departure_lat'] as double?;
              final pickupLng = trip['departure_lng'] as double?;

              if (pickupLat == null || pickupLng == null) {
                // print(
                //     '[OfferService]   - Trip ${trip['id']}: NO COORDINATES, skipped');
                return false;
              }

              final distance = Geolocator.distanceBetween(
                driverPosition!.latitude,
                driverPosition.longitude,
                pickupLat,
                pickupLng,
              );

              final distanceInKm = distance / 1000;
              final included = distanceInKm <= 5.0;
              // print(
              //     '[OfferService]   - Trip ${trip['id']}: ${distanceInKm.toStringAsFixed(2)} km ${included ? "✓ INCLUDED" : "✗ TOO FAR"}');

              return included;
            }).toList();

            // print(
            //     '[OfferService] ✓ ${trips.length} trip(s) within 5 km radius');
          } else {
            // print(
            //     '[OfferService] ⚠ No GPS - showing all ${trips.length} trips');
          }

          if (!controller.isClosed) {
            // print('[OfferService] Adding ${trips.length} trips to stream');
            controller.add(trips);
          }
          return;
        } catch (viewError) {
          // print('[OfferService] ⚠ View query failed: $viewError');
          // print('[OfferService] Falling back to direct table query...');
        }

        // Fallback: requête directe sur la table trips
        // print('[OfferService] Querying trips table directly...');
        final response = await _supabase
            .from('trips')
            .select('''
              *,
              rider:users!trips_rider_id_fkey (
                id,
                full_name,
                phone
              )
            ''')
            .eq('status', 'pending')
            .or('vehicle_type.eq.$vehicleType,vehicle_type.eq.any')
            .order('created_at', ascending: false);

        var trips = List<Map<String, dynamic>>.from(response);
        // print('[OfferService] ✓ Table returned ${trips.length} trip(s)');

        // Filtrer les trips où ce driver a déjà une offre 'rejected'
        final rejectedOffers = await _supabase
            .from('trip_offers')
            .select('trip_id')
            .eq('driver_id', driverId)
            .eq('status', 'rejected');

        final rejectedTripIds = (rejectedOffers as List)
            .map((offer) => offer['trip_id'] as String)
            .toSet();

        trips = trips.where((trip) {
          return !rejectedTripIds.contains(trip['id']);
        }).toList();

        // print('[OfferService] ✓ After filtering rejected: ${trips.length} trip(s)');

        // Filtrer par âge (< 15 minutes) si pas de vue
        // print('[OfferService] Filtering trips by age (< 15 min)...');
        trips = trips.where((trip) {
          final createdAtStr = trip['created_at'] as String?;
          if (createdAtStr == null) return false;

          final createdAt = DateTime.tryParse(createdAtStr);
          if (createdAt == null) return false;

          final age = DateTime.now().difference(createdAt);
          final included = age.inMinutes < 15;
          // print(
          //     '[OfferService]   - Trip ${trip['id']}: ${age.inMinutes} min old ${included ? "✓" : "✗"}');
          return included;
        }).toList();

        // print('[OfferService] ✓ ${trips.length} recent trip(s)');

        // Filtrer par distance si on a la position du chauffeur
        if (driverPosition != null) {
          // print('[OfferService] Filtering by 5km radius...');
          trips = trips.where((trip) {
            final pickupLat = trip['departure_lat'] as double?;
            final pickupLng = trip['departure_lng'] as double?;

            if (pickupLat == null || pickupLng == null) {
              // print(
              //     '[OfferService]   - Trip ${trip['id']}: NO COORDINATES, skipped');
              return false;
            }

            final distance = Geolocator.distanceBetween(
              driverPosition!.latitude,
              driverPosition.longitude,
              pickupLat,
              pickupLng,
            );

            final distanceInKm = distance / 1000;
            final included = distanceInKm <= 5.0;
            // print(
            //     '[OfferService]   - Trip ${trip['id']}: ${distanceInKm.toStringAsFixed(2)} km ${included ? "✓" : "✗"}');
            return included;
          }).toList();
          // print('[OfferService] ✓ ${trips.length} trip(s) within 5 km');
        } else {
          // print('[OfferService] ⚠ No GPS - showing all ${trips.length} trips');
        }

        // print(
        //     '[OfferService] ========== FINAL: ${trips.length} TRIPS ==========');

        if (!controller.isClosed) {
          controller.add(trips);
        }
      } catch (e, stackTrace) {
        print('[OfferService] Error fetching trips: $e');
        print('[OfferService] Stack trace: $stackTrace');
        if (!controller.isClosed) {
          controller.addError(e, stackTrace);
        }
      }
    }

    // 1. Chargement initial
    fetcher();

    // 1.5 Fetch supplémentaire après 500ms pour s'assurer d'avoir les données
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) {
        // print('[OfferService] 🔄 Quick refresh after 500ms');
        fetcher();
      }
    });

    // 2. Rafraîchissement périodique toutes les 3 secondes
    Timer? periodicTimer;
    periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // print('[OfferService] ⏰ Periodic refresh (every 3s)');
      fetcher();
    });

    // 3. Écoute des changements en temps réel sur la table trips
    final channelName =
        'driver-trips-watcher-$vehicleType-${DateTime.now().millisecondsSinceEpoch}';
    print('[OfferService] Creating channel: $channelName');
    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            print('[OfferService] ===== NEW TRIP INSERTED =====');
            print('[OfferService] Payload: ${payload.newRecord}');
            final newVehicleType = payload.newRecord['vehicle_type'];
            print('[OfferService] New trip vehicle_type: $newVehicleType');
            print('[OfferService] Watching vehicle_type: $vehicleType');

            // Vérifier si c'est le bon type de véhicule OU 'any' avant de rafraîchir
            if (newVehicleType == vehicleType || newVehicleType == 'any') {
              print('[OfferService] ✓ Match! Refreshing trips...');
              fetcher();
            } else {
              print('[OfferService] ✗ No match. Ignoring.');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            print('[OfferService] Trip updated: ${payload.newRecord['id']}');
            final newVehicleType = payload.newRecord['vehicle_type'];
            final newStatus = payload.newRecord['status'];
            print(
                '[OfferService] Status: $newStatus, vehicle_type: $newVehicleType');

            // Rafraîchir si c'est notre type de véhicule OU 'any'
            if (newVehicleType == vehicleType || newVehicleType == 'any') {
              print('[OfferService] ✓ Refreshing trips...');
              fetcher();
            }
          },
        )
        .subscribe((status, error) {
      print('[OfferService] Channel subscription status: $status');
      if (error != null) {
        print('[OfferService] Channel error: $error');
      }
    });

    // 4. Nettoyage à la fermeture
    controller.onCancel = () {
      // print('[OfferService] Closing stream');
      periodicTimer?.cancel();
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Enrichit les trips avec les informations du rider depuis la base de données
  Future<List<Map<String, dynamic>>> _enrichTripsWithRiderInfo(
      List<Map<String, dynamic>> trips) async {
    if (trips.isEmpty) return trips;

    // Récupérer tous les rider IDs
    final riderIds = trips
        .map((trip) => trip['rider_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (riderIds.isEmpty) return trips;

    // Charger les infos des riders en une seule requête
    final riders = await _supabase
        .from('users')
        .select('id, full_name, phone')
        .inFilter('id', riderIds);

    // Créer une map pour un accès rapide
    final riderMap = {
      for (var rider in riders) rider['id']: rider,
    };

    // Enrichir chaque trip avec les infos du rider
    final enrichedTrips = trips.map((trip) {
      final riderId = trip['rider_id'] as String?;
      final rider = riderId != null ? riderMap[riderId] : null;

      return {
        ...trip,
        'rider_full_name': rider?['full_name'] ?? 'Client',
        'rider_phone': rider?['phone'],
      };
    }).toList();

    // Trier par date de création décroissante (plus récent en premier)
    enrichedTrips.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate); // Décroissant
    });

    return enrichedTrips;
  }

  /// Méthode privée pour obtenir l'ID de l'utilisateur authentifié.
  /// Lance une exception si l'utilisateur n'est pas connecté.
  String _getAuthenticatedUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return userId;
  }

  Future<int> getDriverTokenBalance() async {
    try {
      final userId = _getAuthenticatedUserId();

      final response = await _supabase
          .from('token_balances')
          .select('balance')
          .eq('user_id', userId)
          .eq('token_type', 'course')
          .maybeSingle();

      return response?['balance'] ?? 0;
    } catch (e) {
      throw Exception('Failed to fetch token balance: $e');
    }
  }

  Future<Map<String, dynamic>> createOffer({
    required String tripId,
    required int offeredPrice,
    required int etaMinutes,
    required double driverLat,
    required double driverLng,
  }) async {
    try {
      final userId = _getAuthenticatedUserId();

      print('DEBUG CREATE OFFER: User ID: $userId');
      print('DEBUG CREATE OFFER: Trip ID: $tripId');
      print('DEBUG CREATE OFFER: Price: $offeredPrice, ETA: $etaMinutes');

      final tokenBalance = await getDriverTokenBalance();
      print('DEBUG CREATE OFFER: Token balance: $tokenBalance');

      if (tokenBalance < 1) {
        throw Exception(
            'Insufficient tokens. You need at least 1 token to make an offer.');
      }

      final response = await _supabase
          .from('trip_offers')
          .insert({
            'trip_id': tripId,
            'driver_id': userId,
            'offered_price': offeredPrice,
            'eta_minutes': etaMinutes,
            'status': 'pending',
            'driver_lat_at_offer': driverLat,
            'driver_lng_at_offer': driverLng,
            'token_spent': false,
          })
          .select()
          .single();
      // Pas besoin d'enrichir ici, la navigation est gérée différemment.

      print(
          'DEBUG CREATE OFFER: Offer created successfully: ${response['id']}');
      return response;
    } catch (e) {
      throw Exception('Impossible de créer l\'offre: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDriverOffers() async {
    try {
      final userId = _getAuthenticatedUserId();
      final response = await _supabase.from('trip_offers').select('''
            *,
            trip:trips (
              *,
              rider:users!trips_rider_id_fkey (
                id,
                full_name,
                phone
              )
            )
          ''').eq('driver_id', userId).order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch driver offers: $e');
    }
  }

  Future<Map<String, dynamic>?> getOfferForTrip(String tripId) async {
    try {
      final userId = _getAuthenticatedUserId();
      final response = await _supabase
          .from('trip_offers')
          .select('*')
          .eq('trip_id', tripId)
          .eq('driver_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch offer: $e');
    }
  }

  Stream<Map<String, dynamic>?> watchOffer(String offerId) {
    // CORRECTION: L'utilisation de .stream() sur une vue ne notifie pas toujours
    // les mises à jour (UPDATE). On passe à une implémentation manuelle avec un
    // StreamController pour plus de fiabilité.
    final controller = StreamController<Map<String, dynamic>?>();

    // Fonction pour récupérer les données à jour depuis la vue.
    Future<void> fetcher() async {
      try {
        print('[DRIVER_DEBUG] watchOffer: Fetching data for offer $offerId');
        final response = await _supabase
            .from(
                'trip_offers_with_driver') // La vue contient les données enrichies
            .select()
            .eq('id', offerId)
            .maybeSingle();

        print(
            '[DRIVER_DEBUG] watchOffer: Fetched data - status: ${response?['status']}, counter_price: ${response?['counter_price']}, driver_counter_price: ${response?['driver_counter_price']}');

        if (!controller.isClosed) {
          controller.add(response);
        }
      } catch (e) {
        print('[DRIVER_DEBUG] watchOffer: Error fetching data: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Chargement initial avec un petit délai.
    // Cela résout une "race condition" où l'écran de négociation essaie de lire
    // l'offre immédiatement après sa création, avant qu'elle ne soit pleinement
    // visible dans la vue.
    print(
        '[DRIVER_DEBUG] watchOffer: Scheduling initial fetch for offer $offerId');
    Future.delayed(const Duration(milliseconds: 300), fetcher);

    // 2. Écoute des changements sur la table 'trip_offers'
    // On donne un nom unique au canal pour inclure l'ID de l'offre et éviter les conflits.
    print(
        '[DRIVER_DEBUG] watchOffer: Setting up Realtime channel for offer $offerId');

    print('[DRIVER_DEBUG] watchOffer: Creating channel...');
    final channel = _supabase.channel('driver-offer-watcher-$offerId');

    print('[DRIVER_DEBUG] watchOffer: Adding onPostgresChanges listener...');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all, // Écoute INSERT, UPDATE, DELETE
      schema: 'public',
      table: 'trip_offers',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: offerId),
      callback: (payload) {
        // CORRECTION: Toujours recharger depuis la vue pour obtenir les données enrichies
        // (trip, rider, etc.) au lieu de pousser directement payload.newRecord qui ne contient
        // que les champs de la table trip_offers.
        print(
            '[DRIVER_DEBUG] watchOffer: ${payload.eventType} received. Re-fetching data from view for offer $offerId.');
        fetcher();
      },
    );

    print('[DRIVER_DEBUG] watchOffer: About to call .subscribe()...');
    channel.subscribe((status, [error]) {
      print('[DRIVER_DEBUG] watchOffer: ✅ Subscribe callback executed!');
      print('[DRIVER_DEBUG] watchOffer: Channel subscription status: $status');
      if (error != null) {
        print(
            '[DRIVER_DEBUG] watchOffer: ❌ Channel subscription error: $error');
      }
    });
    print('[DRIVER_DEBUG] watchOffer: .subscribe() called successfully');

    // 3. Nettoyage à la fermeture du stream
    controller.onCancel = () {
      print('[DRIVER_DEBUG] watchOffer: Removing channel for offer $offerId');
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> acceptCounterOffer({
    required String offerId,
    required String tripId, // Pass tripId directly to avoid an extra query
    required int finalPrice,
  }) async {
    try {
      print(
          '[DRIVER_DEBUG] acceptCounterOffer: Calling RPC for offer $offerId, trip $tripId, finalPrice: $finalPrice');

      // Utilise la fonction RPC spécifique pour le driver qui accepte la contre-offre du rider
      await _supabase.rpc('driver_accept_counter_offer', params: {
        'p_offer_id': offerId,
        'p_trip_id': tripId,
        'p_final_price': finalPrice,
      });
      print('[DRIVER_DEBUG] acceptCounterOffer: RPC call successful.');
    } on PostgrestException catch (e) {
      // Amélioration de la gestion des erreurs pour être plus spécifique.
      // Enhanced logging to make it absolutely clear this is a server-side SQL error.
      print('FATAL: Server-side error in RPC `driver_accept_counter_offer`.');
      print('  > Message: ${e.message}');
      print('  > Details: ${e.details} (Code: ${e.code})');
      print(
          '  > ACTION REQUIRED: This error must be fixed in the SQL function definition in the Supabase SQL Editor.');
      throw Exception(
          'Erreur de base de données lors de l\'acceptation de l\'offre: ${e.message}');
    } catch (e, stackTrace) {
      print('Generic error while accepting counter offer: $e\n$stackTrace');
      throw Exception('Erreur inattendue lors de l\'acceptation de l\'offre.');
    }
  }

  Future<void> rejectCounterOffer(String offerId) async {
    try {
      // 1. Récupérer l'offre pour obtenir le trip_id
      final offerData = await _supabase
          .from('trip_offers')
          .select('trip_id, rider_id')
          .eq('id', offerId)
          .single();

      final String tripId = offerData['trip_id'] as String;
      final String? riderId = offerData['rider_id'] as String?;

      // 2. Mettre à jour le statut de l'offre à 'rejected'
      await _supabase
          .from('trip_offers')
          .update({'status': 'rejected'}).eq('id', offerId);

      // 3. NE PAS changer le status du trip - il reste 'pending' pour les autres drivers
      // Le trip sera visible pour d'autres drivers qui peuvent faire des offres

      // 4. TODO: Envoyer une notification au passager
      print(
          '[DRIVER_DEBUG] rejectCounterOffer: Offer rejected for trip $tripId, trip remains available for other drivers');
    } catch (e) {
      throw Exception('Failed to reject counter offer: $e');
    }
  }

  Future<void> makeCounterOffer({
    required String offerId,
    required int counterPrice,
  }) async {
    try {
      // Le driver fait une nouvelle offre en réponse à la contre-offre du rider
      // On met à jour offered_price et on efface counter_price (logique APPZEDGO)
      print(
          '[DRIVER_DEBUG] makeCounterOffer: Updating offered_price to $counterPrice and resetting counter_price for offerId: $offerId');
      await _supabase.from('trip_offers').update({
        'offered_price': counterPrice,
        'counter_price': null,
        'status': 'pending', // Retour au statut pending (attente rider)
      }).eq('id', offerId);
      print(
          '[DRIVER_DEBUG] makeCounterOffer: Successfully sent. Waiting for rider response.');
    } catch (e) {
      throw Exception('Failed to make counter offer: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDriverAcceptedTrips() async {
    try {
      final userId = _getAuthenticatedUserId();
      final response = await _supabase
          .from('trips')
          .select('''
            *,
            rider:users!trips_rider_id_fkey (
              id,
              full_name,
              phone
            )
          ''')
          .eq('driver_id', userId)
          .inFilter('status', ['accepted', 'started'])
          .order('accepted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch accepted trips: $e');
    }
  }

  /// Récupère toutes les offres faites par le driver connecté
  Future<List<Map<String, dynamic>>> getMyOffers() async {
    try {
      final userId = _getAuthenticatedUserId();
      print('DEBUG getMyOffers: Fetching offers for driver $userId');

      // Étape 1 : Récupérer les offres
      // Version optimisée : Récupère les offres, le trajet associé et le passager en une seule requête.
      // Cela évite le problème de "N+1 query".
      final response = await _supabase.from('trip_offers').select('''
            *,
            trip:trips (
              *,
              rider:users!trips_rider_id_fkey (
                id,
                full_name,
                phone
              )
            )
          ''').eq('driver_id', userId).order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      print('DEBUG getMyOffers: Error: $e');
      print('DEBUG getMyOffers: Stack trace: $stackTrace');
      throw Exception('Failed to fetch my offers: $e');
    }
  }

  /// Récupère les détails d'un trajet, y compris les informations sur le passager.
  Future<Map<String, dynamic>> getTripDetails(String tripId) async {
    try {
      final response = await _supabase.from('trips').select('''
        *,
        rider:users!trips_rider_id_fkey(
          id,
          full_name,
          phone
        )
      ''').eq('id', tripId).single();
      return response;
    } catch (e) {
      throw Exception(
          'Erreur lors de la récupération des détails du trajet: $e');
    }
  }

  /// Met à jour le statut d'un trajet.
  Future<void> updateTripStatus(String tripId, String status) async {
    try {
      await _supabase.from('trips').update({'status': status}).eq('id', tripId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut du trajet: $e');
    }
  }
}
