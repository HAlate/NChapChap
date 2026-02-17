import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
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
      final supabase = Supabase.instance.client;

      // Inscription avec Supabase Auth
      // Le trigger handle_new_user() créera automatiquement l'entrée dans users
      final phone =
          _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

      final email = 'rider_$phone@uumo.app';
      final password = _passwordController.text;

      print('📝 Tentative d\'inscription: $email');
      print('📝 Mot de passe: $password');

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'user_type': 'rider',
        },
        emailRedirectTo: null, // Pas de redirection email
      );

      print('✅ Auth signUp réussi: ${response.user?.id}');

      if (response.user != null) {
        // Attendre que le trigger crée l'entrée dans users
        await Future.delayed(const Duration(milliseconds: 500));

        // Vérifier que l'entrée existe dans public.users
        final userCheck = await supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        print('🔍 Vérification users table: $userCheck');

        if (userCheck == null) {
          print(
              '⚠️ Utilisateur non trouvé dans public.users, création manuelle...');
          // Fallback: créer manuellement si le trigger a échoué
          await supabase.from('users').insert({
            'id': response.user!.id,
            'email': 'rider_$phone@uumo.app',
            'phone': _phoneController.text.trim(),
            'full_name': _nameController.text.trim(),
            'user_type': 'rider',
          });
          print('✅ Utilisateur créé manuellement');
        }

        if (mounted) {
          // Démarrer l'écoute des notifications d'appels
          notificationService.startListening();
          print(
              '[RegisterScreen] 🔔 NotificationService démarré après inscription');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Compte créé avec succès !\nEmail: $email\nMot de passe: $password'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
            ),
          );

          // Afficher aussi dans un dialog pour être sûr
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('✅ Compte créé'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notez vos identifiants:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SelectableText('Email: $email'),
                  const SizedBox(height: 8),
                  SelectableText('Mot de passe: $password'),
                  const SizedBox(height: 12),
                  const Text(
                      '⚠️ Utilisez exactement ces identifiants pour vous reconnecter.',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.goNamed('home');
                  },
                  child: const Text('Continuer'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur inscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
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
                'Créer un compte',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Rejoignez-nous dès maintenant',
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
                    hintText: '+229 XX XX XX XX',
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
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 32),
              Semantics(
                label: 'Créer mon compte',
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
                        : const Text('Créer mon compte'),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms)
                  .scale(begin: Offset(0.95, 0.95)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Vous avez déjà un compte ? ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Semantics(
                    label: 'Se connecter',
                    button: true,
                    child: TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Se connecter'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
