import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/token_package.dart';
import '../models/mobile_money_provider.dart';
import '../services/token_service.dart';
import '../core/theme/app_theme.dart';

/// Modal de paiement Mobile Money pour l'achat de jetons
///
/// Affiche:
/// - Montant total (pack + frais)
/// - Menu déroulant pour choisir l'opérateur
/// - Champ de code de sécurité
/// - Cases SMS/WhatsApp pour accusé de réception
/// - Bouton de validation
class PaymentBottomSheet extends StatefulWidget {
  final TokenPackage package;
  final TokenService tokenService;

  const PaymentBottomSheet({
    super.key,
    required this.package,
    required this.tokenService,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  MobileMoneyProvider? _selectedProvider;
  bool _isProcessing = false;
  List<MobileMoneyProvider> _availableProviders = [];
  bool _isLoadingProviders = true;

  // Frais de transaction (2.5% du montant)
  static const double _transactionFeePercent = 2.5;

  @override
  void initState() {
    super.initState();
    _loadAvailableProviders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Charge les opérateurs Mobile Money disponibles pour le pays du chauffeur
  Future<void> _loadAvailableProviders() async {
    try {
      final providers = await widget.tokenService.getMobileMoneyProviders();
      setState(() {
        _availableProviders = providers;
        _isLoadingProviders = false;
        // Sélectionner le premier par défaut si disponible
        if (providers.isNotEmpty) {
          _selectedProvider = providers.first;
        }
      });
    } catch (e) {
      debugPrint('[PaymentBottomSheet] Error loading providers: $e');
      setState(() {
        _isLoadingProviders = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Calcule les frais de transaction
  int get _transactionFee {
    return (widget.package.priceXof * _transactionFeePercent / 100).round();
  }

  /// Calcule le montant total à payer
  int get _totalAmount {
    return widget.package.priceXof + _transactionFee;
  }

  /// Soumet le paiement
  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un opérateur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Créer la demande de paiement
      await widget.tokenService.createPaymentRequest(
        packageId: widget.package.id,
        providerId: _selectedProvider!.id,
        securityCode: '', // Pas de code secret (utilisateur déjà authentifié)
        totalAmount: _totalAmount,
        transactionFee: _transactionFee,
        smsNotification: true, // Toujours activé
        whatsappNotification: false, // Supprimé
      );

      if (mounted) {
        // Générer le code USSD
        final ussdCode = _selectedProvider!.generateUssdCode(
          amount: _totalAmount,
          securityCode: '', // Pas de code secret
        );

        Navigator.of(context).pop(true); // Retourner success

        // Composer automatiquement le code USSD
        final Uri ussdUri =
            Uri(scheme: 'tel', path: Uri.encodeComponent(ussdCode));

        try {
          if (await canLaunchUrl(ussdUri)) {
            await launchUrl(ussdUri);

            // Afficher une notification de confirmation
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      '📞 Appel USSD lancé. Suivez les instructions de l\'opérateur.'),
                  backgroundColor: AppTheme.primaryGreen,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Copier code',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ussdCode));
                    },
                  ),
                ),
              );
            }
          } else {
            throw 'Impossible de composer le code USSD automatiquement';
          }
        } catch (e) {
          // Si l'appel automatique échoue, afficher le code pour copie manuelle
          if (mounted) {
            _showUssdCodeDialog(ussdCode);
          }
        }
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
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Affiche le code USSD à composer
  void _showUssdCodeDialog(String ussdCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone_in_talk, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Code USSD à composer'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Composez ce code sur votre téléphone :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen, width: 2),
              ),
              child: SelectableText(
                ussdCode,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Instructions :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Ouvrez votre clavier téléphonique'),
                  const Text('2. Composez exactement le code ci-dessus'),
                  const Text('3. Appuyez sur la touche d\'appel'),
                  const Text('4. Suivez les instructions'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Copier le code dans le presse-papier
              Clipboard.setData(ClipboardData(text: ussdCode));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Code USSD copié'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              // Composer automatiquement le code USSD
              final Uri ussdUri =
                  Uri(scheme: 'tel', path: Uri.encodeComponent(ussdCode));
              try {
                if (await canLaunchUrl(ussdUri)) {
                  await launchUrl(ussdUri);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  throw 'Impossible de composer le code USSD';
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text('Composer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Titre
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: AppTheme.primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paiement Mobile Money',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.package.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.2),
                const SizedBox(height: 24),

                // Zone montant (lecture seule)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.primaryGreen.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Montant à envoyer',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_totalAmount.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]} ',
                            )}F CFA',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      _AmountDetailRow(
                        label: 'Prix du pack',
                        amount: widget.package.priceXof,
                      ),
                      const SizedBox(height: 8),
                      _AmountDetailRow(
                        label: 'Frais de transaction',
                        amount: _transactionFee,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).scale(),
                const SizedBox(height: 24),

                // Menu déroulant opérateur
                if (_isLoadingProviders)
                  const Center(child: CircularProgressIndicator())
                else if (_availableProviders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aucun opérateur disponible pour votre zone',
                            style: TextStyle(color: Colors.orange[900]),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opérateur Mobile Money',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<MobileMoneyProvider>(
                        value: _selectedProvider,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.primaryGreen,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[800] : Colors.grey[50],
                        ),
                        items: _availableProviders.map((provider) {
                          return DropdownMenuItem(
                            value: provider,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: provider.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      provider.code,
                                      style: TextStyle(
                                        color: provider.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    provider.displayName,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedProvider = value);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Information de paiement
                if (_selectedProvider != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[800]!.withOpacity(0.5)
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Informations de paiement',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Numéro : ${_selectedProvider!.phoneNumber}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.account_circle, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Compte : ${_selectedProvider!.accountName}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // SMS Accusé (toujours actif, non modifiable)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.green[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sms, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Vous recevrez un SMS de confirmation automatiquement',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Icon(Icons.check_circle, color: Colors.green[700]),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bouton ENVOYER
                ElevatedButton(
                  onPressed: _isProcessing || _availableProviders.isEmpty
                      ? null
                      : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'ENVOYER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ).animate().fadeIn(delay: 500.ms).scale(),
                const SizedBox(height: 12),

                // Bouton annuler
                TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher une étape d'instruction avec icône
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;

  const _InstructionStep({
    required this.number,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget pour afficher une ligne de détail de montant
class _AmountDetailRow extends StatelessWidget {
  final String label;
  final int amount;

  const _AmountDetailRow({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        Text(
          '${amount.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]} ',
              )}F CFA',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
