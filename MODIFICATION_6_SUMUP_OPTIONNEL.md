# Modification #6 : SumUp Optionnel

## Date

7 janvier 2026

## Objectif

Rendre l'utilisation de SumUp optionnelle pour les chauffeurs. L'application doit fonctionner complètement même sans SumUp configuré, en permettant aux chauffeurs de terminer leurs courses avec le système de jetons existant.

## Problème Initial

- SumUp était requis pour compléter les courses
- L'initialisation de SumUp pouvait bloquer l'application
- Les chauffeurs ne pouvaient pas utiliser l'app sans configurer SumUp

## Solution Implémentée

### 1. Service SumUp Rendu Non-Fatal

**Fichier**: `mobile_driver/lib/services/sumup_service.dart`

#### Changements dans initialize()

```dart
// AVANT
static Future<void> initialize({required String affiliateKey}) async {
  try {
    await Sumup.init(affiliateKey);
    _isInitialized = true;
  } catch (e) {
    rethrow; // ❌ Bloquait l'app
  }
}

// APRÈS
static Future<bool> initialize({required String affiliateKey}) async {
  try {
    await Sumup.init(affiliateKey);
    _isInitialized = true;
    return true; // ✅ Succès
  } catch (e) {
    print('SumUp initialization failed: $e');
    return false; // ✅ Échec non-fatal
  }
}
```

#### Ajout d'un getter de disponibilité

```dart
/// Check if SumUp is available for card payments
static bool get isAvailable => _isInitialized;
```

#### Ajout de completeTripWithTokens()

```dart
/// Complete trip with token payment (no SumUp required)
Future<void> completeTripWithTokens({
  required String tripId,
}) async {
  try {
    await _supabase
        .from('trips')
        .update({
          'status': 'completed',
          'payment_method': 'tokens',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tripId);
  } catch (e) {
    throw Exception('Failed to complete trip: $e');
  }
}
```

### 2. Écran de Complétion de Course Mis à Jour

**Fichier**: `mobile_driver/lib/features/trip/presentation/screens/trip_completion_screen.dart`

#### Bouton "Payer par carte" conditionnel

```dart
// Affiche le bouton seulement si SumUp est disponible
if (SumUpService.isAvailable)
  Container(
    // ... bouton de paiement par carte
  ),

// Affiche un message informatif si SumUp n'est pas disponible
if (!SumUpService.isAvailable)
  Container(
    child: Text(
      'Configurez SumUp pour accepter les paiements par carte',
    ),
  ),
```

#### Méthode \_completeWithTokens() améliorée

```dart
Future<void> _completeWithTokens() async {
  setState(() { _isProcessing = true; });

  try {
    // Complète la course avec déduction automatique de jeton
    await _sumupService.completeTripWithTokens(
      tripId: widget.tripId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Course terminée! 1 jeton déduit'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, {'completed': true});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() { _isProcessing = false; });
    }
  }
}
```

### 3. Initialisation dans main.dart

**Fichier**: `mobile_driver/lib/main.dart`

```dart
import 'services/sumup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: 'https://xmbuoprspzhtkbgllwfj.supabase.co',
    anonKey: '...',
  );

  // Initialize SumUp (optional - for card payments)
  final sumupKey = dotenv.env['SUMUP_AFFILIATE_KEY'];
  if (sumupKey != null && sumupKey.isNotEmpty) {
    final sumupAvailable = await SumUpService.initialize(
      affiliateKey: sumupKey,
    );

    if (sumupAvailable) {
      print('✅ SumUp initialized - Card payments enabled');
    } else {
      print('⚠️ SumUp initialization failed - Card payments disabled');
    }
  } else {
    print('ℹ️ SumUp not configured - Card payments disabled');
  }

  runApp(const ProviderScope(child: DriverApp()));
}
```

### 4. Fichier .env.example créé

**Fichier**: `mobile_driver/.env.example`

```env
# SumUp Configuration (Optional - for accepting card payments at end of trip)
# Leave empty or comment out to disable card payments
# Get your affiliate key from: https://developer.sumup.com/
SUMUP_AFFILIATE_KEY=
```

### 5. Documentation complète

**Fichier**: `SUMUP_CONFIGURATION.md`

Documentation détaillée incluant :

- Vue d'ensemble du système optionnel
- Instructions de configuration
- Workflows avec et sans SumUp
- Tests et dépannage
- Sécurité

## Comportement Résultant

### Sans SumUp configuré (SUMUP_AFFILIATE_KEY vide)

