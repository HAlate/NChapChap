# Google Maps - Corrections Appliquées

## Problème
La carte Google Maps ne s'affichait pas sur le TripScreen de mobile_rider (et potentiellement sur mobile_driver).

## Solutions Appliquées

### 1. Android - Permissions et Configuration

#### mobile_rider
✅ **AndroidManifest.xml** - Ajout de la permission Internet
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

✅ **Clé API Google Maps** - Déjà configurée
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0"/>
```

#### mobile_driver
✅ Mêmes corrections appliquées

### 2. iOS - Clé API et Permissions

#### mobile_rider
✅ **AppDelegate.swift** - Import GoogleMaps et configuration de la clé API
```swift
import GoogleMaps

GMSServices.provideAPIKey("AIzaSyCAhiuAPmwfZGOUwR_TwRJ8SmRr-JhXWS0")
```

✅ **Info.plist** - Ajout des permissions de localisation
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application a besoin d'accéder à votre position...</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Cette application a besoin d'accéder à votre position...</string>

<key>io.flutter.embedded_views_preview</key>
<true/>
```

#### mobile_driver
✅ Mêmes corrections appliquées

### 3. Widget MapWidget - Amélioration

Remplacement du placeholder par un vrai widget Google Maps réutilisable:

**Caractéristiques:**
- Support complet de GoogleMap
- Position initiale configurable (défaut: Lomé, Togo - 6.1725, 1.2314)
- Hauteur personnalisable
- Markers personnalisables
- Options de localisation configurables
- Gestion du cycle de vie du controller

**Utilisation:**
```dart
MapWidget(
  height: 320,
  initialPosition: LatLng(6.1725, 1.2314),
  markers: {
    Marker(
      markerId: MarkerId('user'),
      position: LatLng(6.1725, 1.2314),
    ),
  },
  zoom: 16,
)
```

## Apps Corrigées

- ✅ mobile_rider (Android + iOS)
- ✅ mobile_driver (Android + iOS)
- ❌ mobile_merchant (pas de carte nécessaire)
- ❌ mobile_eat (pas de carte nécessaire)

## Prochaines Étapes

### Sur Votre Machine Locale:

1. **Remplacer la clé API Google Maps**
   - La clé actuelle est publique et pourrait être révoquée
   - Créez votre propre clé: https://console.cloud.google.com/
   - Remplacez dans:
     - `android/app/src/main/AndroidManifest.xml`
     - `ios/Runner/AppDelegate.swift`

2. **Activer les APIs nécessaires dans Google Cloud Console:**
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geolocation API (optionnel)

3. **Tester l'application:**
   ```bash
   cd mobile_rider
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Accorder les permissions de localisation:**
   - Au premier lancement, l'app demandera l'accès à la localisation
   - Acceptez pour voir votre position sur la carte

## Vérifications

### La carte s'affiche-t-elle maintenant?

**OUI** → Tout est OK!

**NON** → Vérifiez:
1. La clé API est valide et les APIs sont activées
2. Les permissions de localisation sont accordées
3. Vous êtes sur l'écran TripScreen (pas HomeScreen)
4. Pas d'erreurs dans les logs: `flutter logs`

### Erreurs Courantes

**"Map API Key is invalid"**
→ Remplacez la clé API par une clé valide

**"Location permission denied"**
→ Accordez les permissions dans les paramètres de l'app

**Écran gris/blanc**
→ Vérifiez la connexion Internet et les logs

## Notes Importantes

⚠️ **Clé API Publique**: La clé actuelle est dans le code source et devrait être remplacée par une clé privée avec restrictions appropriées.

⚠️ **Localisation par défaut**: Si la localisation n'est pas disponible, la carte affiche Lomé, Togo (6.1725, 1.2314).

⚠️ **iOS uniquement**: N'oubliez pas de lancer `pod install` dans le dossier `ios/` après `flutter pub get`.
