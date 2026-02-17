import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/buy_tokens_widget.dart';
import '../core/theme/app_theme.dart';

/// Écran d'achat de tokens avec Mobile Money
class BuyTokensScreen extends ConsumerStatefulWidget {
  const BuyTokensScreen({super.key});

  @override
  ConsumerState<BuyTokensScreen> createState() => _BuyTokensScreenState();
}

class _BuyTokensScreenState extends ConsumerState<BuyTokensScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Acheter des Tokens',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: const BuyTokensWidget(),
    );
  }
}
