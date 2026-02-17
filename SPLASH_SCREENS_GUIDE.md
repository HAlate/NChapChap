# UUMO Splash Screens

## Description

Les écrans splash (splash screens) sont les premiers écrans affichés au lancement des applications UUMO Rider et UUMO Driver. Ils offrent une expérience visuelle cohérente avec les logos animés respectifs.

## Fonctionnalités

### 🎨 Design

- **Dégradé de fond** : Bleu foncé (#0F1A2B) avec effet de profondeur
- **Logo SVG animé** : Logo principal de chaque application
- **Animations fluides** : Fade-in et scale avec courbes d'animation personnalisées
- **Loading indicator** : Couleur adaptée à chaque variante
  - Rider : Orange (#FF6B35)
  - Driver : Vert (#34C759)

### ⚡ Animations

- **Durée** : 1.5 secondes d'animation + 3 secondes d'affichage
- **Effets** :
  - Fade-in : 0 → 100% d'opacité
  - Scale : 80% → 100% avec effet "bounce back"
  - Courbes : `Curves.easeIn` et `Curves.easeOutBack`

### 📱 Structure

```
lib/features/splash/
└── presentation/
    └── screens/
        └── splash_screen.dart
```

## Utilisation

### 1. Navigation automatique

Le splash screen s'affiche pendant 3 secondes puis navigue automatiquement vers l'écran suivant.

Pour configurer la navigation, modifier la méthode `_navigateToNextScreen()` :

```dart
void _navigateToNextScreen() {
  // Vérifier l'état de l'authentification
  final authState = ref.read(authProvider);

  if (authState.isAuthenticated) {
    // Utilisateur connecté → Écran principal
    context.go('/home');
  } else {
    // Utilisateur non connecté → Écran de connexion
    context.go('/auth/login');
  }
}
```

### 2. Intégration dans le router

#### Avec GoRouter

```dart
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
```

#### Avec MaterialApp

```dart
MaterialApp(
  home: const SplashScreen(),
  routes: {
    '/login': (context) => const LoginScreen(),
    '/home': (context) => const HomeScreen(),
  },
);
```

### 3. Personnalisation

#### Modifier la durée d'affichage

```dart
// Dans initState()
Timer(const Duration(seconds: 5), () { // Au lieu de 3
  if (mounted) {
    _navigateToNextScreen();
  }
});
```

#### Modifier les animations

```dart
_animationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 2000), // Au lieu de 1500
);
```

#### Changer la couleur de fond

```dart
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFF1A1A2E), // Nouvelle couleur
        Color(0xFF16213E),
      ],
    ),
  ),
)
```

## Assets requis

Les splash screens nécessitent les logos SVG correspondants :

- **Rider** : `assets/splash/splash_logo_rider.svg`
- **Driver** : `assets/splash/splash_logo_driver.svg`

Assurez-vous que ces assets sont déclarés dans `pubspec.yaml` :

```yaml
flutter:
  assets:
    - assets/splash/
```

## Dépendances

```yaml
dependencies:
  flutter_svg: ^2.0.9 # Pour afficher les logos SVG
```

## Bonnes pratiques

### ✅ À faire

- Garder le splash screen simple et rapide (< 3 secondes)
- Vérifier l'état d'authentification avant de naviguer
- Utiliser `if (mounted)` avant toute navigation
- Disposer correctement les AnimationControllers

### ❌ À éviter

- Ne pas faire de requêtes réseau lourdes sur le splash
- Ne pas bloquer l'utilisateur trop longtemps
- Ne pas oublier de disposer les controllers d'animation
- Ne pas naviguer sans vérifier que le widget est monté

## Exemple complet avec authentification

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animationController.forward();

    // Initialiser l'app et naviguer
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Attendre l'animation
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Vérifier l'authentification
    final authService = ref.read(authServiceProvider);
    final isAuthenticated = await authService.checkAuth();

    if (!mounted) return;

    // Naviguer
    if (isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (reste du code)
  }
}
```

## Tests

Pour tester le splash screen :

```dart
testWidgets('SplashScreen displays logo and navigates', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SplashScreen(),
    ),
  );

  // Vérifier que le logo est affiché
  expect(find.text('UUMO Rider'), findsOneWidget);

  // Attendre la navigation
  await tester.pumpAndSettle(const Duration(seconds: 4));

  // Vérifier la navigation (selon votre implémentation)
  // ...
});
```

## Troubleshooting

### Le logo ne s'affiche pas

- Vérifier que le fichier SVG existe dans `assets/splash/`
- Vérifier que l'asset est déclaré dans `pubspec.yaml`
- Exécuter `flutter pub get` après modification du pubspec

### L'animation est saccadée

- S'assurer d'utiliser `SingleTickerProviderStateMixin`
- Vérifier que le `vsync` est correctement configuré
- Tester sur un appareil physique plutôt qu'un émulateur

### Navigation ne fonctionne pas

- Vérifier que le context est valide avec `if (mounted)`
- S'assurer que le router est correctement configuré
- Vérifier les logs pour les erreurs de navigation

## Maintenance

Pour mettre à jour les logos splash :

1. Remplacer les fichiers SVG dans `c:\000APPS\UUMO\assets\splash\`
2. Copier les nouveaux logos dans chaque app :
   ```powershell
   Copy-Item "assets/splash/splash_logo_rider.svg" "mobile_rider/assets/splash/"
   Copy-Item "assets/splash/splash_logo_driver.svg" "mobile_driver/assets/splash/"
   ```
3. Exécuter `flutter pub get` dans chaque app
4. Rebuild les applications

## Ressources

- [Flutter Animations](https://docs.flutter.dev/development/ui/animations)
- [flutter_svg Documentation](https://pub.dev/packages/flutter_svg)
- [Material Design Splash Screens](https://material.io/design/communication/launch-screen.html)
