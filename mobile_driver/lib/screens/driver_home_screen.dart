import 'package:flutter/material.dart';
import 'driver_status_screen.dart';
import 'admin/pending_purchases_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _available = false;

  void _onStatusChanged(bool val) {
    setState(() => _available = val);
    // TODO: envoyer le statut au backend si besoin
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accueil Conducteur')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bienvenue, conducteur !',
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            DriverStatusScreen(
              initialAvailable: _available,
              onStatusChanged: _onStatusChanged,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _available
                  ? () => Navigator.pushNamed(context, '/driver/requests')
                  : null,
              child: const Text('Voir les trajets à accepter'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Historique des courses'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/driver/tokens'),
              child: const Text('Mes jetons'),
            ),
            const SizedBox(height: 30),
            // Bouton admin (à sécuriser avec rôle utilisateur en production)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PendingPurchasesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin - Paiements'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
