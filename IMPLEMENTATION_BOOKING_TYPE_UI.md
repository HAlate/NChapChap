# Implémentation Widget de Sélection - Courses Réservées

**Date:** 7 janvier 2026  
**Modification #2:** Finalisation de l'interface utilisateur

## 📱 Fichiers créés

### 1. Widgets Rider App

#### `mobile_rider/lib/widgets/booking_type_selector.dart`

Widget pour sélectionner entre course immédiate et réservée.

**Fonctionnalités:**

- Radio buttons stylisés pour chaque type
- Affichage emoji + nom + description
- Indicateur visuel de sélection (bordure verte + check)
- Animation de changement d'état

**Utilisation:**

```dart
BookingTypeSelector(
  selectedType: _selectedBookingType,
  onTypeChanged: (type) {
    setState(() {
      _selectedBookingType = type;
    });
  },
)
```

#### `mobile_rider/lib/widgets/scheduled_time_picker.dart`

DateTimePicker pour choisir la date/heure de départ d'une course réservée.

**Fonctionnalités:**

- Sélection date (jusqu'à 7 jours à l'avance)
- Sélection heure (picker natif)
- Affichage formaté: "Aujourd'hui à 14:30", "Demain à 10:00", etc.
- Affichage temps relatif: "Dans 2 heures", "Dans 3 jours"
- Validation: l'heure doit être dans le futur
- Thème Material avec accent vert

**Utilisation:**

```dart
if (_selectedBookingType.isScheduled) {
  ScheduledTimePicker(
    selectedDateTime: _scheduledTime,
    onDateTimeChanged: (dateTime) {
      setState(() {
        _scheduledTime = dateTime;
      });
    },
    minDateTime: DateTime.now().add(Duration(minutes: 30)),
    maxDateTime: DateTime.now().add(Duration(days: 7)),
  )
}
```

### 2. Écrans mis à jour

#### `mobile_rider/lib/features/trip/presentation/screens/trip_screen.dart`

**Modifications apportées:**

1. **Imports ajoutés:**

   - `booking_types.dart` - Enum pour types de réservation
   - `booking_type_selector.dart` - Widget sélecteur
   - `scheduled_time_picker.dart` - Widget date/heure

2. **État ajouté:**

   ```dart
   BookingType _selectedBookingType = BookingType.immediate;
   DateTime? _scheduledTime;
   ```

3. **Panel de confirmation étendu:**

   - Intégration du `BookingTypeSelector` après la distance
   - Affichage conditionnel du `ScheduledTimePicker` si type = scheduled
   - Bouton dynamique: "Trouver un chauffeur" ou "Réserver pour plus tard"
   - Validation: désactiver le bouton si course réservée sans heure

4. **Fonction de validation:**

   ```dart
   bool _canSubmit(Place? departure, Place? destination) {
     if (departure == null || destination == null) return false;
     if (_selectedBookingType.isScheduled && _scheduledTime == null) {
       return false;
     }
     return true;
   }
   ```

5. **Appel service mis à jour:**
   ```dart
   await ref.read(tripServiceProvider).createTrip(
     departure: departure!,
     destination: destination!,
     vehicleType: widget.vehicleType,
     bookingType: _selectedBookingType.value,
     scheduledTime: _scheduledTime,
   );
   ```

### 3. Services mis à jour

#### `mobile_rider/lib/services/trip_service.dart`

**Modifications:**

- Paramètres optionnels ajoutés: `bookingType` et `scheduledTime`
- Transmission conditionnelle à la RPC `create_new_trip`

```dart
Future<Map<String, dynamic>> createTrip({
  required Place departure,
  required Place destination,
  required String vehicleType,
  double? distanceKm,
  String? bookingType,        // ← NOUVEAU
  DateTime? scheduledTime,    // ← NOUVEAU
}) async {
  final params = {
    // ... params existants
  };

  if (bookingType != null) {
    params['p_booking_type'] = bookingType;
  }

  if (scheduledTime != null) {
    params['p_scheduled_time'] = scheduledTime.toIso8601String();
  }

  final response = await _supabase.rpc('create_new_trip', params: params).single();
  return response;
}
```

