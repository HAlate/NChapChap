import 'package:flutter/material.dart';
import '../../../../services/sumup_service.dart';

class TripCompletionScreen extends StatefulWidget {
  final String tripId;
  final String riderName;
  final double distanceKm;

  const TripCompletionScreen({
    super.key,
    required this.tripId,
    required this.riderName,
    required this.distanceKm,
  });

  @override
  State<TripCompletionScreen> createState() => _TripCompletionScreenState();
}

class _TripCompletionScreenState extends State<TripCompletionScreen> {
  final SumUpService _sumupService = SumUpService();

  bool _isLoading = true;
  bool _isProcessing = false;

  Map<String, dynamic>? _costCalculation;
  String? _errorMessage;

  int _selectedTipPercentage = 0;
  final List<int> _tipOptions = [0, 10, 15, 20, 25];

  @override
  void initState() {
    super.initState();
    _calculateCost();
  }

  Future<void> _calculateCost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final calculation = await _sumupService.calculateTripCost(
        tripId: widget.tripId,
        tipPercentage: _selectedTipPercentage,
      );

      setState(() {
        _costCalculation = calculation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _processCardPayment() async {
    if (_costCalculation == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Prepare payment in database
      final paymentData = await _sumupService.preparePayment(
        tripId: widget.tripId,
        amountUsd: _costCalculation!['base_amount_cents'] / 100,
        tipPercentage: _selectedTipPercentage,
      );

      // Process payment via SumUp
      final success = await _sumupService.processPayment(
        context: context,
        transactionCode: paymentData['transaction_code'],
        totalAmount: paymentData['total_amount_cents'] / 100,
        currency: 'USD',
        title: 'Course ${widget.riderName}',
      );

      if (success && mounted) {
        // Navigate back with success
        Navigator.pop(context, {'success': true, 'paymentMethod': 'card'});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _completeTrip() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Complete trip - payment already done between driver and rider
      // Token was already deducted when the offer was accepted
      await _sumupService.completeTrip(tripId: widget.tripId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Course terminée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {'success': true, 'paymentMethod': 'cash'});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onTipPercentageChanged(int percentage) {
    setState(() {
      _selectedTipPercentage = percentage;
    });
    _calculateCost();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fin de course'),
        backgroundColor: Colors.orange,
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
                          onPressed: _calculateCost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip Summary Card
                      Container(
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
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Course terminée',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Passager: ${widget.riderName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Distance: ${widget.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Cost Breakdown
                      Text(
                        'Montant de la course',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _buildCostRow(
                        'Montant de base',
                        SumUpService.formatAmount(
                          _costCalculation!['base_amount_cents'],
                          'usd',
                        ),
                      ),
                      if (_costCalculation!['tip_amount_cents'] > 0) ...[
                        const SizedBox(height: 8),
                        _buildCostRow(
                          'Pourboire ($_selectedTipPercentage%)',
                          SumUpService.formatAmount(
                            _costCalculation!['tip_amount_cents'],
                            'usd',
                          ),
                          isHighlighted: true,
                        ),
                      ],
                      const Divider(height: 32),
                      _buildCostRow(
                        'Total',
                        SumUpService.formatAmount(
                          _costCalculation!['total_amount_cents'],
                          'usd',
                        ),
                        isTotal: true,
                      ),
                      const SizedBox(height: 32),

                      // Tip Selector
                      Text(
                        'Pourboire (optionnel)',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _tipOptions.map((percentage) {
                          final isSelected =
                              _selectedTipPercentage == percentage;
                          return ChoiceChip(
                            label: Text(
                                percentage == 0 ? 'Aucun' : '$percentage%'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _onTipPercentageChanged(percentage);
                              }
                            },
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Trip Completion
                      Text(
                        'Finaliser la course',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),

                      // Card Payment Button (only if SumUp is available)
                      if (SumUpService.isAvailable)
                        Container(
                          width: double.infinity,
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton(
                            onPressed:
                                _isProcessing ? null : _processCardPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.credit_card, size: 32),
                                      const SizedBox(width: 16),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Encaisser par carte',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            SumUpService.formatAmount(
                                              _costCalculation![
                                                  'total_amount_cents'],
                                              'usd',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                      // Info message if SumUp is not available
                      if (!SumUpService.isAvailable)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configurez SumUp pour accepter les paiements par carte',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Complete Trip Button (payment already done with rider)
                      Container(
                        width: double.infinity,
                        height: 80,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _completeTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 32, color: Colors.white),
                              const SizedBox(width: 16),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Terminer la course',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '1 jeton sera déduit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCostRow(String label, String amount,
      {bool isTotal = false, bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? Colors.orange : Colors.black,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.orange : Colors.black,
          ),
        ),
      ],
    );
  }
}
