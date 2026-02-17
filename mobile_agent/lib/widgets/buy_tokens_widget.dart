import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/token_package.dart';
import '../../../models/token_purchase.dart';
import '../../../services/token_service.dart';
import '../../../core/theme/app_theme.dart';
import 'payment_bottom_sheet.dart';

// Provider pour le service de jetons
final tokenServiceProvider = Provider((ref) => TokenService());

// Provider pour le solde de jetons
final tokenBalanceProvider = StreamProvider<TokenBalance>((ref) {
  return ref.watch(tokenServiceProvider).watchBalance();
});

// Provider pour les packages disponibles
final tokenPackagesProvider = FutureProvider<List<TokenPackage>>((ref) {
  return ref.watch(tokenServiceProvider).getActivePackages();
});

class BuyTokensWidget extends ConsumerStatefulWidget {
  const BuyTokensWidget({super.key});

  @override
  ConsumerState<BuyTokensWidget> createState() => _BuyTokensWidgetState();
}

class _BuyTokensWidgetState extends ConsumerState<BuyTokensWidget> {
  TokenPackage? _selectedPackage;

  /// Affiche un dialog pour choisir la méthode de paiement
  Future<void> _showPaymentMethodDialog(TokenPackage package) async {
    final method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir la méthode de paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PaymentMethodOption(
              title: 'Mobile Money',
              subtitle: 'Payer avec MTN, Moov, Togocom...',
              icon: Icons.phone_android,
              color: Colors.green,
              onTap: () => Navigator.pop(context, 'mobile_money'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    if (method == 'mobile_money') {
      _openMobileMoneyModal(package);
    }
  }

  /// Ouvre le modal de paiement Mobile Money
  Future<void> _openMobileMoneyModal(TokenPackage package) async {
    final tokenService = ref.read(tokenServiceProvider);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentBottomSheet(
        package: package,
        tokenService: tokenService,
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _selectedPackage = null;
      });
      ref.invalidate(tokenBalanceProvider);
      ref.invalidate(tokenPackagesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balanceAsync = ref.watch(tokenBalanceProvider);
    final packagesAsync = ref.watch(tokenPackagesProvider);

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec solde
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Acheter des jetons',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideX(begin: -0.2),
                balanceAsync.when(
                  data: (balance) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.toll,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${balance.tokensAvailable}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => const Icon(Icons.error, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les jetons sont utilisés pour faire des offres et négocier',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),

            // Packages disponibles
            packagesAsync.when(
              data: (packages) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choisissez un pack',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  ...packages.map((package) => _PackageCard(
                        package: package,
                        isSelected: _selectedPackage?.id == package.id,
                        onTap: () => _showPaymentMethodDialog(package),
                      ).animate().fadeIn(
                          delay: (300 + packages.indexOf(package) * 50).ms)),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) =>
                  Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cliquez sur un pack pour procéder au paiement Mobile Money',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }
}

/// Widget pour une option de méthode de paiement dans le dialog
class _PaymentMethodOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final TokenPackage package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.1)
              : (isDark ? Colors.grey[900] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.toll,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Détails
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${package.tokenAmount} jetons' +
                        (package.discountPercent > 0
                            ? ' + ${(package.tokenAmount * package.discountPercent / 100).round()} bonus'
                            : ''),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Prix
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${package.priceXof} F',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                if (package.discountPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${package.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
