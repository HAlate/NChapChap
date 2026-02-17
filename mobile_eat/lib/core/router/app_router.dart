import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/restaurant_login_screen.dart';
import '../../features/auth/presentation/screens/restaurant_register_screen.dart';
import '../../features/home/presentation/screens/restaurant_home_shell.dart';
import '../../features/home/presentation/screens/restaurant_home_screen.dart';
import '../../features/menu/presentation/screens/menu_management_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const RestaurantLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RestaurantRegisterScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return RestaurantHomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: RestaurantHomeScreen(),
          ),
        ),
        GoRoute(
          path: '/menu',
          name: 'menu',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MenuManagementScreen(),
          ),
        ),
        GoRoute(
          path: '/orders',
          name: 'orders',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OrdersScreen(),
          ),
        ),
        GoRoute(
          path: '/account',
          name: 'account',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AccountTab(),
          ),
        ),
      ],
    ),
  ],
);

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Mon Restaurant', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Paramètres et profil', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
