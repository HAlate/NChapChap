import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/token_package.dart';
import '../models/mobile_money_account.dart';

class PaymentDialog extends StatefulWidget {
  final TokenPackage package;
  final List<MobileMoneyAccount> momoAccounts;
  final String currencyCode;
  final Function(String momoAccountId, String senderPhone, String senderName,
      String externalTxId) onConfirm;

  const PaymentDialog({
    Key? key,
    required this.package,
    required this.momoAccounts,
    required this.currencyCode,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _senderPhoneController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _externalTxIdController = TextEditingController();

  MobileMoneyAccount? _selectedAccount;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _senderPhoneController.dispose();
    _senderNameController.dispose();
    _externalTxIdController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Numéro copié!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onConfirm(
        _selectedAccount!.id,
        _senderPhoneController.text.trim(),
        _senderNameController.text.trim(),
        _externalTxIdController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.package.getFormattedPrice(widget.currencyCode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Paiement Mobile Money',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pack:'),
                          Text(
                            widget.package.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Montant:'),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Étape 1: Choisissez l\'opérateur',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                ...widget.momoAccounts.map((account) {
                  final isSelected = _selectedAccount?.id == account.id;
                  return Card(
                    color: isSelected ? Colors.blue[50] : null,
                    child: ListTile(
                      leading: account.provider?.logoUrl != null
                          ? Image.network(
                              account.provider!.logoUrl!,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.account_balance_wallet),
                            )
                          : const Icon(Icons.account_balance_wallet),
                      title: Text(account.provider?.name ?? 'Mobile Money'),
                      subtitle: Text(account.phoneNumber),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () =>
                                _copyToClipboard(account.phoneNumber),
                          ),
                          Radio<String>(
                            value: account.id,
                            groupValue: _selectedAccount?.id,
                            onChanged: (value) {
                              setState(() => _selectedAccount = account);
                            },
                          ),
                        ],
                      ),
                      onTap: () => setState(() => _selectedAccount = account),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 20),
                const Text(
                  'Étape 2: Effectuez le paiement',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Instructions:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Ouvrez votre app Mobile Money'),
                      const Text('2. Choisissez "Envoyer de l\'argent"'),
                      const Text('3. Entrez le numéro ci-dessus'),
                      Text('4. Entrez exactement: $price'),
                      const Text('5. Validez avec votre code PIN'),
                      const Text('6. Notez l\'ID de transaction du SMS'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Étape 3: Confirmez le paiement',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _senderPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Votre numéro Mobile Money',
                    hintText: '+228...',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Numéro requis';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _senderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Votre nom complet',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nom requis';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _externalTxIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID Transaction (du SMS)',
                    hintText: 'MP251130.1234.A12345',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ID transaction requis';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Confirmer le paiement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Votre achat sera confirmé sous 24h après vérification',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
