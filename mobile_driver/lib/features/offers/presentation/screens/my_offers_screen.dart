import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../../../services/driver_offer_service.dart';

// NOTE: Cet écran a été désactivé car le flux de travail du passager ne nécessite pas
// une liste de ses propres offres. Le passager suit les offres reçues pour sa demande de course.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Offres'),
      ),
      body: const Center(
        child: Text('Cet écran a été désactivé.'),
      ),
    );
  }
}
