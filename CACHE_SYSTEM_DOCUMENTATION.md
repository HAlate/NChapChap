# 🚀 Système de Cache Mapbox - Documentation

## 📋 Vue d'ensemble

Le système de cache a été implémenté pour réduire considérablement les coûts des API Mapbox en mettant en cache :
- **Geocoding** : Recherches d'adresses et reverse geocoding (validité : 7 jours)
- **Routes** : Itinéraires calculés (validité : 5 minutes)

## 💰 Impact sur les Coûts

### Avant le cache
- **Coût mensuel estimé** : $1 305/mois (100k requêtes/jour)

### Après le cache (taux de hit: 30%)
- **Requêtes réelles à Mapbox** : 70% des requêtes initiales
- **Coût mensuel estimé** : ~$914/mois
- **Économies** : **$391/mois** (~30%)

### Avec optimisations avancées (taux de hit: 50%)
- **Coût mensuel estimé** : ~$652/mois  
- **Économies** : **$653/mois** (~50%)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│         Application Mobile                  │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ PlacesService│    │ TripService  │
│ Tracking     │    │              │
└──────┬───────┘    └──────┬───────┘
       │                   │
       ▼                   ▼
┌──────────────┐    ┌──────────────┐
│GeocodeCacheService│RouteCacheService│
└──────┬───────┘    └──────┬───────┘
       │                   │
       └─────────┬─────────┘
                 │
                 ▼
        ┌────────────────┐
        │ Supabase DB    │
        │ ├─geocode_cache│
        │ └─route_cache  │
        └────────────────┘
                 │
        Cache Miss│? → Mapbox API
                 ▼
        ┌────────────────┐
        │  Mapbox APIs   │
        └────────────────┘
```

## 📦 Fichiers Créés

### Services de Cache

#### mobile_rider
```
lib/services/
├── geocode_cache_service.dart  ✅ Cache pour autocomplete/reverse geocoding
├── route_cache_service.dart    ✅ Cache pour les itinéraires
├── places_service.dart         🔄 Intégré GeocodeCacheService
└── trip_service.dart          🔄 Intégré RouteCacheService
```

#### mobile_driver
```
lib/services/
├── route_cache_service.dart    ✅ Cache pour les itinéraires
└── tracking_service.dart       🔄 Intégré RouteCacheService
```

### Base de données (Supabase)
```
create_cache_tables.sql         ✅ Script de création des tables et fonctions
```

## 🗄️ Structure de la Base de Données

### Table: geocode_cache

| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | Identifiant unique |
| cache_key | TEXT | Hash SHA-256 de la requête |
| query | TEXT | Requête de recherche |
| latitude | DOUBLE | Latitude (pour proximité) |
| longitude | DOUBLE | Longitude (pour proximité) |
| results | JSONB | Résultats JSON complets |
| hit_count | INTEGER | Nombre d'utilisations |
| created_at | TIMESTAMP | Date de création |
| expires_at | TIMESTAMP | Date d'expiration (7 jours) |
| updated_at | TIMESTAMP | Dernière mise à jour |

**Index** :
- `idx_geocode_cache_key` (cache_key)
- `idx_geocode_cache_query` (query)
- `idx_geocode_cache_expires` (expires_at)
- `idx_geocode_cache_coords` (latitude, longitude)

### Table: route_cache

| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | Identifiant unique |
| cache_key | TEXT | Hash SHA-256 origine+destination |
| origin_lat | DOUBLE | Latitude origine |
| origin_lng | DOUBLE | Longitude origine |
| destination_lat | DOUBLE | Latitude destination |
| destination_lng | DOUBLE | Longitude destination |
| profile | TEXT | Type de route (driving-traffic, etc.) |
| route_data | JSONB | Données complètes de la route |
| distance_meters | DOUBLE | Distance en mètres |
| duration_seconds | DOUBLE | Durée en secondes |
| hit_count | INTEGER | Nombre d'utilisations |
| created_at | TIMESTAMP | Date de création |
| expires_at | TIMESTAMP | Date d'expiration (5 minutes) |
| updated_at | TIMESTAMP | Dernière mise à jour |

**Index** :
- `idx_route_cache_key` (cache_key)
- `idx_route_cache_origin` (origin_lat, origin_lng)
- `idx_route_cache_destination` (destination_lat, destination_lng)
- `idx_route_cache_expires` (expires_at)
- `idx_route_cache_profile` (profile)

## 🔧 Installation

### 1. Installer les dépendances

```bash
cd mobile_rider
flutter pub get

