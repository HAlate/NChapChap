import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../models/token_package.dart';
import '../../../../models/mobile_money_account.dart';
import '../../../../services/token_purchase_service.dart';
import '../../../../widgets/token_package_card.dart';
import '../../../../widgets/payment_dialog.dart';

class BuyTokensScreen extends StatefulWidget {
  const BuyTokensScreen({Key? key}) : super(key: key);

  @override
  State<BuyTokensScreen> createState() => _BuyTokensScreenState();
}

class _BuyTokensScreenState extends State<BuyTokensScreen> {
  final _tokenService = TokenPurchaseService();
  final _supabase = Supabase.instance.client;

  List<TokenPackage> _packages = [];
  List<MobileMoneyAccount> _momoAccounts = [];
  int _currentBalance = 0;
  bool _isLoading = true;
  String _error = '';

  final String _tokenType = 'course';
  final String _currencyCode = 'XOF';
  final String _countryCode = 'TG';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final packages =
          await _tokenService.getPackagesByType(_tokenType);
      final accounts =
          await _tokenService.getMobileMoneyAccounts(_countryCode);
      final balance = await _tokenService.getTokenBalance(userId, _tokenType);

      setState(() {
        _packages = packages;
        _momoAccounts = accounts;
        _currentBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePackageTap(TokenPackage package) async {
    if (_momoAccounts.isEmpty) {
      _showError('Aucun compte Mobile Money disponible');
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentDialog(
        package: package,
        momoAccounts: _momoAccounts,
        currencyCode: _currencyCode,
        onConfirm: (momoAccountId, senderPhone, senderName, externalTxId) =>
            _createPurchase(
          package: package,
          momoAccountId: momoAccountId,
          senderPhone: senderPhone,
          senderName: senderName,
          externalTxId: externalTxId,
        ),
      ),
    );

    if (result == true && mounted) {
      _showSuccess();
    }
  }

  Future<void> _createPurchase({
    required TokenPackage package,
    required String momoAccountId,
    required String senderPhone,
    required String senderName,
    required String externalTxId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    await _tokenService.createPurchase(
      userId: userId,
      packageId: package.id,
      tokenType: package.tokenType,
      tokenAmount: package.tokenAmount,
      pricePaid: package.getPriceForCurrency(_currencyCode),
      currencyCode: _currencyCode,
      momoAccountId: momoAccountId,
      senderPhone: senderPhone,
      senderName: senderName,
      externalTransactionId: externalTxId,
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Paiement envoyé'),
          ],
        ),
        content: const Text(
          'Votre demande a été enregistrée.\n\n'
          'Vos jetons seront crédités dans les 24 heures '
          'après vérification du paiement.\n\n'
          'Vous recevrez une notification de confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acheter des jetons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/purchase-history');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'Choisissez un pack',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPackagesGrid(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stars,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solde actuel',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_currentBalance jetons',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    '$_currentBalance courses disponibles',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Comment ça marche ?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoStep('1', 'Choisissez un pack de jetons'),
          _buildInfoStep('2', 'Payez via Mobile Money'),
          _buildInfoStep('3', 'Recevez vos jetons sous 24h'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1 jeton = 1 course acceptée',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildPackagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        return TokenPackageCard(
          package: package,
          currencyCode: _currencyCode,
          onTap: () => _handlePackageTap(package),
        );
      },
    );
  }
}
