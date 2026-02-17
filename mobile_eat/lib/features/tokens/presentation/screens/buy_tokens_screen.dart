import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/buy_tokens_widget.dart';

/// Écran d'achat de jetons pour les restaurants
/// Utilise le nouveau système avec USSD automatique et validation admin
class BuyTokensScreen extends ConsumerWidget {
  const BuyTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Acheter des jetons',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
      ),
      body: const BuyTokensWidget(),
    );
  }
}
