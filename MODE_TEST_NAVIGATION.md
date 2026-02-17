# 🧪 Mode Test - Navigation GPS Simulée

## 📋 Description

Le mode test permet de tester tout le système de navigation et de tracking sans avoir besoin de se déplacer physiquement ou d'utiliser une app GPS fake. Le GPS est complètement simulé dans l'application.

## 🎯 Fonctionnalités

### ✅ Ce qui est simulé :
- Position GPS du chauffeur
- Déplacement automatique vers le point de pickup
- Déplacement automatique vers la destination
- Mise à jour en temps réel de la position dans Supabase
- Affichage des polylines et instructions de navigation
- Notifications au rider

### ✅ Ce qui fonctionne normalement :
- Création de course
- Acceptation d'offre
- Changements de statut
- Interface utilisateur
- Communication Supabase

## 🚀 Comment utiliser

### 1. Activer le mode test

Dans `driver_navigation_screen` :
1. Appuyez sur l'icône 🐛 (bug) en haut à droite
2. L'icône devient orange = mode test activé
3. Message de confirmation : "Mode test activé - GPS simulé"

### 2. Workflow de test complet

**Sur mobile_rider :**
1. Créer une course normale
2. Attendre qu'un chauffeur fasse une offre

**Sur mobile_driver :**
1. Voir la course disponible
2. Faire une offre
3. Attendre que le rider accepte
4. Aller sur l'écran de navigation
5. **Activer le mode test** (icône 🐛)
6. Cliquer sur "Allez vers le point de départ"
   - Le chauffeur commence 500m avant le pickup
   - Il se déplace automatiquement de 50m toutes les 2 secondes
   - Les polylines et instructions se mettent à jour
7. Arrivé au pickup : cliquer sur "Je suis arrivé"
8. Cliquer sur "Démarrer la course"
9. Cliquer sur "Allez vers la destination"
   - Le chauffeur se déplace automatiquement vers la destination
10. Arrivé à destination : cliquer sur "Je suis arrivé"
11. Course terminée !

**Sur mobile_rider :**
- Vous voyez le chauffeur se déplacer en temps réel sur la carte
- Les polylines orange montrent son trajet
- Vous recevez les notifications d'arrivée

### 3. Paramètres de simulation

Dans `test_mode_provider.dart` :

```dart
// Distance initiale du pickup
final testLat = _pickupLat - 0.005; // ~500m au sud

// Vitesse de déplacement
stepMeters: 50.0, // 50m toutes les 2 secondes = ~90 km/h

// Fréquence de mise à jour
Timer.periodic(const Duration(seconds: 2), ...)
```

### 4. Ajuster la vitesse

Pour modifier la vitesse de simulation, éditez `_startTestMovement()` :

```dart
// Plus lent (30 km/h)
stepMeters: 17.0,  // 17m toutes les 2 secondes

// Moyen (60 km/h)
stepMeters: 33.0,  // 33m toutes les 2 secondes

// Rapide (90 km/h)
stepMeters: 50.0,  // 50m toutes les 2 secondes
```

## 🔧 Architecture

### Fichiers modifiés :

1. **`core/providers/test_mode_provider.dart`** (NOUVEAU)
   - Provider pour activer/désactiver le mode test
   - Classe `TestPositionGenerator` pour créer des positions fictives
   - Fonction `moveTowards()` pour simuler le déplacement

2. **`driver_navigation_screen.dart`**
   - Import du provider test
   - Variable `_testModeTimer` pour la simulation
   - Fonction `_startTestMode()` pour initialiser la position
   - Fonction `_startTestMovement()` pour simuler le mouvement
   - Bouton 🐛 pour activer/désactiver
   - Intégration dans les boutons "Allez vers..."

### Logique de simulation :

```dart
// 1. Position initiale
_currentPosition = TestPositionGenerator.createTestPosition(
  latitude: testLat,
  longitude: testLng,
);

// 2. Mouvement progressif
Timer.periodic(Duration(seconds: 2), (timer) {
  final newPosition = TestPositionGenerator.moveTowards(
    current: _currentPosition!,
    targetLat: targetLat,
    targetLng: targetLng,
    stepMeters: 50.0,
  );
  
  // Mise à jour de la position
  setState(() => _currentPosition = newPosition);
  
  // Mise à jour Supabase
  ref.read(trackingServiceProvider).updateDriverLocation(newPosition);
});
```

## 🐛 Désactiver le mode test

1. Appuyez à nouveau sur l'icône 🐛
2. L'icône redevient grise = mode normal
3. Le timer de simulation s'arrête
4. Le GPS réel reprend le contrôle

## ⚠️ Important

- Le mode test est **local** à chaque session
- Redémarrer l'app réinitialise le mode test (désactivé)
- Le rider voit les vraies positions simulées (elles sont envoyées à Supabase)
- N'oubliez pas de désactiver le mode test pour tester avec un vrai GPS

## 🎓 Cas d'usage

### Test rapide de l'interface
Activez le mode test, testez tous les boutons et flux sans bouger.

### Test de performance
Vérifiez que les mises à jour en temps réel fonctionnent bien avec une position qui change rapidement.

### Test de logique métier
Validez que tous les changements de statut, notifications et calculs sont corrects.

### Démo client
Montrez le fonctionnement complet de l'app sans avoir à vous déplacer physiquement.

## 🔮 Améliorations futures

- [ ] Ajuster la vitesse depuis l'UI
- [ ] Mode test aussi pour le rider
- [ ] Sauvegarder les préférences de test
- [ ] Tracer un itinéraire personnalisé
- [ ] Simuler des arrêts et ralentissements
