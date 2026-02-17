import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.goNamed('home');
        break;
      case 1:
        // TODO: Remplacer par le dernier tripId connu ou afficher un message d'erreur si aucun tripId n'est disponible
        // Exemple :
        // final tripId = ...;
        // context.goNamed('propositions', pathParameters: {'tripId': tripId});
        // Pour l'instant, navigation désactivée si pas de tripId
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Sélectionnez d\'abord une course pour voir les propositions.')),
        );
        break;
      case 2:
        context.goNamed('my-trips');
        break;
      case 3:
        context.goNamed('activity');
        break;
      case 4:
        context.goNamed('account');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        indicatorColor: AppTheme.primaryOrange.withOpacity(0.15),
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
            icon: Semantics(
              label: 'Propositions',
              child: const Icon(Icons.local_offer_outlined),
            ),
            selectedIcon: const Icon(Icons.local_offer),
            label: 'Propositions',
          ),
          NavigationDestination(
            icon: Semantics(
              label: 'Courses',
              child: const Icon(Icons.local_taxi_outlined),
            ),
            selectedIcon: const Icon(Icons.local_taxi),
            label: 'Courses',
          ),
          // NavigationDestination(
          //   icon: Semantics(
          //     label: 'Activité',
          //     child: const Icon(Icons.receipt_long_outlined),
          //   ),
          //   selectedIcon: const Icon(Icons.receipt_long),
          //   label: 'Activité',
          // ),
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
