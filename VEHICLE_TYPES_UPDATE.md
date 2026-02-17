# Modification de la liste des véhicules - UUMO

**Date:** 7 janvier 2026  
**Modification:** Remplacement des types de véhicules africains par des types internationaux

## Changements effectués

### 🚗 Anciens types (supprimés)

- `moto-taxi` - Moto-taxi
- `tricycle` - Tricycle motorisé
- `taxi` - Taxi classique

### ✅ Nouveaux types (Option A - Véhicules classiques)

1. **`moto`** 🏍️ - Moto/Scooter
   - Rapide, économique, adapté aux courtes distances
2. **`car_economy`** 🚗 - Voiture économique
   - Voiture compacte, tarif abordable
3. **`car_standard`** 🚙 - Voiture standard
   - Berline classique confortable
4. **`car_premium`** 🚘 - Voiture premium
   - Véhicule haut de gamme, grand confort
5. **`suv`** 🚐 - SUV
   - Grand véhicule spacieux, plus d'espace bagages
6. **`minibus`** 🚌 - Minibus (6-8 places)
   - Transport de groupes, familles

## Fichiers modifiés

### Base de données

- ✅ `supabase/migrations/20260107000001_update_vehicle_types.sql`
  - Migration Supabase qui modifie l'ENUM `vehicle_type`
  - Convertit automatiquement les données existantes:
    - `moto-taxi` → `moto`
    - `tricycle` → `car_economy`
    - `taxi` → `car_standard`
  - Recrée la vue `trip_offers_with_driver`

### Applications Flutter

- ✅ `mobile_rider/lib/core/constants/vehicle_types.dart`

  - Enum Dart avec les 6 nouveaux types
  - Méthode `fromString()` pour conversion depuis DB
  - Descriptions et emojis pour l'UI

- ✅ `mobile_driver/lib/core/constants/vehicle_types.dart`
  - Même structure pour l'app chauffeur
  - Liste `availableForDrivers` pour sélection

## Déploiement

### 1. Appliquer la migration

```bash
cd C:\000APPS\UUMO
supabase db push
```

### 2. Redémarrer les applications

```bash
# Terminal mobile_rider
flutter run

# Terminal mobile_driver
flutter run
```

## Impact sur les données

- ✅ **Données existantes préservées** - La migration convertit automatiquement
- ✅ **Rétrocompatibilité** - Gestion des anciennes valeurs avec conversion
- ✅ **Aucune perte de données** - Tous les trips/offres existants sont migrés

## Prochaines étapes

Après avoir appliqué cette modification, les applications devront être mises à jour pour:

1. Utiliser la nouvelle enum `VehicleType` dans les formulaires
2. Afficher les nouveaux types avec icônes et descriptions
3. Adapter les filtres de recherche de chauffeurs

## Test

Pour tester après déploiement:

1. Créer un nouveau trip avec chaque type de véhicule
2. Vérifier que les chauffeurs peuvent voir et accepter les offres
3. S'assurer que les anciens trips sont toujours visibles avec leurs nouveaux types

---

**Note:** Cette modification est la première des 5 améliorations planifiées pour adapter UUMO au marché international.