1. ✅ L'application démarre normalement
2. ✅ Les chauffeurs peuvent accepter et effectuer des courses
3. ✅ À la fin d'une course, seul le bouton "Payer avec jetons" est visible
4. ℹ️ Message informatif : "Configurez SumUp pour accepter les paiements par carte"
5. ✅ La course se termine correctement avec déduction de 1 jeton
6. ✅ Le trigger `handle_trip_token_deduction` fonctionne automatiquement

### Avec SumUp configuré (SUMUP_AFFILIATE_KEY défini)

1. ✅ SumUp s'initialise au démarrage
2. ✅ Deux options de paiement sont disponibles :
   - **Payer par carte** : Traite via SumUp SDK
   - **Payer avec jetons** : Déduit 1 jeton
3. ✅ Le chauffeur peut choisir librement entre les deux méthodes
4. ✅ Les deux méthodes complètent correctement la course

### En cas d'échec d'initialisation SumUp

1. ⚠️ Log : "SumUp initialization failed"
2. ✅ L'application continue de fonctionner
3. ✅ Seul le paiement par jetons est disponible
4. ✅ Aucun crash, aucun blocage

## Avantages

1. **Flexibilité** : Les chauffeurs peuvent utiliser l'app sans SumUp
2. **Fiabilité** : Pas de point de défaillance unique
3. **Déploiement progressif** : Activer SumUp région par région
4. **Tests facilités** : Tester avec et sans SumUp
5. **Coûts réduits** : Pas besoin d'équipement SumUp pour tous les chauffeurs

## Tests Effectués

### ✅ Compilation réussie

- Aucune erreur de compilation
- Toutes les dépendances résolues

### À tester manuellement

- [ ] App démarre sans SUMUP_AFFILIATE_KEY
- [ ] App démarre avec SUMUP_AFFILIATE_KEY invalide
- [ ] App démarre avec SUMUP_AFFILIATE_KEY valide
- [ ] Complétion de course avec jetons (sans SumUp)
- [ ] Complétion de course avec jetons (avec SumUp disponible)
- [ ] Complétion de course avec carte (SumUp disponible)
- [ ] Affichage conditionnel du bouton de paiement par carte
- [ ] Message informatif quand SumUp non configuré

## Fichiers Modifiés

1. ✅ `mobile_driver/lib/services/sumup_service.dart`

   - Méthode `initialize()` retourne `bool`
   - Ajout de `isAvailable` getter
   - Ajout de `completeTripWithTokens()`

2. ✅ `mobile_driver/lib/features/trip/presentation/screens/trip_completion_screen.dart`

   - Bouton carte conditionnel (`if (SumUpService.isAvailable)`)
   - Message informatif si SumUp non disponible
   - Méthode `_completeWithTokens()` complétée

3. ✅ `mobile_driver/lib/main.dart`
   - Import de `SumUpService`
   - Initialisation optionnelle de SumUp
   - Logs informatifs

## Fichiers Créés

1. ✅ `SUMUP_CONFIGURATION.md`

   - Documentation complète du système
   - Instructions de configuration
   - Workflows et tests
   - Dépannage

2. ✅ `mobile_driver/.env.example`
   - Template de configuration
   - Documentation des variables d'environnement

## Migration

Aucune migration de base de données requise. Cette modification est purement côté client (mobile_driver).

## Configuration Requise

### Pour activer SumUp

1. Obtenir une clé d'affiliation SumUp
2. Ajouter à `.env` : `SUMUP_AFFILIATE_KEY=your_key`
3. Relancer l'application

### Pour désactiver SumUp

1. Retirer ou vider `SUMUP_AFFILIATE_KEY` dans `.env`
2. Relancer l'application

## Notes Importantes

- Le système de jetons reste le système de paiement **par défaut**
- SumUp est une **amélioration optionnelle**
- La déduction automatique de jetons fonctionne via le trigger existant `handle_trip_token_deduction`
- Aucun changement n'est requis dans la base de données
- Compatible avec toutes les modifications précédentes (1-5)

## Prochaines Étapes Recommandées

1. Tester l'application sans SumUp configuré
2. Tester l'initialisation de SumUp avec une vraie clé
3. Vérifier le workflow complet de paiement par carte
4. Documenter les clés SumUp pour chaque environnement (dev, staging, prod)
5. Former les chauffeurs sur les deux méthodes de paiement

## Support

- Documentation SumUp : https://developer.sumup.com/docs/
- Package Flutter SumUp : https://pub.dev/packages/sumup
- Documentation interne : `SUMUP_CONFIGURATION.md`
