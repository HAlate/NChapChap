import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/sumup_service.dart';
import '../../../../services/post_login_init_service.dart';

class SumUpSettingsScreen extends StatefulWidget {
  const SumUpSettingsScreen({super.key});

  @override
  State<SumUpSettingsScreen> createState() => _SumUpSettingsScreenState();
}

class _SumUpSettingsScreenState extends State<SumUpSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _affiliateKeyController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _postLoginInitService = PostLoginInitService();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTestingConnection = false;
  String? _currentKey;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  @override
  void dispose() {
    _affiliateKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentKey() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('driver_profiles')
          .select('sumup_affiliate_key')
          .eq('id', userId)
          .single();

      _currentKey = response['sumup_affiliate_key'] as String?;

      if (_currentKey != null) {
        _affiliateKeyController.text = _currentKey!;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final newKey = _affiliateKeyController.text.trim();

      await _supabase
          .from('driver_profiles')
          .update({'sumup_affiliate_key': newKey.isEmpty ? null : newKey}).eq(
              'id', userId);

      setState(() => _currentKey = newKey.isEmpty ? null : newKey);

      // Reinitialize SumUp with the new key
      await _postLoginInitService.reinitializeSumUp();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newKey.isEmpty
                  ? '✅ Clé SumUp supprimée'
                  : '✅ Clé SumUp enregistrée et activée!',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_affiliateKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir une clé d\'affiliation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTestingConnection = true);

    try {
      final isConnected = await SumUpService.initialize(
        affiliateKey: _affiliateKeyController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected
                  ? '✅ Connexion SumUp réussie!'
                  : '❌ Échec de connexion SumUp. Vérifiez votre clé.',
            ),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
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
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Future<void> _removeKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la clé SumUp'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer votre clé SumUp?\n\n'
          'Vous ne pourrez plus accepter de paiements par carte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('driver_profiles')
          .update({'sumup_affiliate_key': null}).eq('user_id', userId);

      _affiliateKeyController.clear();
      setState(() => _currentKey = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clé SumUp supprimée'),
            backgroundColor: Colors.orange,
          ),
        );
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration SumUp'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Compte SumUp personnel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Configurez votre propre compte SumUp pour recevoir '
                            'les paiements par carte directement sur votre compte.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Current Status
                    if (_currentKey != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'SumUp configuré - Paiements par carte activés',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Affiliate Key Input
                    Text(
                      'Clé d\'affiliation SumUp',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _affiliateKeyController,
                      decoration: InputDecoration(
                        hintText: 'Entrez votre clé d\'affiliation',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: _currentKey != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    _affiliateKeyController.clear(),
                              )
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null; // Optional field
                        }
                        if (value.trim().length < 10) {
                          return 'La clé semble trop courte';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Help Text
                    Text(
                      'Obtenez votre clé d\'affiliation sur developer.sumup.com',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Test Connection Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isTestingConnection || _isSaving
                            ? null
                            : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(
                          _isTestingConnection
                              ? 'Test en cours...'
                              : 'Tester la connexion',
                        ),
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: Colors.orange, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSaving || _isTestingConnection ? null : _saveKey,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving
                            ? 'Enregistrement...'
                            : 'Enregistrer la clé'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Remove Button (only if key exists)
                    if (_currentKey != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving || _isTestingConnection
                              ? null
                              : _removeKey,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer la clé'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // How to Get Key
                    ExpansionTile(
                      title: const Text('Comment obtenir ma clé ?'),
                      leading: const Icon(Icons.help_outline),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStep('1',
                                  'Créez un compte sur developer.sumup.com'),
                              const SizedBox(height: 12),
                              _buildStep('2', 'Créez une nouvelle application'),
                              const SizedBox(height: 12),
                              _buildStep('3',
                                  'Copiez votre clé d\'affiliation (Affiliate Key)'),
                              const SizedBox(height: 12),
                              _buildStep(
                                  '4', 'Collez-la dans le champ ci-dessus'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}
