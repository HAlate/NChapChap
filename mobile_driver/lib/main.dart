import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/sumup_service.dart';
import 'services/driver_sumup_config_service.dart';
import 'services/notification_service.dart';
import 'widgets/call_notification_listener.dart';

// Service global pour les notifications d'appels
final notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chargez les variables d'environnement AVANT toute autre chose.
  // L'appel `await` garantit que le chargement est terminé avant de continuer.
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Note: SumUp initialization is now done per-driver after login
  // Each driver uses their own SumUp affiliate key from driver_profiles
  print(
      'ℹ️ SumUp will be initialized with driver\'s individual key after login');

  // Démarrer l'écoute des notifications si l'utilisateur est connecté
  if (Supabase.instance.client.auth.currentUser != null) {
    notificationService.startListening();
    print('[DriverApp] 🔔 NotificationService démarré');
  }

  runApp(
    const ProviderScope(
      child: DriverApp(),
    ),
  );
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Urban Mobility Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return CallNotificationListener(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
