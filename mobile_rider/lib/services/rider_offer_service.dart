import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_offer.dart';

class RiderOfferService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // On utilise la vue SQL qui contient déjà toutes les données jointes.
  static const String _offersView = 'trip_offers_with_driver';

  Future<List<TripOffer>> getOffersForTrip(String tripId) async {
    try {
      print('DEBUG: Fetching offers for trip_id: $tripId');
      print('DEBUG: Using view: $_offersView');
      final response = await _supabase
          .from(_offersView)
          .select() // La vue contient déjà toutes les colonnes nécessaires
          .eq('trip_id', tripId) // La RLS s'occupe de la sécurité
          .neq('status', 'rejected') // Exclure les offres refusées
          .order('created_at', ascending: false);

      print('DEBUG: Raw response: $response');
      final offers =
          (response as List).map((item) => TripOffer.fromJson(item)).toList();
      print('DEBUG: Total offers found: ${offers.length}');
      if (offers.isNotEmpty) {
        print('DEBUG: First offer ID: ${offers.first.id}');
      }
      return offers;
    } catch (e) {
      print('DEBUG: Error in getOffersForTrip: $e');
      throw Exception('Erreur lors de la récupération des offres: $e');
    }
  }

  Future<TripOffer?> getOfferById(String offerId) async {
    try {
      print('DEBUG getOfferById: Fetching offer $offerId');
      final data = await _supabase
          .from(_offersView)
          .select()
          .eq('id', offerId)
          .maybeSingle();
      return data != null ? TripOffer.fromJson(data) : null;
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'offre: $e');
    }
  }

  Future<TripOffer> sendCounterOffer(String offerId, int counterPrice,
      {String? message}) async {
    try {
      print(
          '[RIDER_DEBUG] sendCounterOffer: Sending counter_price: $counterPrice for offerId: $offerId');

      // Le rider fait une contre-offre au prix proposé par le driver
      final updates = <String, dynamic>{
        'status': 'selected',
        'counter_price': counterPrice,
      };

      final response = await _supabase
          .from('trip_offers')
          .update(updates)
          .match({'id': offerId})
          .select()
          .single();

      print('[RIDER_DEBUG] sendCounterOffer: Update response: $response');

      final offer = await getOfferById(response['id'] as String);
      if (offer == null) {
        throw Exception('Offre non trouvée après contre-proposition');
      }

      print(
          '[RIDER_DEBUG] sendCounterOffer: Successfully sent. Offer status is now \'selected\'. Counter price: $counterPrice');

      return offer;
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de la contre-offre: $e');
    }
  }

  Future<TripOffer> acceptOffer(
    String offerId, {
    required int agreedPrice,
    required String tripId, // Le paramètre manquant est ajouté ici
  }) async {
    try {
      print(
          '[RIDER_DEBUG] acceptOffer: Calling RPC for offer $offerId with agreedPrice: $agreedPrice');

      // CORRECTION: On utilise la fonction RPC unifiée qui garantit une mise à jour atomique.
      await _supabase.rpc('accept_offer_and_update_trip', params: {
        'p_offer_id': offerId,
        'p_trip_id': tripId,
        'p_final_price': agreedPrice,
      });

      print('[RIDER_DEBUG] acceptOffer: RPC call successful.');
      // Après l'acceptation, on recharge les données complètes de l'offre pour avoir un état à jour.
      final updatedOffer = await getOfferById(offerId);
      if (updatedOffer == null) {
        throw Exception('Offre non trouvée après acceptation.');
      }
      print(
          '[RIDER_DEBUG] acceptOffer: Fetched updated offer with status: ${updatedOffer.status}');
      return updatedOffer;
    } catch (e, stackTrace) {
      print('[RIDER_DEBUG] acceptOffer: Error: $e\n$stackTrace');
      throw Exception('Erreur lors de l\'acceptation de l\'offre: $e');
    }
  }

  Future<TripOffer> rejectOffer(String offerId) async {
    try {
      final response = await _supabase
          .from('trip_offers')
          .update({'status': 'rejected'})
          .match({'id': offerId})
          .select()
          .single();

      final offer = await getOfferById(response['id'] as String);
      if (offer == null) {
        throw Exception('Offre non trouvée après rejet');
      }

      return offer;
    } catch (e) {
      throw Exception('Erreur lors du rejet de l\'offre: $e');
    }
  }

  Stream<List<TripOffer>> watchOffersForTrip(String tripId) {
    final controller = StreamController<List<TripOffer>>();
    List<TripOffer> currentOffers = [];

    // Fonction pour recharger et pousser les données dans le stream
    Future<void> fetchAndPushOffers() async {
      try {
        final offers = await getOffersForTrip(tripId);
        if (!controller.isClosed) {
          controller.add(offers);
          currentOffers = offers;
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Chargement initial des données
    fetchAndPushOffers();

    // 2. Écoute des changements en temps réel
    // On donne un nom unique au canal pour éviter les conflits
    final channel = _supabase.channel('trip-offers-for-trip-$tripId');
    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all, // Écoute tous les événements
      schema: 'public',
      table: 'trip_offers', // On écoute la table source, pas la vue
      // Le filtre realtime sur `trip_id` est appliqué pour les UPDATEs/DELETEs.
      // Pour les INSERTs, nous devons filtrer côté client.
      callback: (payload) {
        print('DEBUG Realtime: Received payload: ${payload.eventType}');

        final eventType = payload.eventType;
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        // Le payload ne contient pas les données jointes. Nous devons donc recharger.
        // C'est la méthode la plus simple et la plus fiable.
        if (eventType == PostgresChangeEvent.insert) {
          if (newRecord['trip_id'] == tripId) {
            print(
                'DEBUG Realtime: INSERT detected for our trip. Refetching all offers.');
            fetchAndPushOffers(); // Recharge la liste complète depuis la vue
          }
        } else if (eventType == PostgresChangeEvent.update) {
          // La manière la plus fiable de gérer une mise à jour est de tout recharger
          // pour s'assurer que l'état est parfaitement synchronisé avec la base de données.
          if (newRecord['trip_id'] == tripId) {
            print(
                'DEBUG Realtime: UPDATE detected for our trip. Refetching all offers.');
            fetchAndPushOffers();
          }
        } else if (eventType == PostgresChangeEvent.delete) {
          // Pour DELETE, le trip_id est dans oldRecord
          if (oldRecord['trip_id'] == tripId) {
            print(
                'DEBUG Realtime: DELETE detected for our trip. Removing offer.');
            fetchAndPushOffers();
          }
        }
      },
    )
        .subscribe((status, [error]) {
      print('DEBUG Realtime: Subscription status: $status');
    });

    // 3. Nettoyage lors de la fermeture du stream
    controller.onCancel = () {
      print('DEBUG Realtime: Stream cancelled. Unsubscribing.');
      channel.unsubscribe();
    };

    return controller.stream;
  }

  Future<int> getOfferCountForTrip(String tripId) async {
    try {
      // La syntaxe pour obtenir un comptage a changé.
      // Note: La RLS s'applique, donc le comptage est sécurisé.
      final response = await _supabase
          .from(_offersView)
          .select() // Il faut appeler select() avant d'appliquer un filtre
          .eq('trip_id', tripId) // Applique le filtre sur le trajet
          .count(CountOption.exact); // Compte les résultats
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Récupère les détails complets d'une offre avec toutes les données du driver
  Future<Map<String, dynamic>> getOfferDetails(String offerId) async {
    try {
      print('DEBUG getOfferDetails: Fetching offer $offerId');
      final data =
          await _supabase.from(_offersView).select().eq('id', offerId).single();

      // La vue contient déjà toutes les informations, il suffit de les retourner.
      // Le modèle TripOffer.fromJson s'occupe de la conversion.
      return data;
    } catch (e) {
      throw Exception(
          'Erreur lors de la récupération des détails de l\'offre: $e');
    }
  }

  /// Surveille les changements sur une seule offre en temps réel.
  /// Retourne un Map pour être compatible avec l'écran de négociation.
  Stream<Map<String, dynamic>?> watchOffer(String offerId) {
    // CORRECTION: L'utilisation de .stream() sur une vue ne notifie pas toujours
    // les mises à jour (UPDATE). On passe à une implémentation manuelle avec un
    // StreamController pour plus de fiabilité, comme côté chauffeur.
    final controller = StreamController<Map<String, dynamic>?>();

    // Fonction pour récupérer les données à jour depuis la vue.
    Future<void> fetcher() async {
      try {
        final response = await _supabase
            .from(_offersView) // La vue contient les données enrichies
            .select()
            .eq('id', offerId)
            .maybeSingle();

        print('[RIDER_OFFER_SERVICE] watchOffer fetched data for $offerId:');
        print('[RIDER_OFFER_SERVICE] - driver_id: ${response?['driver_id']}');
        print(
            '[RIDER_OFFER_SERVICE] - driver_name: ${response?['driver_name']}');
        print(
            '[RIDER_OFFER_SERVICE] - driver_rating: ${response?['driver_rating']}');
        print(
            '[RIDER_OFFER_SERVICE] - driver_total_trips: ${response?['driver_total_trips']}');
        print(
            '[RIDER_OFFER_SERVICE] - driver_vehicle_plate: ${response?['driver_vehicle_plate']}');
        print('[RIDER_OFFER_SERVICE] - All keys: ${response?.keys.toList()}');

        if (!controller.isClosed) {
          controller.add(response);
        }
      } catch (e) {
        print('[RIDER_OFFER_SERVICE] Error in watchOffer: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Chargement initial
    fetcher();

    // 2. Écoute des changements sur la table 'trip_offers'
    final channel = _supabase.channel('public:trip_offers:id=eq.$offerId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Écoute INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: offerId),
          callback: (payload) {
            print(
                '[RIDER_DEBUG] watchOffer: Realtime update received for offer $offerId. Payload: ${payload.newRecord}');
            fetcher(); // Recharge les données à chaque changement
          },
        )
        .subscribe();

    // 3. Nettoyage à la fermeture du stream
    controller.onCancel = () => _supabase.removeChannel(channel);

    return controller.stream;
  }
}
