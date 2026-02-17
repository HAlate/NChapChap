import 'package:flutter/material.dart';
import '../services/driver_auth_service.dart';
import '../../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DriverTokensScreen extends StatefulWidget {
  const DriverTokensScreen({super.key});

  @override
  State<DriverTokensScreen> createState() => _DriverTokensScreenState();
}

class _DriverTokensScreenState extends State<DriverTokensScreen> {
  int? _tokens;
  bool _loading = false;
  String? _message;
  final _amountController = TextEditingController();
  final _codeController = TextEditingController();
  bool _awaitingCode = false;

  Future<void> _fetchTokens() async {
    setState(() {
      _loading = true;
    });
    final token = await DriverAuthService.getToken();
    if (token == null) return;
    // Appel profil pour récupérer le nombre de jetons
    final response = await http.get(
      Uri.parse('http://10.0.2.2:3001/api/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _tokens = data['tokens'] ?? 0;
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _buyTokens() async {
    setState(() {
      _awaitingCode = true;
      _message = null;
    });
    // On ne fait rien ici, on attend la saisie du code de confirmation
  }

  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes jetons')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Jetons disponibles :', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            _loading
                ? const CircularProgressIndicator()
                : Text(_tokens?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            const Text('Acheter des jetons (1 jeton = 10F CFA)',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              enabled: !_awaitingCode,
              decoration:
                  const InputDecoration(labelText: 'Montant (F CFA, min 10)'),
            ),
            const SizedBox(height: 10),
            if (!_awaitingCode)
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        final amount =
                            int.tryParse(_amountController.text) ?? 0;
                        if (amount < 10) {
                          setState(() {
                            _message = 'Montant minimum : 10F CFA (1 jeton)';
                          });
                          return;
                        }
                        _buyTokens();
                      },
                child: const Text('Acheter'),
              ),
            if (_awaitingCode) ...[
              const SizedBox(height: 16),
              const Text(
                  'Après paiement, saisissez le code de confirmation reçu par SMS :'),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'Code de confirmation'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() {
                          _loading = true;
                          _message = null;
                        });
                        final token = await DriverAuthService.getToken();
                        if (token == null) return;
                        final userId =
                            await DriverAuthService.getUserIdFromToken(token);
                        if (userId == null) {
                          setState(() {
                            _message =
                                "Impossible de récupérer l'identifiant utilisateur.";
                            _loading = false;
                          });
                          return;
                        }
                        final amount =
                            int.tryParse(_amountController.text) ?? 0;
                        final code = _codeController.text.trim();
                        final resp = await ApiService.validatePayment(
                          userId: userId,
                          amount: amount,
                          codeConfirmation: code,
                        );
                        if (resp.statusCode == 200) {
                          setState(() {
                            _message = 'Jetons crédités avec succès !';
                            _awaitingCode = false;
                            _amountController.clear();
                            _codeController.clear();
                          });
                          await _fetchTokens();
                        } else {
                          setState(() {
                            _message = 'Erreur : ${resp.body}';
                          });
                        }
                        setState(() {
                          _loading = false;
                        });
                      },
                child: const Text('Valider le paiement'),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 20),
              Text(_message!,
                  style: TextStyle(
                      color: _message!.contains('succès')
                          ? Colors.green
                          : Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
