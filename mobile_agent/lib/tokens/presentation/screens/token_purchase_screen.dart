import 'package:flutter/material.dart';
import '../../../../services/stripe_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TokenPurchaseScreen extends StatefulWidget {
  const TokenPurchaseScreen({super.key});

  @override
  State<TokenPurchaseScreen> createState() => _TokenPurchaseScreenState();
}

class _TokenPurchaseScreenState extends State<TokenPurchaseScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StripeService _stripeService = StripeService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _packages = [];
  String _selectedCurrency = 'usd';
  String? _errorMessage;
  int? _currentBalance;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadBalance();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('token_packages')
          .select()
          .eq('is_active', true)
          .order('price_usd_cents');

      setState(() {
        _packages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('token_balances')
          .select('balance')
          .eq('user_id', userId)
          .eq('token_type', 'course')
          .maybeSingle();

      if (response != null) {
        setState(() {
          _currentBalance = response['balance'] as int;
        });
      } else {
        setState(() {
          _currentBalance = 0;
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _purchasePackage(Map<String, dynamic> package) async {
    final success = await _stripeService.purchaseTokens(
      context: context,
      packageId: package['id'],
      currency: _selectedCurrency,
    );

    if (success) {
      // Reload balance after successful purchase
      await _loadBalance();
    }
  }

  int _getPriceInCents(Map<String, dynamic> package) {
    if (_selectedCurrency == 'usd') {
      return package['price_usd_cents'] ?? 500;
    } else {
      // Convert USD to EUR (approximate)
      final usdCents = package['price_usd_cents'] ?? 500;
      return (usdCents * 0.92).round();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acheter des jetons'),
        backgroundColor: Colors.orange,
        actions: [
          // Currency selector
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedCurrency,
              dropdownColor: Colors.orange[700],
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              underline: Container(),
              items: const [
                DropdownMenuItem(value: 'usd', child: Text('USD \$')),
                DropdownMenuItem(value: 'eur', child: Text('EUR €')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCurrency = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadPackages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadPackages();
                    await _loadBalance();
                  },
                  color: Colors.orange,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Balance Card
                        if (_currentBalance != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange, Colors.orange.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Solde actuel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_currentBalance',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'jetons disponibles',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Packages disponibles',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Methods Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.credit_card,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Paiement sécurisé par Stripe\nCartes, Apple Pay, Google Pay',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Packages Grid
                        ..._packages
                            .map((package) => _buildPackageCard(package)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final tokenAmount = package['token_amount'] as int;
    final bonusTokens = package['bonus_tokens'] as int? ?? 0;
    final priceCents = _getPriceInCents(package);
    final priceFormatted =
        StripeService.formatAmount(priceCents, _selectedCurrency);
    final isPopular = package['name'] == 'Pro Pack';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPopular ? Colors.orange : Colors.grey.shade200,
                width: isPopular ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isPopular
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.grey.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package['name'] ?? 'Package',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isPopular ? Colors.orange : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: Colors.orange, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '$tokenAmount jetons',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (bonusTokens > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+$bonusTokens bonus',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          priceFormatted,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isPopular ? Colors.orange : Colors.black,
                          ),
                        ),
                        if (bonusTokens > 0)
                          Text(
                            'Total: ${tokenAmount + bonusTokens}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _purchasePackage(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPopular ? Colors.orange : Colors.orange.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Acheter maintenant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '⭐ POPULAIRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
