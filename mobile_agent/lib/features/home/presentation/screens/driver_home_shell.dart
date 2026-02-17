import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'driver_home_screen.dart';

class DriverHomeShell extends ConsumerStatefulWidget {
  final Widget child;

  const DriverHomeShell({super.key, required this.child});

  @override
  ConsumerState<DriverHomeShell> createState() => _DriverHomeShellState();
}

class _DriverHomeShellState extends ConsumerState<DriverHomeShell> {
  int _currentIndex = 0;

  void _onTabTapped(int index, WidgetRef ref) {
    // On récupère le statut actuel du chauffeur pour bloquer la navigation si nécessaire.
    final isDriverOnline = ref.read(isDriverOnlineProvider);

    if (index == 1 && !isDriverOnline) {
      // Si le chauffeur est hors ligne, on ne navigue pas vers "Demandes".
      return;
    }

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.goNamed('home');
        break;
      case 1:
        context.goNamed('requests');
        break;
      case 2:
        context.goNamed('earnings');
        break;
      case 3:
        context.goNamed('account');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // On écoute le statut du chauffeur pour reconstruire la barre de navigation.
    final isDriverOnline = ref.watch(isDriverOnlineProvider);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => _onTabTapped(index, ref),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        indicatorColor: AppTheme.primaryGreen.withOpacity(0.15),
        elevation: 8,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Semantics(
              label: 'Accueil',
              child: const Icon(Icons.home_outlined),
            ),
            selectedIcon: const Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            // L'icône change et le widget est désactivé si le chauffeur est hors ligne.
            icon: Icon(
              isDriverOnline ? Icons.list_alt_outlined : Icons.list_alt,
              color: isDriverOnline ? null : Colors.grey,
            ),
            selectedIcon: Icon(Icons.list_alt,
                color: isDriverOnline ? null : Colors.grey),
            label: 'Demandes',
          ),
          NavigationDestination(
            icon: Semantics(
              label: 'Gains',
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: 'Gains',
          ),
          NavigationDestination(
            icon: Semantics(
              label: 'Compte',
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: const Icon(Icons.person),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
