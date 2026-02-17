import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/auth_service.dart';
import '../../../../main.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Check user type
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final userData = await Supabase.instance.client
              .from('users')
              .select('user_type')
              .eq('id', userId)
              .single();
          
          final userType = userData['user_type'];
          
          if (userType == 'agent') {
             context.goNamed('agent-home');
             return;
          } else if (userType == 'driver') {
             // Démarrer l'écoute des notifications d'appels pour les chauffeurs
             notificationService.startListening();
             print('[DriverLoginScreen] 🔔 NotificationService démarré après connexion');
             context.goNamed('home');
             return;
          } else {
             // Other types not allowed in this app
             await Supabase.instance.client.auth.signOut();
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Accès non autorisé pour ce type d\'utilisateur'),
                   backgroundColor: Colors.red,
                 ),
               );
             }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: e'),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.local_taxi,
                size: 64,
                color: AppTheme.primaryGreen,
              ).animate().fadeIn(duration: 600.ms).scale(),
              const SizedBox(height: 24),
              Text(
                'Espace Connexion',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour commencer',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 48),
              Semantics(
                label: 'Numéro de téléphone',
                textField: true,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+229 XX XX XX XX',
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
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
                    suffixIcon: Semantics(
                      label: _obscurePassword
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      button: true,
                      child: IconButton(
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
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              Semantics(
                label: 'Se connecter',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .scale(begin: Offset(0.95, 0.95)),
              const SizedBox(height: 16),
              Semantics(
                label: 'Devenir chauffeur',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.pushNamed('register'),
                    child: const Text('Devenir chauffeur'),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms)
                  .scale(begin: Offset(0.95, 0.95)),
            ],
          ),
        ),
      ),
    );
  }
}
