import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/merchant_login_screen.dart';
import '../../features/auth/presentation/screens/merchant_register_screen.dart';
import '../../features/home/presentation/screens/merchant_home_shell.dart';
import '../../features/home/presentation/screens/merchant_home_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/orders/presentation/screens/merchant_orders_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const MerchantLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const MerchantRegisterScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MerchantHomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MerchantHomeScreen(),
          ),
        ),
        GoRoute(
          path: '/products',
          name: 'products',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProductsScreen(),
          ),
        ),
        GoRoute(
          path: '/orders',
          name: 'orders',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MerchantOrdersScreen(),
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
            Icon(Icons.store, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Mon Commerce', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Paramètres et profil', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
