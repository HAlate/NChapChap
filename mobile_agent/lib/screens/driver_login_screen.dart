import 'package:flutter/material.dart';
import '../services/driver_auth_service.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _phone = '';
  String _password = '';
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final result = await DriverAuthService.login(_phone, _password);
    setState(() { _loading = false; });
    if (result == true) {
      Navigator.pushReplacementNamed(context, '/driver/home');
    } else {
      setState(() { _error = 'Identifiants invalides ou erreur serveur.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion Conducteur')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _phone = v,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onChanged: (v) => _password = v,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator() : const Text('Se connecter'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/driver/register'),
                child: const Text("Créer un compte conducteur"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
