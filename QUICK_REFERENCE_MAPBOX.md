# 🚀 Quick Reference - Migration Mapbox

## 📋 Changements rapides

### Avant (Google)
```dart
// Autocomplete
import 'package:google_maps_apis/places.dart';
final places = GoogleMapsPlaces(apiKey: key);
final response = await places.autocomplete(query);

// Directions
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
PolylinePoints polylinePoints = PolylinePoints();
PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
  googleApiKey: apiKey,
  request: PolylineRequest(origin: ..., destination: ...)
);

// Reverse Geocoding
final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$key';
final response = await http.get(Uri.parse(url));
```

### Après (Mapbox)
```dart
// Autocomplete
final mapboxGeocoding = MapboxGeocodingService(token);
final places = await mapboxGeocoding.searchPlaces(
  query,
  proximity: LatLng(lat, lng),
);

// Directions
final mapboxDirections = MapboxDirectionsService(token);
final route = await mapboxDirections.getRoute(
  origin: LatLng(lat1, lng1),
  destination: LatLng(lat2, lng2),
);
final polylinePoints = route['polyline_points'] as List<LatLng>;

// Reverse Geocoding
final place = await mapboxGeocoding.reverseGeocode(
  latitude: lat,
  longitude: lng,
);
```

---

## 🔑 Configuration

### .env
```bash
MAPBOX_ACCESS_TOKEN="YOUR_MAPBOX_ACCESS_TOKEN"
```

### Initialisation service
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mapbox_directions_service.dart';

class MyService {
  late final MapboxDirectionsService _mapboxDirections;
  
  MyService() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (token == null) throw Exception("Token manquant");
    _mapboxDirections = MapboxDirectionsService(token);
  }
}
```

---

## 📦 Fichiers modifiés

### mobile_rider
- ✅ `lib/services/mapbox_directions_service.dart` (NOUVEAU)
- ✅ `lib/services/mapbox_geocoding_service.dart` (NOUVEAU)
- 🔄 `lib/services/places_service.dart` (MODIFIÉ)
- 🔄 `lib/services/trip_service.dart` (MODIFIÉ)
- 🔄 `pubspec.yaml` (MODIFIÉ)

### mobile_driver
- ✅ `lib/services/mapbox_directions_service.dart` (NOUVEAU)
- ✅ `lib/services/mapbox_geocoding_service.dart` (NOUVEAU)
- 🔄 `lib/services/tracking_service.dart` (MODIFIÉ)
- 🔄 `pubspec.yaml` (MODIFIÉ)

---

## 🎯 API Mapbox - Utilisation

### Directions
```dart
// Itinéraire simple
final route = await mapboxDirections.getRoute(
  origin: LatLng(lat1, lng1),
  destination: LatLng(lat2, lng2),
  profile: 'driving-traffic', // 'driving', 'walking', 'cycling'
);

// Données disponibles
route['distance']        // double (mètres)
route['duration']        // double (secondes)
route['distance_text']   // String "5.4 km"
route['duration_text']   // String "15 min"
route['polyline_points'] // List<LatLng>
route['steps']           // List (instructions)

// Routes alternatives
final routes = await mapboxDirections.getAlternativeRoutes(
  origin: origin,
  destination: destination,
  alternatives: 2, // Nombre de routes
);
```

### Geocoding
```dart
// Recherche d'adresses
final places = await mapboxGeocoding.searchPlaces(
  'Restaurant',
  proximity: LatLng(currentLat, currentLng), // Optionnel
  language: 'fr',
  limit: 5,
);

// Reverse geocoding
final place = await mapboxGeocoding.reverseGeocode(
  latitude: lat,
  longitude: lng,
  language: 'fr',
);

// Distance entre 2 lieux
final distance = await mapboxGeocoding.getDistance(
  origin,    // Place
  destination, // Place
); // Retourne "5.4 km"
```

---

## 🔍 Logs de débogage

```dart
// Autocomplete
[MapboxGeocoding] Search URL: https://api.mapbox.com/geocoding/v5/...
[MapboxGeocoding] Search error: ...

// Directions
[MapboxDirections] Request URL: https://api.mapbox.com/directions/v5/...
[MapboxDirections] Error: ...

// Reverse geocoding
[MapboxGeocoding] Reverse URL: https://api.mapbox.com/geocoding/v5/...
[MapboxGeocoding] Reverse error: ...
```

---

## ⚠️ Erreurs courantes

### "Clé Mapbox non trouvée"
```dart
// Vérifier .env
final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
print('Token: ${token ?? "ABSENT"}');

// Charger .env dans main()
await dotenv.load(fileName: ".env");
```

### Polyline vide
```dart
// Vérifier le format
final route = await mapboxDirections.getRoute(...);
if (route['polyline_points'] != null) {
  final points = route['polyline_points'] as List<LatLng>;
  print('Points: ${points.length}');
} else {
  print('Aucun point reçu');
}
```

### Autocomplete ne retourne rien
```dart
// Vérifier la proximité
final places = await mapboxGeocoding.searchPlaces(
  'Restaurant',
  proximity: LatLng(currentLat, currentLng), // Important!
);
print('Résultats: ${places.length}');
```

---

## 🧪 Tests rapides

### Test 1 : Autocomplete
```dart
final places = await mapboxGeocoding.searchPlaces(
  'Douala',
  language: 'fr',
);
print('Trouvé ${places.length} lieux');
```

### Test 2 : Directions
```dart
final route = await mapboxDirections.getRoute(
  origin: LatLng(4.0511, 9.7679),      // Douala
  destination: LatLng(3.8480, 11.5021), // Yaoundé
);
print('Distance: ${route["distance_text"]}');
print('Durée: ${route["duration_text"]}');
```

### Test 3 : Reverse Geocoding
```dart
final place = await mapboxGeocoding.reverseGeocode(
  latitude: 4.0511,
  longitude: 9.7679,
);
print('Lieu: ${place.name}');
print('Adresse: ${place.address}');
```

---

## 📊 Limites API

| API | Gratuit/mois | Après quota |
|-----|--------------|-------------|
| Geocoding | 100,000 | $0.50/1000 |
| Directions | 100,000 | $0.40/1000 |
| Static Images | 200,000 | $0.25/1000 |

**Monitoring** : https://account.mapbox.com/

---

## 🚀 Commandes utiles

```bash
# Installation
cd mobile_rider && flutter pub get
cd ../mobile_driver && flutter pub get

# Clean build
flutter clean && flutter pub get

# Lancer l'app
flutter run

# Voir les logs
flutter logs

# Analyser le code
flutter analyze
```

---

## 📚 Documentation complète

- [MAPBOX_MIGRATION_GUIDE.md](./MAPBOX_MIGRATION_GUIDE.md) - Guide détaillé
- [TESTS_MIGRATION_MAPBOX.md](./TESTS_MIGRATION_MAPBOX.md) - Tests
- [MIGRATION_SUMMARY.md](./MIGRATION_SUMMARY.md) - Résumé complet

---

## 💡 Tips

### Afficher la durée en format lisible
```dart
String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours h $remainingMinutes min';
}
```

### Afficher la distance
```dart
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
```

### Tester une URL Mapbox
```
https://api.mapbox.com/geocoding/v5/mapbox.places/douala.json?access_token=VOTRE_TOKEN
```

---

**Version** : 1.0.0  
**Dernière mise à jour** : 19 décembre 2025
