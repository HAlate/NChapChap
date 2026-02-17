# Guide de Calcul ETA (Estimated Time of Arrival)

## Vue d'ensemble

Le système calcule automatiquement le temps estimé d'arrivée (ETA) du chauffeur vers le passager en utilisant :
- **Distance** : Calculée à vol d'oiseau avec la formule de Haversine
- **Vitesse moyenne** : 10 km/h (constante définie dans les services)

## Formule de calcul

```
Distance (km) = Formule de Haversine entre deux coordonnées GPS
ETA (minutes) = (Distance ÷ Vitesse moyenne) × 60
```

### Exemple
- Distance chauffeur → passager : 3 km
- Vitesse moyenne : 10 km/h
- ETA = (3 ÷ 10) × 60 = **18 minutes**

## Implémentation

### Mobile Rider (Application Passager)

**Fichier** : `mobile_rider/lib/services/trip_service.dart`

#### Méthodes disponibles

```dart
// Calcul avec objets LatLng
int eta = tripService.calculateEtaMinutes(
  LatLng(driverLat, driverLng),
  LatLng(passengerLat, passengerLng),
);

// Calcul avec coordonnées séparées
int eta = tripService.calculateEtaFromCoordinates(
  driverLat: 6.1234,
  driverLng: 1.5678,
  passengerLat: 6.2345,
  passengerLng: 1.6789,
);
```

### Mobile Driver (Application Chauffeur)

**Fichier** : `mobile_driver/lib/services/tracking_service.dart`

#### Méthodes disponibles (identiques)

```dart
// Calcul avec objets LatLng
int eta = trackingService.calculateEtaMinutes(
  LatLng(driverLat, driverLng),
  LatLng(passengerLat, passengerLng),
);

// Calcul avec coordonnées séparées
int eta = trackingService.calculateEtaFromCoordinates(
  driverLat: 6.1234,
  driverLng: 1.5678,
  passengerLat: 6.2345,
  passengerLng: 1.6789,
);
```

## Utilisation dans l'application

### 1. Lors de la création d'une offre (Chauffeur)

Quand un chauffeur fait une offre pour une course :

```dart
// Dans driver_offers_screen.dart ou similaire
final trackingService = ref.read(trackingServiceProvider);

// Position actuelle du chauffeur
final driverPosition = await Geolocator.getCurrentPosition();

// Position du point de départ du passager (depuis tripData)
final passengerLat = tripData['departure_lat'];
final passengerLng = tripData['departure_lng'];

// Calcul de l'ETA
final etaMinutes = trackingService.calculateEtaFromCoordinates(
  driverLat: driverPosition.latitude,
  driverLng: driverPosition.longitude,
  passengerLat: passengerLat,
  passengerLng: passengerLng,
);

// Création de l'offre avec l'ETA
await offerService.createOffer(
  tripId: tripId,
  offeredPrice: price,
  etaMinutes: etaMinutes, // Utilisé ici
);
```

### 2. Affichage dans waiting_offers_screen (Passager)

Les offres reçues contiennent déjà l'ETA calculé lors de la création :

```dart
// Dans waiting_offers_screen.dart
_OfferCard(
  offer: offer,
  onTap: () => _handleSelectDriver(offer),
  timeAgo: _getTimeAgo(offer.createdAt),
)

// L'ETA est affiché via offer.etaMinutes
Text('Arrivée dans ${offer.etaMinutes} min')
```

### 3. Mise à jour en temps réel dans tracking_screen

Pour afficher l'ETA mis à jour pendant que le chauffeur se déplace :

```dart
// Dans rider_tracking_screen.dart
final tripService = ref.read(tripServiceProvider);

// Position actuelle du chauffeur (depuis le stream)
final driverPosition = driverPositionAsync.value;

// Position du passager
final passengerPosition = LatLng(departureLat, departureLng);

// Calcul ETA en temps réel
if (driverPosition != null) {
  final currentEta = tripService.calculateEtaMinutes(
    driverPosition,
    passengerPosition,
  );
  
  // Affichage
  Text('Arrivée dans $currentEta min')
}
```

## Configuration de la vitesse moyenne

Pour modifier la vitesse moyenne (actuellement 10 km/h) :

**Rider** : `mobile_rider/lib/services/trip_service.dart`
```dart
static const double _averageSpeedKmH = 10.0; // Modifier cette valeur
```

**Driver** : `mobile_driver/lib/services/tracking_service.dart`
```dart
static const double _averageSpeedKmH = 10.0; // Modifier cette valeur
```

## Formule de Haversine

Calcule la distance orthodromique (la plus courte) entre deux points sur une sphère :

```dart
double calculateDistanceKm(LatLng point1, LatLng point2) {
  const double earthRadiusKm = 6371.0;
  
  final double lat1Rad = point1.latitude * (π / 180.0);
  final double lat2Rad = point2.latitude * (π / 180.0);
  final double deltaLat = (point2.latitude - point1.latitude) * (π / 180.0);
  final double deltaLng = (point2.longitude - point1.longitude) * (π / 180.0);
  
  final double a = sin²(deltaLat/2) + cos(lat1) × cos(lat2) × sin²(deltaLng/2);
  final double c = 2 × asin(√a);
  
  return earthRadiusKm × c;
}
```

## Limitations

1. **Distance à vol d'oiseau** : Ne tient pas compte des routes réelles
2. **Vitesse constante** : Ne considère pas le trafic ou les conditions routières
3. **Approximation** : L'ETA est indicatif, pas précis au mètre près

## Améliorations futures possibles

- Utiliser Google Directions API pour obtenir la distance routière réelle
- Ajuster la vitesse en fonction de l'heure (trafic)
- Prendre en compte le type de véhicule (zem vs car)
- Intégrer les données de trafic en temps réel
- Ajouter un facteur de correction basé sur l'historique des courses

## Tests

Pour tester le calcul ETA :

```dart
// Exemple : Lomé, Togo
final eta = tripService.calculateEtaFromCoordinates(
  driverLat: 6.1256,  // Boulevard du 13 janvier
  driverLng: 1.2254,
  passengerLat: 6.1725, // Marché de Lomé
  passengerLng: 1.2314,
);

print('ETA: $eta minutes');
// Résultat attendu : environ 3-4 minutes (distance ~0.5 km)
```

## Support

Pour toute question ou modification du système ETA, contactez l'équipe de développement.
