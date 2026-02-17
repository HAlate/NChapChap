import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/screens/driver_login_screen.dart';
import '../../features/auth/presentation/screens/driver_register_screen.dart';
import '../../features/home/presentation/screens/driver_home_shell.dart';
import '../../features/home/presentation/screens/driver_home_screen.dart';
import '../../features/requests/presentation/screens/driver_requests_screen.dart';
import '../../features/offers/presentation/screens/my_offers_screen.dart';
import '../../features/negotiation/presentation/screens/driver_negotiation_screen.dart';
import '../../features/tracking/presentation/screens/driver_navigation_screen.dart';
import '../../screens/agent_home_screen.dart';
import '../../core/theme/app_theme.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const DriverLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const DriverRegisterScreen(),
    ),
    GoRoute(
      path: '/agent-home',
      name: 'agent-home',
      builder: (context, state) => const AgentHomeScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return DriverHomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DriverHomeScreen(),
          ),
        ),
        GoRoute(
          path: '/requests',
          name: 'requests',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DriverRequestsScreen(),
          ),
        ),
        GoRoute(
          path: '/my-offers',
          name: 'my-offers',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyOffersScreen(),
          ),
        ),
        GoRoute(
          path: '/earnings',
          name: 'earnings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: EarningsTab(),
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
    GoRoute(
      path: '/negotiation/:offerId',
      name: 'negotiation',
      builder: (context, state) {
        final offerId = state.pathParameters['offerId']!;
        final offer = state.extra as Map<String, dynamic>;
        return DriverNegotiationScreen(
          offerId: offerId,
          offer: offer,
        );
      },
    ),
    GoRoute(
      path: '/driver-navigation',
      name: 'driver-navigation',
      builder: (context, state) {
        final tripData = state.extra as Map<String, dynamic>;
        return DriverNavigationScreen(
          tripData: tripData,
        );
      },
    ),
  ],
);

class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Gains', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Historique de vos revenus',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});

  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Compte'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryGreen.withOpacity(0.60),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryGreen,
                  AppTheme.primaryGreen.withOpacity(0.1),
                ],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? user?.phone ?? 'Chauffeur',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildSettingsTab(user),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsItem(
            icon: Icons.person,
            title: 'Profil',
            subtitle: user?.email ?? user?.phone ?? '',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Gérer les notifications',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.help,
            title: 'Aide',
            subtitle: 'Centre d\'aide et support',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.privacy_tip,
            title: 'Confidentialité',
            subtitle: 'Politique de confidentialité',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
          child: Icon(icon, color: AppTheme.primaryGreen),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
