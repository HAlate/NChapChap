import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'widgets/call_notification_listener.dart';

// Service global pour les notifications d'appels
final notificationService = NotificationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CORRECTION : On charge les variables d'environnement avant toute autre chose.
  // L'appel `await` garantit que le chargement est terminé avant de continuer.
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Démarrer l'écoute des notifications si l'utilisateur est connecté
  if (Supabase.instance.client.auth.currentUser != null) {
    notificationService.startListening();
    print('[RiderApp] 🔔 NotificationService démarré');
  }

  runApp(
    const ProviderScope(
      child: RiderApp(), // On garde RiderApp pour plus de clarté
    ),
  );
}

// Le widget racine de l'application du passager
class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zem Rider', // Un titre spécifique pour l'app passager
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return CallNotificationListener(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
