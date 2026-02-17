# Tests de validation - Migration Mapbox

## 📋 Checklist de tests

### ✅ Configuration
- [x] Dépendances installées (mobile_rider)
- [x] Dépendances installées (mobile_driver)
- [x] Clé Mapbox configurée dans .env
- [x] Aucune erreur de compilation

### 🧪 Tests fonctionnels à effectuer

#### 1. mobile_rider - Recherche d'adresses (Autocomplete)

**Test** : Rechercher une adresse dans le champ de recherche

**Attendu** :
- Les suggestions apparaissent avec Mapbox
- Les résultats sont pertinents et localisés
- Les coordonnées sont correctement récupérées

**Fichier à tester** : `PlacesService.getAutocomplete()`

```dart
// Vérifier les logs dans la console :
[MapboxGeocoding] Search URL: ...
```

---

#### 2. mobile_rider - Reverse Geocoding

**Test** : Sélectionner un point sur la carte

**Attendu** :
- L'adresse du point est affichée correctement
- Le nom du lieu est pertinent

**Fichier à tester** : `PlacesService.getPlaceDetailsFromLatLng()`

```dart
// Vérifier les logs :
[MapboxGeocoding] Reverse URL: ...
```

---

#### 3. mobile_rider - Calcul d'itinéraire

**Test** : Créer un trajet entre deux points

**Attendu** :
- La polyline s'affiche sur Google Maps
- La distance et durée sont calculées
- L'itinéraire suit les routes

**Fichier à tester** : `TripService.getPolylinePoints()`

```dart
// Vérifier les logs :
[MapboxDirections] Request URL: ...
```

**Vérification visuelle** :
- La ligne bleue suit les routes (pas une ligne droite)
- La distance affichée est cohérente

---

#### 4. mobile_driver - Navigation vers passager

**Test** : Accepter une course et naviguer vers le point de départ

**Attendu** :
- L'itinéraire vers le passager s'affiche
- La polyline est visible sur Google Maps
- L'ETA est calculé

**Fichier à tester** : `TrackingService.getPolylinePoints()`

```dart
// Vérifier les logs :
[MapboxDirections] Request URL: ...
```

---

#### 5. mobile_driver - Navigation durant la course

**Test** : Démarrer une course et naviguer vers la destination

**Attendu** :
- L'itinéraire vers la destination s'affiche
- La polyline se met à jour si nécessaire
- La distance diminue progressivement

---

### 🔍 Tests de performance

#### Test de charge

**Scénario** : Effectuer 10 recherches consécutives

**Attendu** :
- Temps de réponse < 1 seconde
- Pas de ralentissement progressif
- Pas de fuite mémoire

#### Test réseau

**Scénario** : Tester avec une connexion lente (3G simulée)

**Attendu** :
- Gestion des timeout
- Messages d'erreur appropriés
- Pas de crash

---

### 🐛 Tests d'erreurs

#### 1. Clé API invalide

**Test** : Modifier `MAPBOX_ACCESS_TOKEN` dans .env

**Attendu** :
- Message d'erreur clair dans les logs
- Pas de crash de l'application
- Fallback ou message utilisateur

#### 2. Pas de connexion internet

**Test** : Désactiver le WiFi/4G

**Attendu** :
- Message d'erreur approprié
- L'application reste fonctionnelle
- Retry automatique quand connexion revient

#### 3. Adresse introuvable

**Test** : Rechercher une adresse inexistante

**Attendu** :
- Liste vide ou message "Aucun résultat"
- Pas de crash

---

### 📊 Comparaison Google vs Mapbox

#### Test A/B (si possible)

**Test** : Comparer les résultats pour la même requête

| Critère | Google | Mapbox |
|---------|--------|--------|
| Vitesse de réponse | ? | ? |
| Pertinence des résultats | ? | ? |
| Qualité des itinéraires | ? | ? |
| Distance calculée | ? | ? |

**Exemple de test** :
- Recherche : "Restaurant Douala"
- Itinéraire : Akwa → Bonanjo (Douala)

---

## 🔧 Commandes de test

### Lancer mobile_rider

```bash
cd C:\0000APP\APPZEDGO\mobile_rider
flutter run
```

### Lancer mobile_driver

```bash
cd C:\0000APP\APPZEDGO\mobile_driver
flutter run
```

### Voir les logs détaillés

```bash
# Dans une autre fenêtre terminal
flutter logs
```

### Analyser les erreurs

```bash
flutter analyze
```

---

## 📝 Résultats attendus

### Logs de succès

**Autocomplete avec Mapbox** :
```
[MapboxGeocoding] Search URL: https://api.mapbox.com/geocoding/v5/...
[MapboxGeocoding] Found 5 places
```

**Directions avec Mapbox** :
```
[MapboxDirections] Request URL: https://api.mapbox.com/directions/v5/...
[MapboxDirections] Route found: 5.4 km, 15 min
[MapboxDirections] Polyline points: 152
```

**Reverse Geocoding avec Mapbox** :
```
[MapboxGeocoding] Reverse URL: https://api.mapbox.com/geocoding/v5/...
[MapboxGeocoding] Found place: Rue de la Liberté, Douala
```

### Logs d'erreur (à investiguer)

```
❌ [MapboxDirections] Error: 401 Unauthorized
   → Vérifier MAPBOX_ACCESS_TOKEN

❌ [MapboxGeocoding] Error: No route found
   → Points trop éloignés ou inaccessibles

❌ Failed to load place suggestions: SocketException
   → Pas de connexion internet
```

---

## 🎯 Critères de validation

### ✅ Migration réussie si :

1. **Autocomplete fonctionne**
   - Résultats pertinents
   - Temps de réponse acceptable
   - Coordonnées correctes

2. **Itinéraires s'affichent**
   - Polyline visible sur Google Maps
   - Suit les routes (pas ligne droite)
   - Distance/durée cohérentes

3. **Reverse geocoding fonctionne**
   - Adresses pertinentes
   - Pas d'erreurs fréquentes

4. **Pas de régression**
   - Google Maps SDK fonctionne toujours
   - Pas de crash
   - Performance acceptable

### ❌ Migration à revoir si :

1. Erreurs fréquentes (> 10%)
2. Temps de réponse > 3 secondes
3. Résultats non pertinents
4. Crash de l'application
5. Itinéraires incohérents

---

## 📞 Support

En cas de problème :

1. Vérifier les logs : `flutter logs`
2. Vérifier .env : `cat .env`
3. Vérifier les dépendances : `flutter pub get`
4. Nettoyer le build : `flutter clean && flutter pub get`

**Token Mapbox** :
```
YOUR_MAPBOX_ACCESS_TOKEN
```

**Vérifier la validité** : https://account.mapbox.com/access-tokens/

---

## 📚 Documentation

- [Mapbox Directions API](https://docs.mapbox.com/api/navigation/directions/)
- [Mapbox Geocoding API](https://docs.mapbox.com/api/search/geocoding/)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Guide de migration](./MAPBOX_MIGRATION_GUIDE.md)
