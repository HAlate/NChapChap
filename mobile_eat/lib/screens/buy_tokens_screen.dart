import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/buy_tokens_widget.dart';
// import '../widgets/crypto_buy_widget.dart';
import '../services/token_service.dart';
import '../core/theme/app_theme.dart';

/// Écran d'achat de tokens avec 2 méthodes de paiement :
/// 1. Mobile Money (validation manuelle admin)
/// 2. NJIA Token (crypto, validation automatique blockchain)
class BuyTokensScreen extends ConsumerStatefulWidget {
  const BuyTokensScreen({super.key});

  @override
  ConsumerState<BuyTokensScreen> createState() => _BuyTokensScreenState();
}

class _BuyTokensScreenState extends ConsumerState<BuyTokensScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Récupérer l'ID utilisateur
    final userId = ref.watch(tokenServiceProvider).getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Acheter des Tokens',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.phone_android),
              text: 'Mobile Money',
            ),
            Tab(
              icon: Icon(Icons.currency_bitcoin),
              text: 'NJIA Token',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet 1 : Mobile Money (système existant)
          const BuyTokensWidget(),

          // Onglet 2 : NJIA Token (crypto)
          // CryptoBuyWidget(userId: userId ?? 'unknown'),
        ],
      ),
    );
  }
}

// Extension pour TokenService
extension TokenServiceExtension on TokenService {
  String? getCurrentUserId() {
    // Récupérer l'ID depuis Supabase auth
    return Supabase.instance.client.auth.currentUser?.id;
  }
}
