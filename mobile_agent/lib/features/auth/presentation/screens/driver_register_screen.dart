import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../services/auth_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _licenseController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedVehicleType = 'moto';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _vehiclePlateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit contenir au moins 6 caractères'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.register(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        vehicleType: _selectedVehicleType,
        vehiclePlate: _vehiclePlateController.text.trim(),
        licenseNumber: _licenseController.text.trim().isEmpty
            ? null
            : _licenseController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Compte créé avec succès! Vous pouvez maintenant vous connecter.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.pop();
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Semantics(
          label: 'Retour',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Devenir Chauffeur',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Remplissez vos informations',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 48),
              Semantics(
                label: 'Nom complet',
                textField: true,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Semantics(
                label: 'Numéro de téléphone',
                textField: true,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Semantics(
                label: 'Mot de passe',
                textField: true,
                obscured: _obscurePassword,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    hintText: 'Minimum 6 caractères',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Semantics(
                label: 'Type de véhicule',
                child: DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Type de véhicule',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'moto', child: Text('Moto')),
                    DropdownMenuItem(
                        value: 'car_economy',
                        child: Text('Voiture Économique')),
                    DropdownMenuItem(
                        value: 'car_standard', child: Text('Voiture Standard')),
                    DropdownMenuItem(
                        value: 'car_premium', child: Text('Voiture Premium')),
                    DropdownMenuItem(value: 'suv', child: Text('SUV')),
                    DropdownMenuItem(value: 'minibus', child: Text('Minibus')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedVehicleType = value);
                    }
                  },
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Semantics(
                label: 'Plaque d\'immatriculation',
                textField: true,
                child: TextField(
                  controller: _vehiclePlateController,
                  decoration: const InputDecoration(
                    labelText: 'Plaque d\'immatriculation',
                    prefixIcon: Icon(Icons.pin_outlined),
                    hintText: 'Ex: AB-1234-CD',
                  ),
                ),
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Semantics(
                label: 'Numéro de permis (optionnel)',
                textField: true,
                child: TextField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de permis (optionnel)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 32),
              Semantics(
                label: 'Soumettre ma candidature',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Soumettre ma candidature'),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .scale(begin: Offset(0.95, 0.95)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
