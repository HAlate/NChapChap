import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class MerchantHomeShell extends StatefulWidget {
  final Widget child;

  const MerchantHomeShell({super.key, required this.child});

  @override
  State<MerchantHomeShell> createState() => _MerchantHomeShellState();
}

class _MerchantHomeShellState extends State<MerchantHomeShell> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.goNamed('home');
        break;
      case 1:
        context.goNamed('products');
        break;
      case 2:
        context.goNamed('orders');
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

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        indicatorColor: AppTheme.primaryBlue.withOpacity(0.15),
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
              label: 'Produits',
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: const Icon(Icons.inventory_2),
            label: 'Produits',
          ),
          NavigationDestination(
            icon: Semantics(
              label: 'Commandes',
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Semantics(
              label: 'Compte',
              child: const Icon(Icons.store_outlined),
            ),
            selectedIcon: const Icon(Icons.store),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
