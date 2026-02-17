import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/home/presentation/screens/home_screen_new.dart';
import '../../features/trip/presentation/screens/trip_screen.dart';
import '../../features/trip/presentation/screens/waiting_offers_screen.dart';
import '../../features/trip/presentation/screens/negotiation_detail_screen.dart';
import '../../features/trip/presentation/screens/my_trips_screen.dart';

import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/order/presentation/screens/negotiation_screen.dart';
import '../../features/order/presentation/screens/rider_tracking_screen.dart';
import '../../models/place.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

// Getter public pour accéder au navigatorKey depuis d'autres fichiers
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreenNew(),
          ),
        ),
        // GoRoute(
        //   path: '/propositions/:tripId',
        //   name: 'propositions',
        //   pageBuilder: (context, state) {
        //     final tripId = state.pathParameters['tripId']!;
        //     return NoTransitionPage(
        //       child: PropositionsScreen(tripId: tripId),
        //     );
        //   },
        // ),
        GoRoute(
          path: '/my-trips',
          name: 'my-trips',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyTripsScreen(),
          ),
        ),
        GoRoute(
          path: '/activity',
          name: 'activity',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ActivityTab(),
          ),
        ),
        GoRoute(
          path: '/account',
          name: 'account',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/trip',
      name: 'trip',
      builder: (context, state) {
        final vehicleType = state.extra as String? ?? 'moto';
        return TripScreen(vehicleType: vehicleType);
      },
    ),
    GoRoute(
      path: '/negotiation',
      name: 'negotiation',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return NegotiationScreen(
          departure: params['departure'] as Place,
          destination: params['destination'] as Place,
          vehicleType: params['vehicleType'] as String,
          tripId: params['tripId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/tracking',
      name: 'tracking',
      builder: (context, state) {
        print('[ROUTER] Building tracking screen...');
        print('[ROUTER] state.extra type: ${state.extra?.runtimeType}');
        print('[ROUTER] state.extra value: ${state.extra}');

        final params = state.extra as Map<String, dynamic>? ?? {};
        print('[ROUTER] params after cast: $params');
        print('[ROUTER] driver from params: ${params['driver']}');
        print('[ROUTER] price from params: ${params['price']}');

        return RiderTrackingScreen(
          // CORRECTION: Le paramètre est 'driver', pas 'rider'
          driver: params['driver'] as Map<String, dynamic>? ?? {},
          departure: (params['departure'] ?? '') as String,
          destination: (params['destination'] ?? '') as String,
          price: params['price'] as int? ?? 0,
          tripId: params['tripId'] as String? ?? '',
          departureLat: params['departure_lat'] as double? ?? 0.0,
          departureLng: params['departure_lng'] as double? ?? 0.0,
          driverLatAtOffer: params['driverLatAtOffer'] as double? ?? 0.0,
          driverLngAtOffer: params['driverLngAtOffer'] as double? ?? 0.0,
          destinationLat: params['destination_lat'] as double? ?? 0.0,
          destinationLng: params['destination_lng'] as double? ?? 0.0,
        );
      },
    ),
    GoRoute(
      path: '/waiting-offers/:tripId',
      name: 'waiting-offers',
      builder: (context, state) {
        final tripId = state.pathParameters['tripId']!;
        final showList = state.uri.queryParameters['list'] == 'true';
        return WaitingOffersScreen(tripId: tripId);
      },
    ),
    GoRoute(
      path: '/negotiation/:offerId',
      name: 'negotiation-detail',
      builder: (context, state) {
        final offerId = state.pathParameters['offerId']!;
        final offer = state.extra as Map<String, dynamic>;
        return NegotiationDetailScreen(
          offerId: offerId,
          tripId: offer['trip_id'] as String,
          offer: offer,
        );
      },
    ),
  ],
);

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Activité',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Historique de vos trajets',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