### 4. Base de données

#### `supabase/migrations/20260107000003_create_new_trip_function.sql`

Fonction Postgres pour créer un trip via RPC.

**Paramètres:**

```sql
CREATE OR REPLACE FUNCTION create_new_trip(
  p_departure text,
  p_departure_lat numeric,
  p_departure_lng numeric,
  p_destination text,
  p_destination_lat numeric,
  p_destination_lng numeric,
  p_vehicle_type vehicle_type,
  p_distance_km numeric DEFAULT NULL,
  p_booking_type booking_type DEFAULT 'immediate',  -- ← NOUVEAU
  p_scheduled_time timestamptz DEFAULT NULL         -- ← NOUVEAU
)
RETURNS jsonb
```

**Validations:**

- Vérifie que l'utilisateur est authentifié
- Si `booking_type = 'scheduled'`, `scheduled_time` doit être fourni
- `scheduled_time` doit être dans le futur

**Retour:**

- Objet JSON complet du trip créé

### 5. Dépendances

#### `mobile_rider/pubspec.yaml`

Ajout du package `intl` pour le formatage des dates:

```yaml
dependencies:
  intl: ^0.19.0
```

## 🎯 Flux utilisateur

### Course Immédiate (par défaut)

1. Utilisateur sélectionne départ/destination
2. Type "Immédiate" est présélectionné (⚡)
3. Bouton: "Trouver un chauffeur"
4. → Création trip avec `booking_type: 'immediate'`

### Course Réservée

1. Utilisateur sélectionne départ/destination
2. Utilisateur clique sur "Réservée" (📅)
3. DateTimePicker apparaît automatiquement
4. Utilisateur sélectionne date + heure
5. Affichage: "Demain à 14:30" + "Dans 1 jour"
6. Bouton: "Réserver pour plus tard" (actif seulement si heure choisie)
7. → Création trip avec `booking_type: 'scheduled'`, `scheduled_time: '2026-01-08T14:30:00Z'`

## 🔧 Prochaines étapes

### À appliquer maintenant

```bash
cd C:\000APPS\UUMO

# 1. Appliquer la migration create_new_trip
supabase db push

# 2. Installer la nouvelle dépendance intl
cd mobile_rider
flutter pub get

# 3. Lancer l'app
flutter run
```

### À implémenter ensuite (Driver App)

1. **Badge visuel dans liste des courses**

   - Afficher emoji + type de réservation
   - Couleur orange (immédiate) ou bleue (réservée)

2. **Filtre par type de réservation**

   - Bouton "Toutes" / "Immédiates" / "Réservées"
   - Compteur pour chaque type

3. **Détail course réservée**
   - Affichage heure de départ planifiée
   - Notification 30 min avant
   - Bouton "Accepter" désactivé si > 1h avant départ

## ✅ Tests à effectuer

- [ ] Créer une course immédiate → `booking_type: 'immediate'`, `scheduled_time: null`
- [ ] Créer une course réservée pour demain 10h → Valeurs correctes en DB
- [ ] Essayer de réserver pour hier → Erreur "must be in the future"
- [ ] Sélectionner "Réservée" sans choisir d'heure → Bouton désactivé
- [ ] Changer de "Réservée" à "Immédiate" → DateTimePicker disparaît
- [ ] Formatage des dates: aujourd'hui, demain, date complète
- [ ] Temps relatif: "Dans X minutes/heures/jours"

## 📊 Récapitulatif Modification #2

**Base de données:** ✅ COMPLÈTE

- Migration booking_type appliquée
- Fonction create_new_trip créée

**Backend:** ✅ COMPLÈTE

- Service TripService mis à jour
- Support paramètres optionnels

**Frontend Rider:** ✅ COMPLÈTE

- Widget BookingTypeSelector
- Widget ScheduledTimePicker
- TripScreen mis à jour
- Validation formulaire

**Frontend Driver:** ⏳ EN ATTENTE

- Badges visuels à ajouter
- Filtres par type à implémenter
- Notifications à configurer

---

**Statut global Modification #2:** 80% complété

**Prochaine étape:** Appliquer migration `20260107000003_create_new_trip_function.sql`
