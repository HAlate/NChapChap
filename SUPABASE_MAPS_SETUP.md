# 🚀 Supabase + Google Maps - Guide de Configuration

**Date**: 2025-11-30
**Statut**: ✅ Code corrigé, installation requise

---

## ⚠️ Problèmes Identifiés

### 1. **Supabase Manquant** ❌
- `supabase_flutter` n'était PAS installé
- TripService, TripOfferService ne peuvent pas fonctionner
- **Impact**: Toute l'app de négociation ne fonctionne pas

### 2. **Google Maps ne S'affiche Pas** ⚠️
- Clé API configurée: `AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0`
- Possible problème: API non activée dans Google Cloud Console

---

## ✅ Corrections Appliquées

### 1. Supabase Ajouté

**Fichier**: `mobile_rider/pubspec.yaml`
```yaml
dependencies:
  supabase_flutter: ^2.3.4  # ✅ AJOUTÉ
```

**Fichier**: `mobile_rider/lib/main.dart`
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialisation Supabase
  await Supabase.initialize(
    url: 'https://ivcofgvpjrkntpzwlfhh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  );

  runApp(const ProviderScope(child: RiderApp()));
}
```

---

## 🔧 Étapes à Suivre (OBLIGATOIRE)

### Étape 1: Installer les Dépendances

```bash
cd mobile_rider
flutter pub get
```

**Attendez que toutes les dépendances soient téléchargées.**

### Étape 2: Nettoyer le Build

```bash
flutter clean
flutter pub get
```

### Étape 3: Rebuilder l'App

**Android:**
```bash
flutter run
```

**iOS (si sur Mac):**
```bash
cd ios
pod install
cd ..
flutter run
```

---

## 🗺️ Correction Google Maps

### Configuration Actuelle (Déjà OK)

✅ **Android** - `AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0"/>
```

✅ **iOS** - `AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0")
```

### Si Maps ne S'affiche Toujours Pas

#### Option 1: Vérifier Google Cloud Console

1. Aller sur: https://console.cloud.google.com/apis/credentials
2. Chercher votre clé: `AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0`
3. **Activer ces APIs:**
   - ✅ Maps SDK for Android
   - ✅ Maps SDK for iOS
   - ✅ Geocoding API (optionnel)

#### Option 2: Créer une Nouvelle Clé

Si la clé actuelle ne fonctionne pas:

1. Créer une nouvelle clé API dans Google Cloud Console
2. Activer Maps SDK for Android et iOS
3. **Remplacer dans:**
   - `mobile_rider/android/app/src/main/AndroidManifest.xml` (ligne 9)
   - `mobile_rider/ios/Runner/AppDelegate.swift` (ligne 11)

#### Option 3: Vérifier les Logs

```bash
flutter run --verbose 2>&1 | grep -i "maps"
```

Chercher des erreurs comme:
- `API key not found`
- `API key not valid`
- `Maps SDK not enabled`

---

## 🧪 Test Rapide

### Test 1: Vérifier Supabase

Après `flutter pub get` et `flutter run`, l'app devrait démarrer sans erreur.

**Si erreur Supabase:**
- Vérifier que l'URL et anonKey sont corrects dans `main.dart`
- Vérifier la connexion internet

### Test 2: Vérifier Maps

1. Lancer l'app
2. Sélectionner un type de véhicule (Zem, Taxi, etc.)
3. **Vérifier**: La carte devrait s'afficher avec un marqueur
4. **Si carte grise/vide**: Problème de clé API

### Test 3: Vérifier la Navigation Complète

1. Entrer une destination
2. Cliquer "Rechercher des chauffeurs"
3. **Vérifier**: Navigation vers écran d'attente
4. **Vérifier**: Aucune erreur dans la console

---

## 📋 Checklist Avant de Tester

### Installation
- [ ] `flutter pub get` exécuté dans `mobile_rider/`
- [ ] `flutter clean` exécuté
- [ ] `flutter pub get` exécuté à nouveau
- [ ] App rebuilée complètement

### Configuration Maps
- [ ] Clé API présente dans AndroidManifest.xml
- [ ] Clé API présente dans AppDelegate.swift
- [ ] APIs Maps SDK activées dans Google Cloud Console
- [ ] Permissions localisation accordées sur l'appareil

### Configuration Supabase
- [ ] `supabase_flutter` dans pubspec.yaml
- [ ] Supabase initialisé dans main.dart
- [ ] URL et anonKey corrects

---

## 🎯 Workflow Complet Attendu

### 1. Lancement App
```
✅ Supabase initialized
✅ App starts without errors
✅ Home screen displays
```

### 2. Création de Trip
```
User: Sélectionne véhicule (Zem)
User: Entre destination "Hôtel Sarakawa"
User: Clique "Rechercher des chauffeurs"
↓
✅ Loading spinner appears
✅ TripService.createTrip() called
✅ Trip created in Supabase
✅ Navigation to /waiting-offers/{tripId}
```

### 3. Attente Offres
```
Screen: WaitingOffersScreen
↓
✅ Message "En attente de propositions"
✅ Real-time listener active
✅ When driver makes offer → Offer appears
```

### 4. Sélection Driver
```
User: Clique "Sélectionner" sur une offre
↓
✅ Modal opens with 2 buttons:
   - "Accepter X FCFA"
   - "Contre-proposer"
