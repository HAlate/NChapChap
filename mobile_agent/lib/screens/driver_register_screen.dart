import 'package:flutter/material.dart';
import '../services/driver_auth_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _phone = '';
  String _password = '';
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final result = await DriverAuthService.register(_phone, _password);
    setState(() {
      _loading = false;
    });
    if (result == true) {
      setState(() {
        _success = 'Compte conducteur créé ! Connectez-vous.';
      });
    } else {
      setState(() {
        _error = 'Erreur lors de la création du compte.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription Conducteur')),
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
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onChanged: (v) => _password = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe'),
                obscureText: true,
                validator: (v) => v != _password
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Créer le compte'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_success != null) ...[
                const SizedBox(height: 20),
                Text(_success!, style: const TextStyle(color: Colors.green)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
