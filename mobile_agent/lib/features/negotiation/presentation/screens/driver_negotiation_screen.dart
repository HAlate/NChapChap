import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_driver/core/theme/app_theme.dart';
import 'package:mobile_driver/services/driver_offer_service.dart';

// Provider singleton pour le service (évite de créer plusieurs instances)
final driverOfferServiceProvider = Provider<DriverOfferService>((ref) {
  return DriverOfferService();
});

final offerStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, offerId) {
  // Utiliser le provider singleton au lieu de créer une nouvelle instance
  return ref.watch(driverOfferServiceProvider).watchOffer(offerId);
});

class DriverNegotiationScreen extends ConsumerStatefulWidget {
  final String offerId;
  final Map<String, dynamic> offer;

  const DriverNegotiationScreen({
    super.key,
    required this.offerId,
    required this.offer,
  });

  @override
  ConsumerState<DriverNegotiationScreen> createState() =>
      _DriverNegotiationScreenState();
}

class _DriverNegotiationScreenState
    extends ConsumerState<DriverNegotiationScreen> {
  final _counterPriceController = TextEditingController();
  // Mémorisation du prix précédent pour affichage du prix barré
  num? _lastKnownPrice;

  @override
  void initState() {
    super.initState();
    // Initialiser avec l'offre du driver
    _lastKnownPrice = widget.offer['offered_price'] as num?;
  }

  @override
  void dispose() {
    _counterPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listener pour mémoriser le prix AVANT changement (pour le barrer)
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
            _lastKnownPrice = previousPrice;
            print(
                '[DRIVER_LISTENER] Prix changé: $previousPrice → $newPrice, mémorisé: $previousPrice');
          }
        });
      }
    });

    // Listener pour la navigation automatique quand l'offre est acceptée
    // Si le statut de l'offre passe à "accepted", on redirige le chauffeur.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
        offerStreamProvider(widget.offerId), (previous, next) async {
      final offerData = next.value;
      if (offerData == null) return;

      if (offerData['status'] == 'accepted' && mounted) {
        // Le prix final est celui qui a été convenu.
        final finalPrice = offerData['final_price'] as int?;
        print(
            '[DRIVER_DEBUG] Navigation Listener: Final price from DB: $finalPrice. Redirecting to /tracking.');

        if (finalPrice == null) {
          print("Erreur: Le prix final est manquant pour la redirection.");
          return;
        }

        // Pour plus de robustesse, on recharge les données complètes du trajet
        // car le stream de l'offre ne les contient pas toujours.
        final tripData = await DriverOfferService()
            .getTripDetails(offerData['trip_id'] as String);

        final riderData = tripData['rider'] as Map? ?? {};
        final rider = Map<String, dynamic>.from(riderData);

        context.go('/driver-navigation', extra: {
          'rider': rider,
          'departure': tripData['departure'] ?? '',
          'destination': tripData['destination'] ?? '',
          'price': finalPrice, // Le nom du paramètre doit être cohérent
          'tripId': offerData['trip_id'], // Ajout de l'ID du trajet
          'departure_lat':
              (tripData['departure_lat'] as num?)?.toDouble() ?? 0.0,
          'departure_lng':
              (tripData['departure_lng'] as num?)?.toDouble() ?? 0.0,
          'destination_lat':
              (tripData['destination_lat'] as num?)?.toDouble() ?? 0.0,
          'destination_lng':
              (tripData['destination_lng'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });

    final offerAsyncValue = ref.watch(offerStreamProvider(widget.offerId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: offerAsyncValue.when(
        // CORRECTION: On utilise les données initiales de `widget.offer` pendant le chargement
        // ou si le stream ne renvoie rien au début. `streamData` peut être null au premier frame.
        data: (streamData) {
          final currentOffer = streamData ?? widget.offer;

          if (currentOffer.isEmpty) {
            return const Center(
                child: Text('Données de l\'offre non disponibles.'));
          }

          final trip = currentOffer['trip'] as Map<String, dynamic>?;
          final rider = trip?['rider'] as Map<String, dynamic>?;
          // final num offeredPrice = currentOffer['offered_price'] ?? 0; // Déjà dans _NegotiationState
          final num? counterPrice = currentOffer['counter_price'];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTripInfoCard(context, currentOffer),
                  const SizedBox(height: 16),
                  _NegotiationState(
                    currentOffer: currentOffer,
                    lastKnownPrice: _lastKnownPrice,
                  ),
                  _ActionButtons(
                    offerId: widget.offerId,
                    currentOffer: currentOffer,
                    // isDriverWaiting: isDriverWaiting, // Ce paramètre est maintenant géré dans _ActionButtons
                    counterPriceController: _counterPriceController,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur de chargement de l\'offre: $error'),
        ),
      ),
    );
  }

  // Les widgets ci-dessous sont déplacés en dehors de la classe State pour une meilleure organisation.
}

/// Un widget dédié pour encapsuler la logique d'état de la négociation.
class _NegotiationState extends StatelessWidget {
  final Map<String, dynamic> currentOffer;
  final num? lastKnownPrice;

  const _NegotiationState({
    required this.currentOffer,
    required this.lastKnownPrice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- Logique d'état et de prix (APPZEDGO style) ---
    final num driverPrice = currentOffer['offered_price'] as num? ?? 0;
    final num? riderCounterPrice = currentOffer['counter_price'];

    // Le chauffeur attend si le passager n'a pas (encore) fait d'offre.
    final bool isDriverWaiting = riderCounterPrice == null;

    // Le prix à afficher:
    // - Si rider a contré: afficher sa contre-offre
    // - Sinon: afficher l'offre du driver
    final num priceToShow = riderCounterPrice ?? driverPrice;

    // Le prix à barrer: utiliser lastKnownPrice SI différent du prix actuel
    final num? priceToStrike =
        (lastKnownPrice != null && priceToShow != lastKnownPrice)
            ? lastKnownPrice
            : null;

    final num leftPrice = priceToStrike ?? driverPrice;
    final bool isInitialOffer = priceToStrike == null;

    return Column(
      children: [
        // --- Carte de comparaison des prix ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isInitialOffer) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prix précédent', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '$leftPrice F CFA',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.green),
              ],
              Column(
                crossAxisAlignment: isInitialOffer
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    priceToStrike != null ? 'Offre du client' : 'Votre offre',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Animate(
                    key: ValueKey(priceToShow),
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
                      '$priceToShow F CFA',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2, end: 0),
        const SizedBox(height: 32),

        // --- Bannière d'attente ---
        if (isDriverWaiting)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En attente de la réponse du client...',
                    style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),
      ],
    );
  }
}

Widget _buildTripInfoCard(
    BuildContext context, Map<String, dynamic> currentOffer) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // Extraction des données depuis la vue trip_offers_with_driver
  // Les champs sont maintenant au premier niveau au lieu d'être imbriqués
  final riderName = currentOffer['rider_name'] as String?;
  final riderPhone = currentOffer['rider_phone'] as String?;

  final departureAddress = currentOffer['departure_address'] as String?;
  final destinationAddress = currentOffer['destination_address'] as String?;
  final distanceKm = currentOffer['distance_km'] as double?;

  print('[DEBUG NEGO] riderName: $riderName');
  print('[DEBUG NEGO] departureAddress: $departureAddress');
  print('[DEBUG NEGO] destinationAddress: $destinationAddress');

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: isDark ? Border.all(color: Colors.grey[800]!) : null,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    riderName ?? 'Client',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Trajet',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on,
                color: AppTheme.primaryGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                departureAddress ?? 'Départ',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destinationAddress ?? 'Destination',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (distanceKm != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.straighten, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(
                '$distanceKm km',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    ),
  ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
}

class _ActionButtons extends StatefulWidget {
  final String offerId;
  final Map<String, dynamic> currentOffer;
  final TextEditingController counterPriceController;

  const _ActionButtons({
    required this.offerId,
    required this.currentOffer,
    required this.counterPriceController,
  });

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _isLoading = false;
  final DriverOfferService _tripOfferService = DriverOfferService();

  @override
  Future<void> _acceptCounterOffer() async {
    setState(() => _isLoading = true);

    // Le prix que le chauffeur accepte est la contre-offre du client.
    final int? finalPrice = widget.currentOffer['counter_price'] as int?;

    if (finalPrice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur: Le prix de la contre-offre est invalide.')));
      }
      setState(() => _isLoading = false);
      return;
    }

    print(
        '[DRIVER_DEBUG] _acceptCounterOffer: Final price to be sent: $finalPrice');

    try {
      // FIX: Use the tripId from the widget's currentOffer
      final String? tripId = widget.currentOffer['trip_id'] as String?;
      if (tripId == null) throw Exception('Trip ID is missing from the offer.');

      await _tripOfferService.acceptCounterOffer(
        offerId: widget.offerId,
        tripId: tripId,
        finalPrice: finalPrice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Course confirmée!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                          '${widget.currentOffer['counter_price']}F CFA accepté'),
                      const SizedBox(height: 2),
                      const Text(
                        'Votre jeton a été dépensé',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        // Note: Ne pas rediriger manuellement ici.
        // Le listener automatique (lignes ~90-130) détecte le changement de status à 'accepted'
        // et redirige avec les données complètes du trip rechargées via getTripDetails().
        // Cela garantit que toutes les infos rider/trip sont présentes.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectCounterOffer() async {
    setState(() => _isLoading = true);

    try {
      await _tripOfferService.rejectCounterOffer(widget.offerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Négociation abandonnée',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Le passager a été notifié. Votre jeton n\'a pas été dépensé.',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // Redirection vers l'écran des demandes (la demande refusée sera masquée)
        // Attendre un peu pour que le stream Realtime se mette à jour
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/requests');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makeCounterCounterOffer() async {
    final driverCounterPrice = int.tryParse(widget.counterPriceController.text);

    if (driverCounterPrice == null || driverCounterPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Veuillez entrer un prix valide'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _tripOfferService.makeCounterOffer(
        offerId: widget.offerId,
        counterPrice: driverCounterPrice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Contre-proposition envoyée!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('$driverCounterPrice F CFA proposé au client'),
                      const SizedBox(height: 2),
                      const Text(
                        'En attente de sa réponse...',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        // L'écran se mettra à jour via le StreamBuilder pour montrer l'état d'attente
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final num? counterPrice = widget.currentOffer['counter_price'];

    // La logique d'attente est maintenant locale à ce widget.
    final bool isDriverWaiting = counterPrice == null;

    // Le chauffeur peut toujours refuser, même en attente.
    final bool canReject = !_isLoading;
    // Les autres actions (accepter, contre-proposer) ne sont possibles que si le chauffeur n'est pas en attente.
    final bool canPerformMainActions = !isDriverWaiting && !_isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action requise',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canReject ? _rejectCounterOffer : null,
                label: const Text(
                  'Refuser',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.close),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: canPerformMainActions
                    ? _acceptCounterOffer // Appel direct sans popup de confirmation
                    : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isLoading ? 'Acceptation...' : 'Accepter',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          ],
        ).animate().fadeIn(delay: 500.ms).scale(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Text(
          'Ou faire une contre-contre-offre',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(delay: 700.ms),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                // CORRECTION: Le champ de texte doit être explicitement désactivé
                // si les actions principales ne sont pas permises.
                enabled: canPerformMainActions,
                controller: widget.counterPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Votre prix',
                  suffixText: 'F CFA',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed:
                  canPerformMainActions ? _makeCounterCounterOffer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 56), // Match height
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2, end: 0),
      ],
    );
  }
}