```

### 5. Négociation
```
User: Clique "Contre-proposer"
↓
✅ Navigation to /negotiation/{offerId}
✅ Form with price input + message
✅ 2 buttons: "Envoyer contre-offre" / "Accepter prix proposé"
```

---

## 🚨 Erreurs Possibles

### Erreur 1: "Supabase not initialized"
**Solution**: Vérifier que `Supabase.initialize()` est appelé dans `main.dart`

### Erreur 2: "No element" ou "Invalid trip_id"
**Solution**: Vérifier que le trip est bien créé dans Supabase avant navigation

### Erreur 3: Map grise/vide
**Causes possibles:**
- Clé API invalide
- Maps SDK non activé
- Permissions localisation refusées

**Solution**:
1. Vérifier clé API dans Google Cloud Console
2. Activer Maps SDK for Android/iOS
3. Demander permissions dans l'app

### Erreur 4: "flutter: command not found"
**Solution**: Vous devez exécuter les commandes flutter depuis votre machine, pas dans cet environnement

---

## 📝 Commandes à Exécuter MAINTENANT

```bash
# Dans votre terminal local (pas ici)
cd /chemin/vers/votre/projet/mobile_rider

# Installer les dépendances
flutter pub get

# Nettoyer
flutter clean

# Réinstaller
flutter pub get

# Lancer l'app
flutter run

# Ou avec logs verbeux
flutter run --verbose
```

---

## 🎉 Ce Qui a Été Corrigé

### Code
✅ Supabase ajouté à pubspec.yaml
✅ Supabase initialisé dans main.dart
✅ Routes navigation configurées
✅ TripService intégré
✅ Workflow complet implémenté

### Documentation
✅ NAVIGATION_NEGOTIATION_CORRIGEE.md
✅ FICHIERS_CREES.md
✅ GOOGLE_MAPS_FIX.md (existant)
✅ SUPABASE_MAPS_SETUP.md (ce fichier)

---

## ⏭️ Prochaines Étapes

1. **Exécuter** `flutter pub get` dans mobile_rider
2. **Rebuilder** l'app complètement
3. **Tester** la création de trip
4. **Vérifier** si Maps s'affiche
5. **Si Maps ne marche pas**: Vérifier Google Cloud Console
6. **Tester** le workflow complet de négociation

---

**Maintenant vous devez exécuter `flutter pub get` dans le dossier mobile_rider sur votre machine!**

Si Maps ne s'affiche toujours pas après, le problème est très probablement la clé API qui n'a pas les bonnes permissions dans Google Cloud Console.

---

**Document créé**: 2025-11-30
**Action requise**: Installation des dépendances Flutter
