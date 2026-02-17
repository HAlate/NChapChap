import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lpbfemncwasppngjmubn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtYnVvcHJzcHpodGtiZ2xsd2ZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc3OTk3ODgsImV4cCI6MjA4MzM3NTc4OH0.guJbWXSQR8fBfyb1LPZLaY7AtVaDrwVkFCd-UxuCnMc',
  );

  runApp(
    const ProviderScope(
      child: RestaurantApp(),
    ),
  );
}

class RestaurantApp extends ConsumerWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Urban Mobility Eat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