cd ../mobile_driver
flutter pub get
```

### 2. Créer les tables dans Supabase

1. Aller sur [Supabase Dashboard](https://supabase.com/dashboard)
2. Sélectionner votre projet
3. Menu **SQL Editor**
4. Créer une nouvelle requête
5. Copier le contenu de `create_cache_tables.sql`
6. Exécuter le script

### 3. Vérifier l'installation

```sql
-- Vérifier les tables
SELECT * FROM public.get_geocode_cache_stats();
SELECT * FROM public.get_route_cache_stats();

-- Vérifier les vues
SELECT * FROM public.top_geocode_queries LIMIT 5;
SELECT * FROM public.top_routes LIMIT 5;
```

## 📊 Utilisation

### GeocodeCacheService

```dart
import 'services/geocode_cache_service.dart';

final cache = GeocodeCacheService();

// Recherche avec cache
Future<List<Place>> searchWithCache(String query) async {
  // Vérifier le cache
  final cachedResults = await cache.getFromCache(query);
  if (cachedResults != null) {
    return cachedResults;
  }
  
  // Sinon, appeler l'API
  final results = await mapboxAPI.search(query);
  
  // Sauvegarder dans le cache
  await cache.saveToCache(query, results);
  
  return results;
}

// Reverse geocoding avec cache
Future<Place> reverseGeocodeWithCache(double lat, double lng) async {
  final cached = await cache.getReverseGeocodeFromCache(lat, lng);
  if (cached != null) return cached;
  
  final place = await mapboxAPI.reverseGeocode(lat, lng);
  await cache.saveReverseGeocodeToCache(place);
  
  return place;
}
```

### RouteCacheService

```dart
import 'services/route_cache_service.dart';

final cache = RouteCacheService();

// Obtenir une route avec cache
Future<Map<String, dynamic>> getRouteWithCache(
  LatLng origin,
  LatLng destination,
) async {
  // Vérifier le cache
  final cachedRoute = await cache.getFromCache(origin, destination);
  if (cachedRoute != null) {
    print('Using cached route!');
    return cachedRoute;
  }
  
  // Sinon, appeler l'API
  final route = await mapboxAPI.getRoute(origin, destination);
  
  // Sauvegarder dans le cache
  await cache.saveToCache(origin, destination, route);
  
  return route;
}
```

## 📈 Monitoring & Statistiques

### Obtenir les statistiques du cache

```dart
// Stats geocoding
final geocodeStats = await GeocodeCacheService().getCacheStats();
print('Entrées totales: ${geocodeStats['total_entries']}');
print('Hits totaux: ${geocodeStats['total_hits']}');
print('Moyenne hits/entrée: ${geocodeStats['avg_hits_per_entry']}');

// Stats routes
final routeStats = await RouteCacheService().getCacheStats();
print('Taille du cache: ${routeStats['cache_size_mb']} MB');
print('Distance moyenne: ${routeStats['avg_distance_km']} km');

// Taux de hit
final hitRate = await RouteCacheService().getCacheHitRate();
print('Taux de hit: ${hitRate.toStringAsFixed(1)}%');
```

### Requêtes SQL utiles

```sql
-- Top 10 des recherches
SELECT query, hit_count, created_at 
FROM geocode_cache 
ORDER BY hit_count DESC 
LIMIT 10;

-- Top 10 des routes
SELECT 
  ROUND((distance_meters/1000)::numeric, 2) as distance_km,
  ROUND((duration_seconds/60)::numeric, 2) as duration_min,
  hit_count,
  created_at
FROM route_cache 
ORDER BY hit_count DESC 
LIMIT 10;

-- Taux de cache actif
SELECT 
  COUNT(*) FILTER (WHERE expires_at >= NOW()) as active,
  COUNT(*) FILTER (WHERE expires_at < NOW()) as expired,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE expires_at >= NOW()) / NULLIF(COUNT(*), 0),
    2
  ) as active_percentage
FROM geocode_cache;

-- Économies estimées
SELECT 
  SUM(hit_count) as total_cache_hits,
  SUM(hit_count) * 0.0005 as savings_usd -- $0.50 per 1000
FROM geocode_cache;
```

## 🧹 Maintenance

### Nettoyage manuel

```dart
// Nettoyer les caches expirés
await GeocodeCacheService().cleanExpiredCache();
await RouteCacheService().cleanExpiredCache();
```

```sql
-- Ou via SQL
SELECT * FROM public.clean_expired_caches();
-- Retourne: (geocode_deleted, route_deleted)
```

### Nettoyage automatique

Le script SQL inclut une tâche CRON qui nettoie automatiquement les caches expirés tous les jours à 2h du matin.

**Activation dans Supabase** :

1. Aller dans **Database** → **Extensions**
2. Activer `pg_cron`
3. Exécuter dans SQL Editor :

```sql
SELECT cron.schedule(
    'clean-expired-caches-daily',
    '0 2 * * *',
    $$ SELECT public.clean_expired_caches(); $$
);
```

## ⚡ Optimisations Avancées

### 1. Ajuster la durée de cache

```dart
// Dans geocode_cache_service.dart
final Duration _cacheDuration = const Duration(days: 14); // Au lieu de 7

