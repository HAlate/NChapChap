import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider qui expose l'état de disponibilité (online/offline), géré localement.
final isDriverOnlineProvider = StateProvider<bool>((ref) => false);

/// Provider pour stocker la souscription au stream de position, afin de pouvoir l'annuler.
final _positionStreamSubscriptionProvider =
    StateProvider<StreamSubscription?>((ref) => null);

/// Provider pour marquer si la vérification des courses actives a déjà été faite
final _hasCheckedActiveTripProvider = StateProvider<bool>((ref) => false);

/// Provider pour récupérer le nom complet du chauffeur connecté
final driverNameProvider = FutureProvider<String>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 'Chauffeur';

  try {
    final response = await Supabase.instance.client
        .from('users')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();

    return response?['full_name'] as String? ?? 'Chauffeur';
  } catch (e) {
    return 'Chauffeur';
  }
});

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  Future<void> _checkActiveTrip(BuildContext context, WidgetRef ref) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Vérifier s'il y a une course active
      final response = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('driver_id', userId)
          .inFilter('status', ['accepted', 'started', 'completed'])
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final trip = response.first;
        final status = trip['status'];

        // Récupérer les données complètes du trajet avec les bonnes clés
        // La table trips utilise 'origin' et 'destination', mais la vue/fonction peut retourner d'autres noms
        // Nous devons nous assurer que les noms de champs correspondent à ce que attend driver_navigation_screen

        // Si la course est complétée mais pas évaluée, rediriger
        if (status == 'completed' && trip['rider_rating'] == null) {
          if (context.mounted) {
            // Rediriger vers l'écran de navigation avec la course
            context.push('/driver-navigation', extra: {
              'tripId': trip['id'],
              'rider': trip['rider'],
              'departure': trip['origin'] ?? trip['departure'] ?? '',
              'destination': trip['destination'] ?? '',
              'departure_lat':
                  (trip['origin_lat'] ?? trip['departure_lat'] ?? 0.0) as num,
              'departure_lng':
                  (trip['origin_lng'] ?? trip['departure_lng'] ?? 0.0) as num,
              'destination_lat':
                  (trip['dest_lat'] ?? trip['destination_lat'] ?? 0.0) as num,
              'destination_lng':
                  (trip['dest_lng'] ?? trip['destination_lng'] ?? 0.0) as num,
              'price': trip['price'] ?? 0,
            });
          }
        }
        // Si la course est acceptée ou démarrée, rediriger aussi
        else if (status == 'accepted' || status == 'started') {
          if (context.mounted) {
            context.push('/driver-navigation', extra: {
              'tripId': trip['id'],
              'rider': trip['rider'],
              'departure': trip['origin'] ?? trip['departure'] ?? '',
              'destination': trip['destination'] ?? '',
              'departure_lat':
                  (trip['origin_lat'] ?? trip['departure_lat'] ?? 0.0) as num,
              'departure_lng':
                  (trip['origin_lng'] ?? trip['departure_lng'] ?? 0.0) as num,
              'destination_lat':
                  (trip['dest_lat'] ?? trip['destination_lat'] ?? 0.0) as num,
              'destination_lng':
                  (trip['dest_lng'] ?? trip['destination_lng'] ?? 0.0) as num,
              'price': trip['price'] ?? 0,
            });
          }
        }
      }
    } catch (e) {
      print('[DRIVER_HOME] Error checking active trip: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TEMPORAIREMENT DÉSACTIVÉ : Vérification des courses actives
    // Cette fonctionnalité sera réactivée après clarification du workflow
    // final hasChecked = ref.watch(_hasCheckedActiveTripProvider);

    // if (!hasChecked) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     ref.read(_hasCheckedActiveTripProvider.notifier).state = true;
    //     _checkActiveTrip(context, ref);
    //   });
    // }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // On écoute l'état local de l'interrupteur
    final isOnline = ref.watch(isDriverOnlineProvider);
    final driverNameAsync = ref.watch(driverNameProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour,',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          driverNameAsync.when(
                            data: (name) => Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            loading: () => Text(
                              'Chauffeur',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            error: (_, __) => Text(
                              'Chauffeur',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Semantics(
                        label: 'Menu',
                        button: true,
                        child: Material(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          elevation: isDark ? 0 : 2,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: const Icon(Icons.menu, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 24),
                  Material(
                    elevation: isDark ? 0 : 4,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOnline
                              ? [AppTheme.statusOnline, AppTheme.lightGreen]
                              : [AppTheme.statusOffline, Colors.grey[600]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Statut',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOnline ? 'En ligne' : 'Hors ligne',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Semantics(
                                label: isOnline
                                    ? 'Passer hors ligne'
                                    : 'Passer en ligne',
                                toggled: isOnline,
                                child: Switch(
                                  value: isOnline,
                                  onChanged: (newValue) async {
                                    // Met à jour l'état de l'interrupteur
                                    ref
                                        .read(isDriverOnlineProvider.notifier)
                                        .state = newValue;

                                    final supabase = Supabase.instance.client;
                                    final driverId =
                                        supabase.auth.currentUser?.id;
                                    if (driverId == null) return;

                                    // Met à jour le statut dans la base de données
                                    await supabase
                                        .from('driver_profiles')
                                        .update({'is_online': newValue}).eq(
                                            'id', driverId);

                                    // Démarre ou arrête le suivi de la position proprement
                                    if (newValue) {
                                      try {
                                        // On démarre le suivi en arrière-plan (sans attendre)
                                        final subscription =
                                            Geolocator.getPositionStream(
                                                locationSettings:
                                                    const LocationSettings(
                                          accuracy: LocationAccuracy.high,
                                          distanceFilter: 50,
                                        )).listen((position) {
                                          // Vérifier que le provider est toujours disponible
                                          try {
                                            // Met à jour la position dans la DB
                                            if (ref
                                                .read(isDriverOnlineProvider)) {
                                              // Double-check
                                              supabase
                                                  .from('driver_profiles')
                                                  .update({
                                                'current_lat':
                                                    position.latitude,
                                                'current_lng':
                                                    position.longitude,
                                                'location_updated_at':
                                                    DateTime.now()
                                                        .toIso8601String(),
                                              }).eq('id', driverId);
                                            }
                                          } catch (e) {
                                            // Ignorer les erreurs si le widget est disposé
                                            print(
                                                '[GPS] Widget disposed, stopping updates: $e');
                                          }
                                        });
                                        // On stocke la souscription pour pouvoir l'annuler plus tard
                                        ref
                                            .read(
                                                _positionStreamSubscriptionProvider
                                                    .notifier)
                                            .state = subscription;
                                      } catch (e) {
                                        print(
                                            "Erreur de démarrage du suivi: $e");
                                      }
                                    } else {
                                      // On arrête le stream de position
                                      await ref
                                          .read(
                                              _positionStreamSubscriptionProvider
                                                  .notifier)
                                          .state
                                          ?.cancel();
                                      ref
                                          .read(
                                              _positionStreamSubscriptionProvider
                                                  .notifier)
                                          .state = null;
                                      print(
                                          "Geolocator position updates stopped.");
                                    }
                                  },
                                  activeColor: Colors.white,
                                  activeTrackColor:
                                      Colors.white.withOpacity(0.5),
                                  inactiveThumbColor: Colors.white70,
                                  inactiveTrackColor: Colors.white30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms).scale(),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.backgroundDark : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistiques du jour',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.account_balance_wallet,
                              label: 'Gains',
                              value: '15 000 F',
                              color: AppTheme.earningsGold,
                            ).animate().fadeIn(delay: 300.ms).scale(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_taxi,
                              label: 'Courses',
                              value: '8',
                              color: AppTheme.primaryGreen,
                            ).animate().fadeIn(delay: 400.ms).scale(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Actions rapides',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 700.ms)
                          .slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 20),
                      // --- CARTE D'ACTION POUR LES DEMANDES ---
                      // Cette carte est toujours visible, mais son état change
                      // en fonction du statut en ligne du chauffeur.
                      _QuickActionCard(
                        icon: Icons.list_alt_rounded,
                        title: 'Voir les demandes',
                        subtitle: isOnline
                            ? 'En attente de nouvelles courses...'
                            : 'Passez en ligne pour commencer',
                        onTap: isOnline
                            ? () => context.go('/requests')
                            : null, // Le onTap est null si hors ligne, ce qui désactive la carte.
                      )
                          .animate()
                          .fadeIn(delay: 800.ms)
                          .slideX(begin: -0.2, end: 0),
                      _QuickActionCard(
                        icon: Icons.map_outlined,
                        title: 'Voir la carte',
                        subtitle: 'Zones de forte demande',
                        onTap: () {},
                      )
                          .animate()
                          .fadeIn(delay: 900.ms)
                          .slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 12),
                      _QuickActionCard(
                        icon: Icons.history,
                        title: 'Historique',
                        subtitle: 'Vos courses récentes',
                        onTap: () {},
                      )
                          .animate()
                          .fadeIn(delay: 1000.ms)
                          .slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 12),
                      _QuickActionCard(
                        icon: Icons.support_agent,
                        title: 'Support',
                        subtitle: 'Besoin d\'aide ?',
                        onTap: () {},
                      )
                          .animate()
                          .fadeIn(delay: 1100.ms)
                          .slideX(begin: -0.2, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: isDark ? 0 : 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isEnabled = onTap != null;

    return Semantics(
      label: title,
      button: true,
      enabled: isEnabled,
      child: Material(
        elevation: isDark ? 0 : 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isDark ? AppTheme.surfaceDark : Colors.white)
                  : (isDark ? Colors.grey[900] : Colors.grey[200]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? AppTheme.primaryGreen : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isEnabled
                                ? null
                                : theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: isEnabled
                                ? theme.textTheme.bodySmall?.color
                                : theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: isEnabled ? null : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
