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

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Check user type before starting services
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('user_type')
          .eq('id', user.id)
          .single();
      
      final userType = userData['user_type'];
      
      if (userType == 'driver') {
        notificationService.startListening();
        print('[MobileAgent] 🔔 NotificationService démarré pour le chauffeur');
      } else if (userType == 'agent') {
        print('[MobileAgent] ℹ️ Mode Agent détecté - Services chauffeur désactivés');
      }
    } catch (e) {
      print('Erreur vérification type utilisateur: e');
    }
  }

  runApp(
    const ProviderScope(
      child: AgentApp(),
    ),
  );
}

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Agent ChapChap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        // Only wrap with CallNotificationListener if needed, or make it smart.
        // For now, we leave it but it might be redundant for agents.
        return CallNotificationListener(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