// Dans route_cache_service.dart
final Duration _cacheDuration = const Duration(minutes: 10); // Au lieu de 5
```

### 2. Pré-charger les lieux populaires

```dart
// Script de pré-chargement
Future<void> preloadPopularPlaces() async {
  final popularPlaces = [
    'Akwa, Douala',
    'Bonanjo, Douala',
    'Bastos, Yaoundé',
    // ... autres lieux
  ];
  
  final cache = GeocodeCacheService();
  final mapbox = MapboxGeocodingService(token);
  
  for (final place in popularPlaces) {
    final results = await mapbox.searchPlaces(place);
    await cache.saveToCache(place, results);
  }
}
```

### 3. Cache en mémoire (niveau 2)

Ajouter un cache mémoire pour encore plus de performance :

```dart
class GeocodeCacheService {
  // Cache L1: Mémoire (ultra-rapide)
  final Map<String, List<Place>> _memoryCache = {};
  
  Future<List<Place>?> getFromCache(String query) async {
    // Vérifier la mémoire d'abord
    if (_memoryCache.containsKey(query)) {
      print('[Cache L1] Memory hit');
      return _memoryCache[query];
    }
    
    // Puis Supabase
    final results = await _getFromSupabase(query);
    if (results != null) {
      _memoryCache[query] = results; // Stocker en mémoire
    }
    
    return results;
  }
}
```

## 📊 Dashboard Recommandé

Créer une vue Supabase pour monitorer le cache :

```sql
CREATE OR REPLACE VIEW cache_dashboard AS
SELECT 
  'Geocode' as cache_type,
  COUNT(*) as total_entries,
  SUM(hit_count) as total_hits,
  COUNT(*) FILTER (WHERE expires_at >= NOW()) as active_entries,
  ROUND(AVG(hit_count)::numeric, 2) as avg_hits,
  ROUND((pg_total_relation_size('geocode_cache')::numeric / 1024 / 1024), 2) as size_mb,
  ROUND((SUM(hit_count) * 0.50 / 1000)::numeric, 2) as savings_usd
FROM geocode_cache
UNION ALL
SELECT 
  'Route' as cache_type,
  COUNT(*),
  SUM(hit_count),
  COUNT(*) FILTER (WHERE expires_at >= NOW()),
  ROUND(AVG(hit_count)::numeric, 2),
  ROUND((pg_total_relation_size('route_cache')::numeric / 1024 / 1024), 2),
  ROUND((SUM(hit_count) * 0.40 / 1000)::numeric, 2)
FROM route_cache;
```

## 🎯 KPIs à suivre

| Métrique | Cible | Alerte si |
|----------|-------|-----------|
| Taux de hit geocoding | > 30% | < 20% |
| Taux de hit routes | > 25% | < 15% |
| Taille cache geocoding | < 100 MB | > 200 MB |
| Taille cache routes | < 50 MB | > 100 MB |
| Entrées expirées | < 10% | > 25% |
| Économies mensuelles | > $300 | < $200 |

## ⚠️ Points d'attention

### 1. Précision des coordonnées

Les coordonnées sont arrondies pour le cache :
- **Geocoding** : 3 décimales (~111m)
- **Routes** : 4 décimales (~11m)

### 2. Durée de validité

- **Geocoding** : 7 jours (les adresses changent rarement)
- **Routes** : 5 minutes (le trafic change souvent)

### 3. Taille de la base

Surveiller la taille des tables :
- Prévoir ~1 KB par entrée geocoding
- Prévoir ~5 KB par entrée route

**Estimation** : 100k entrées = ~100 MB (geocoding) + ~500 MB (routes)

## 🚀 Prochaines Améliorations

1. **Cache prédictif** : Pré-charger les routes probables
2. **Clustering** : Grouper les requêtes similaires
3. **Analytics** : Dashboard temps réel
4. **Compression** : Compresser les données JSON
5. **Partitionnement** : Partitionner par date pour performance

## ✅ Checklist de Validation

- [x] Tables créées dans Supabase
- [x] Services de cache implémentés
- [x] Intégration dans PlacesService
- [x] Intégration dans TripService
- [x] Intégration dans TrackingService
- [ ] Tests fonctionnels effectués
- [ ] Monitoring activé
- [ ] Tâche CRON configurée
- [ ] Dashboard créé

---

**Version** : 1.0.0  
**Date** : 19 décembre 2025  
**Auteur** : GitHub Copilot  
**Statut** : ✅ Prêt pour les tests
