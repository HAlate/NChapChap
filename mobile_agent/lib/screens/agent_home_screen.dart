import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_agent/services/agent_service.dart';
import 'package:mobile_agent/widgets/input_field.dart';
import 'package:mobile_agent/widgets/custom_button.dart';
import 'package:mobile_agent/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentHomeScreen extends ConsumerStatefulWidget {
  const AgentHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends ConsumerState<AgentHomeScreen> {
  final _agentService = AgentService();
  final _phoneController = TextEditingController();
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final packages = await _agentService.getTokenPackages();
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement packages: e')),
      );
    }
  }

  Future<void> _processSale() async {
    if (_selectedPackageId == null || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un pack et entrer un numéro')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _agentService.sellTokens(
        driverPhone: _phoneController.text,
        packageId: _selectedPackageId!,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Succès'),
            content: Text(
              'Vente effectuée !\n' 
              'Chauffeur: {result['driver_phone']}\n'
              'Jetons ajoutés: {result['tokens_added']}\n'
              'Nouveau solde: {result['new_balance']}'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _phoneController.clear();
                  setState(() => _selectedPackageId = null);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vente: e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Navigate back to login handled by auth state change listener usually
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vendre des jetons',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  InputField(
                    controller: _phoneController,
                    label: 'Numéro du chauffeur',
                    hint: '+228...',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sélectionner un pack',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ..._packages.map((pkg) => _buildPackageCard(pkg)).toList(),
                  const SizedBox(height: 30),
                  CustomButton(
                    text: 'Valider la vente',
                    onPressed: _processSale,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final isSelected = _selectedPackageId == pkg['id'];
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedPackageId = pkg['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: pkg['id'],
                groupValue: _selectedPackageId,
                onChanged: (val) => setState(() => _selectedPackageId = val),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '{pkg['token_amount']} jetons + {pkg['bonus_tokens']} bonus',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                '{pkg['price_fcfa']} F',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
