import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/trip_offer.dart';
import '../../../../services/rider_offer_service.dart';
import 'negotiation_status_banner.dart';

// --- Providers ---
// On déclare les providers en dehors de la classe pour qu'ils soient accessibles globalement
// et pour éviter les erreurs d'initialisation.
final riderOfferServiceProvider = Provider((ref) => RiderOfferService());

final offerStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, offerId) {
  return ref.watch(riderOfferServiceProvider).watchOffer(offerId);
});

class NegotiationDetailScreen extends ConsumerStatefulWidget {
  final String offerId;
  final String tripId;
  final Map<String, dynamic> offer;

  const NegotiationDetailScreen({
    super.key,
    required this.offerId,
    required this.tripId,
    required this.offer,
  });

  @override
  ConsumerState<NegotiationDetailScreen> createState() =>
      _NegotiationDetailScreenState();
}

class _NegotiationDetailScreenState
    extends ConsumerState<NegotiationDetailScreen> {
  final _counterPriceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  // CORRECTION: On stocke la dernière offre connue du passager pour l'affichage.
  // Cela résout le problème où `counter_price` devient null après la contre-offre du chauffeur.
  num? _lastKnownRiderPrice;

  @override
  void initState() {
    super.initState();
    // On initialise avec l'offre du driver pour afficher le prix barré
    _lastKnownRiderPrice = widget.offer['offered_price'] as num?;
  }

  Future<void> _acceptOffer(Map<String, dynamic> currentOffer) async {
    setState(() => _isLoading = true);
    try {
      // Le prix que le client accepte est l'offre actuelle du driver (offered_price)
      final int? finalPrice = currentOffer['offered_price'] as int?;

      if (finalPrice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur: Le prix final est invalide.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      print('[RIDER_DEBUG] _acceptOffer: Final price to be sent: $finalPrice');

      await ref.read(riderOfferServiceProvider).acceptOffer(
            widget.offerId,
            tripId: widget.tripId, // CORRECTION: Ajout du tripId manquant
            agreedPrice: finalPrice,
          );

      // La redirection est maintenant gérée par ref.listen pour plus de robustesse.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offre acceptée ! Le chauffeur a été notifié.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'acceptation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCounterOffer(Map<String, dynamic> currentOffer) async {
    final priceText = _counterPriceController.text.trim();
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Veuillez entrer un prix pour la contre-offre.')),
      );
      return;
    }
    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer un prix valide.')),
      );
      return;
    }

    // On vérifie que le statut de l'offre permet une contre-proposition
    final status = currentOffer['status'] as String?;
    final canSendCounterOffer = status == 'pending' || status == 'selected';
    if (!canSendCounterOffer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Vous ne pouvez pas envoyer de contre-offre pour cette offre.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(riderOfferServiceProvider).sendCounterOffer(
            widget.offerId,
            price,
            message: _messageController.text.trim(),
          );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contre-offre envoyée avec succès.')),
        );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'envoi de la contre-offre: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Écoute les changements sur l'offre
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
        offerStreamProvider(widget.offerId), (previous, next) {
      final offerData = next.value;
      if (offerData == null) return;

      final status = offerData['status'] as String?;

      // Si le driver a refusé la négociation
      if (status == 'rejected' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '❌ Le chauffeur a refusé la négociation. Recherche d\'autres chauffeurs...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        // Redirection vers l'écran d'attente des offres
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/waiting-offers/${widget.tripId}');
          }
        });
        return;
      }

      // Si l'offre passe au statut "accepted", on redirige vers l'écran de suivi
      if (status == 'accepted' && mounted) {
        // CORRECTION: On utilise le prix final définitif stocké dans la base de données.
        final int? finalPrice = offerData['final_price'] as int?;

        print('[RIDER_DEBUG] Navigation Listener: offerData received:');
        print('[RIDER_DEBUG] - driver_id: ${offerData['driver_id']}');
        print('[RIDER_DEBUG] - driver_name: ${offerData['driver_name']}');
        print('[RIDER_DEBUG] - driver_rating: ${offerData['driver_rating']}');
        print(
            '[RIDER_DEBUG] - driver_total_trips: ${offerData['driver_total_trips']}');
        print(
            '[RIDER_DEBUG] - driver_vehicle_plate: ${offerData['driver_vehicle_plate']}');
        print('[RIDER_DEBUG] - All offerData keys: ${offerData.keys.toList()}');
        print(
            '[RIDER_DEBUG] Final price from DB: $finalPrice. Redirecting to /tracking.');

        // Redirection vers l'écran de tracking avec les données complètes.
        context.go('/tracking', extra: {
          'driver': {
            'id': offerData['driver_id'] as String?,
            'full_name': offerData['driver_name'] as String? ??
                (offerData['driver'] as Map?)?['full_name'] as String? ??
                'Chauffeur',
            'rating': (offerData['driver_rating'] as num?)?.toDouble() ??
                (offerData['driver'] as Map?)?['rating'] as num? ??
                5.0,
            'total_trips': offerData['driver_total_trips'] as int? ??
                (offerData['driver'] as Map?)?['total_trips'] as int? ??
                0,
            'vehicle_plate':
                offerData['driver_vehicle_plate'] as String? ?? '-',
          },
          // Les données du trajet sont récupérées depuis l'offre enrichie.
          'departure': offerData['departure_address'] ?? '',
          'destination': offerData['destination_address'] ?? '',
          'price': finalPrice, // CORRECTION: Assurer que la clé est 'price'
          'tripId': offerData['trip_id'], // Ajout de l'ID du trajet
          'departure_lat':
              (offerData['departure_lat'] as num?)?.toDouble() ?? 0.0,
          'departure_lng':
              (offerData['departure_lng'] as num?)?.toDouble() ?? 0.0,
          'driverLatAtOffer':
              (offerData['driver_lat_at_offer'] as num?)?.toDouble() ?? 0.0,
          'driverLngAtOffer':
              (offerData['driver_lng_at_offer'] as num?)?.toDouble() ?? 0.0,
          'destination_lat':
              (offerData['destination_lat'] as num?)?.toDouble() ?? 0.0,
          'destination_lng':
              (offerData['destination_lng'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });

    // On écoute les changements pour mémoriser le prix AVANT changement (pour le barrer)
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
        offerStreamProvider(widget.offerId), (previous, next) {
      final previousData = previous?.value;
      final nextData = next.value;

      if (previousData != null && nextData != null) {
        setState(() {
          // Récupérer le prix qui ÉTAIT affiché avant ce changement
          final num? prevDriverPrice = previousData['offered_price'] as num?;
          final num? prevRiderCounter = previousData['counter_price'] as num?;
          final num? previousPrice = prevRiderCounter ?? prevDriverPrice;

          // Récupérer le nouveau prix affiché maintenant
          final num? newDriverPrice = nextData['offered_price'] as num?;
          final num? newRiderCounter = nextData['counter_price'] as num?;
          final num? newPrice = newRiderCounter ?? newDriverPrice;

          // Si le prix a changé, mémoriser l'ANCIEN prix pour le barrer
          if (previousPrice != null &&
              newPrice != null &&
              previousPrice != newPrice) {
            _lastKnownRiderPrice = previousPrice;
            print(
                '[RIDER_LISTENER] Prix changé: $previousPrice → $newPrice, mémorisé: $previousPrice');
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // L'AppBar est maintenant plus simple
      appBar: AppBar(
        title: const Text('Négociation'),
        centerTitle: true,
      ),
      body: Consumer(builder: (context, ref, _) {
        final offerAsync = ref.watch(offerStreamProvider(widget.offerId));
        return offerAsync.when(
          data: (snapshotData) {
            // Le StreamBuilder est remplacé par le Consumer et le when().
            // Le reste du code de la méthode build reste identique.
            // On crée un AsyncSnapshot pour la compatibilité avec le code existant.
            final snapshot =
                AsyncSnapshot.withData(ConnectionState.active, snapshotData);

            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(
                  child: Text('Cette offre n\'est plus disponible.'));
            }

            final currentOffer = snapshot.data!;
            final isDark = theme.brightness == Brightness.dark;

            // --- Getters pour un accès aux données plus sûr ---
            // CORRECTION: Les données peuvent venir soit du stream Supabase (clés snake_case)
            // soit des données passées en paramètre (objet driver). On vérifie les deux.
            String _driverName() =>
                currentOffer['driver_name'] as String? ??
                (currentOffer['driver'] as Map?)?['full_name'] as String? ??
                widget.offer['driver']?['full_name'] as String? ??
                'Chauffeur';
            String _driverRating() =>
                (currentOffer['driver_rating'] as num?)?.toStringAsFixed(1) ??
                (widget.offer['driver']?['rating'] as num?)
                    ?.toStringAsFixed(1) ??
                'N/A';
            String _driverTotalTrips() =>
                (currentOffer['driver_total_trips'] as int?)?.toString() ??
                (widget.offer['driver']?['total_trips'] as int?)?.toString() ??
                '0';
            String _etaMinutes() =>
                (currentOffer['eta_minutes'] as int?)?.toString() ?? 'N/A';
            int? driverPrice = currentOffer['offered_price'] as int?;
            int? riderCounterPrice = currentOffer['counter_price'] as int?;

            // --- Logique de prix et d'état (APPZEDGO style) ---
            // Le prix à afficher:
            // - Si rider a contré: afficher sa contre-offre
            // - Sinon: afficher l'offre du driver
            final currentPriceToShow = riderCounterPrice ?? driverPrice;

            final status = currentOffer['status'] as String?;

            // --- Logique d'activation des boutons ---
            // Le rider attend si il a fait une contre-offre (status = selected)
            // et que le driver n'a pas encore répondu (offered_price n'a pas changé)
            final bool isRiderWaitingForDriverResponse = status == 'selected';

            // Tous les boutons d'action sont désactivés si on attend une réponse OU si une opération est en cours.
            final bool actionButtonsEnabled =
                !isRiderWaitingForDriverResponse && !_isLoading;

            // Le bouton "Envoyer" a une condition supplémentaire : le champ de texte doit être valide.
            final counterOfferInputIsValid =
                (_counterPriceController.text.trim().isNotEmpty &&
                    int.tryParse(_counterPriceController.text.trim()) != null &&
                    int.tryParse(_counterPriceController.text.trim())! > 0);
            final sendButtonEnabled =
                actionButtonsEnabled && counterOfferInputIsValid;

            // Le bouton "Accepter" a une condition supplémentaire : on ne peut accepter
            // que l'offre du chauffeur, pas notre propre contre-offre.
            // C'est le cas si le chauffeur a fait une contre-offre OU si c'est l'offre initiale.
            // CORRECTION: On peut accepter tant que ce n'est pas notre tour d'attendre.
            final bool canAcceptOffer = actionButtonsEnabled;

            // Logique pour l'affichage de la séquence de négociation (APPZEDGO style)
            final bool hasRiderCountered = riderCounterPrice != null;

            // Prix à barrer:
            // On barre le prix mémorisé SI le prix actuel est différent
            // Cela fonctionne dans les deux directions:
            // - Rider contre 23F après driver 25F : barre 25F → affiche 23F
            // - Driver contre 24F après rider 23F : barre 23F → affiche 24F
            final num? priceToStrike = (currentPriceToShow != null &&
                    _lastKnownRiderPrice != null &&
                    currentPriceToShow != _lastKnownRiderPrice)
                ? _lastKnownRiderPrice
                : null;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark
                            ? Border.all(color: Colors.grey[800]!)
                            : null,
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor:
                                    AppTheme.primaryOrange.withOpacity(0.1),
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
                                      _driverName(),
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          _driverRating(),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_driverTotalTrips()} courses',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Prix proposé',
                                      style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                  // Affichage avec prix barré si négociation en cours
                                  if (priceToStrike != null)
                                    Row(
                                      children: [
                                        Text(
                                          '${priceToStrike}F',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward,
                                            color: AppTheme.primaryOrange,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Animate(
                                          key: ValueKey(currentPriceToShow),
                                          effects: [
                                            FadeEffect(duration: 300.ms),
                                            ScaleEffect(
                                                begin: const Offset(0.9, 0.9),
                                                curve: Curves.easeOutBack),
                                            TintEffect(
                                                color: AppTheme.primaryGreen,
                                                end: 0.0,
                                                duration: 700.ms),
                                          ],
                                          child: Text(
                                            '${currentPriceToShow ?? '...'}F',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryOrange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    // Offre initiale sans négociation
                                    Animate(
                                      key: ValueKey(currentPriceToShow),
                                      effects: [
                                        FadeEffect(duration: 300.ms),
                                        ScaleEffect(
                                            begin: const Offset(0.9, 0.9),
                                            curve: Curves.easeOutBack),
                                        TintEffect(
                                            color: AppTheme.primaryGreen,
                                            end: 0.0,
                                            duration: 700.ms),
                                      ],
                                      child: Text(
                                        '${currentPriceToShow ?? '...'}F',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Arrivée',
                                      style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_etaMinutes()} min',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(),
                    const SizedBox(height: 24),

                    // Bannière de statut
                    NegotiationStatusBanner(
                      isRiderWaiting: isRiderWaitingForDriverResponse,
                      hasDriverResponded:
                          false, // APPZEDGO: plus de driver_counter_price
                    ),

                    Animate(
                      effects: [FadeEffect(delay: 200.ms)],
                      child: Text('Faire une contre-offre',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Animate(
                      effects: [
                        FadeEffect(delay: 500.ms),
                        SlideEffect(begin: Offset(0.2, 0), end: Offset(0, 0))
                      ],
                      child: TextField(
                        // Le champ est désactivé si les actions ne sont pas permises
                        enabled: actionButtonsEnabled,
                        controller: _counterPriceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        // CORRECTION: La suggestion de prix doit gérer le cas où le prix est null.
                        decoration: InputDecoration(
                          hintText: currentPriceToShow != null
                              ? 'Ex: ${(currentPriceToShow * 0.9).round()}' // Opération sûre
                              : 'Ex: ',
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText: 'F',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryOrange,
                              width: 2,
                            ),
                          ),
                        ),
                        // Reconstruit le widget pour mettre à jour l'état du bouton "Envoyer"
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            priceToStrike != null
                                                ? 'Prix précédent'
                                                : 'Offre initiale',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                    fontSize: 13,
                                                    color: theme.textTheme
                                                        .bodySmall?.color)),
                                        // CORRECTION: Le prix barré peut être null au tout début.
                                        // On affiche le prix initial s'il n'y a rien à barrer.
                                        Text(
                                          '${priceToStrike ?? '...'}F',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .textTheme.bodySmall?.color,
                                            decoration: priceToStrike != null
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (priceToStrike !=
                                      null) // CORRECTION: Afficher si une négociation est en cours
                                    const Icon(Icons.arrow_forward,
                                        color: AppTheme.primaryOrange,
                                        size: 20),
                                  if (priceToStrike !=
                                      null) // CORRECTION: Afficher si une négociation est en cours
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('Nouvelle offre',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                      fontSize: 13,
                                                      color: AppTheme
                                                          .primaryOrange)),
                                          // APPZEDGO: afficher le prix actuel (la dernière offre active)
                                          Text(
                                            '${currentPriceToShow ?? '...'}F',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryOrange,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (actionButtonsEnabled) ...[
                      Animate(
                        effects: [FadeEffect(delay: 800.ms), ScaleEffect()],
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: actionButtonsEnabled
                                    ? () => context.pop()
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      theme.textTheme.bodyLarge?.color,
                                  side: BorderSide(
                                    color: theme.dividerColor,
                                    width: 2,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Annuler'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: sendButtonEnabled
                                    ? () => _sendCounterOffer(currentOffer)
                                    : null,
                                icon: const Icon(Icons.send),
                                label: const Text('Envoyer contre-offre'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryOrange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Animate(
                        effects: [FadeEffect(delay: 900.ms), ScaleEffect()],
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canAcceptOffer
                                ? () => _acceptOffer(
                                    currentOffer) // Le prix est recalculé dans la fonction
                                : null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                              'Accepter l\'offre de ${currentPriceToShow ?? '...'}F',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Erreur: $error')),
        );
      }),
    );
  }
}
