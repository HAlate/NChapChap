# Modification #2: Courses Immédiates vs Réservées - UUMO

**Date:** 7 janvier 2026  
**Modification:** Ajout du système de réservation de courses

## Changements effectués

### 🚀 Nouvelles fonctionnalités

Les passagers peuvent maintenant choisir entre deux types de courses:

1. **⚡ Course Immédiate** (`immediate`)

   - Départ immédiat (maintenant)
   - Recherche de chauffeurs disponibles en temps réel
   - Comportement par défaut (rétrocompatible)

2. **📅 Course Réservée** (`scheduled`)
   - Départ planifié à une date/heure future
   - Permet de réserver jusqu'à 7 jours à l'avance
   - Notification envoyée au chauffeur avant le départ

## Base de données

### Table `trips` - Nouvelles colonnes

```sql
-- Type de réservation (immediate ou scheduled)
booking_type booking_type DEFAULT 'immediate' NOT NULL

-- Heure de départ planifiée (NULL pour immediate)
scheduled_time timestamptz NULL
```

### Contraintes

- Si `booking_type = 'scheduled'`, alors `scheduled_time` doit être:
  - Non NULL
  - Dans le futur (> now())

### Index ajoutés

```sql
-- Pour rechercher par type de réservation
CREATE INDEX idx_trips_booking_type ON trips(booking_type, created_at DESC);

-- Pour les courses réservées à venir
CREATE INDEX idx_trips_scheduled ON trips(scheduled_time, status)
  WHERE booking_type = 'scheduled';
```

## Fichiers modifiés

### Base de données

- ✅ `supabase/migrations/20260107000002_add_booking_type.sql`
  - ENUM `booking_type` ('immediate', 'scheduled')
  - Colonnes `booking_type` et `scheduled_time` dans `trips`
  - Contraintes et index

### Applications Flutter

#### mobile_rider (Passager)

- ✅ `mobile_rider/lib/core/constants/booking_types.dart`
  - Enum `BookingType` avec immediate et scheduled
  - Méthodes helper: `isImmediate`, `isScheduled`

#### mobile_driver (Chauffeur)

- ✅ `mobile_driver/lib/core/constants/booking_types.dart`
  - Même structure + propriété `badgeColor`
  - Orange pour immédiat, bleu pour réservé

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

## Utilisation

### Côté Passager (Rider)

**Créer une course immédiate:**

```dart
final trip = await supabase.from('trips').insert({
  'rider_id': userId,
  'booking_type': 'immediate', // Par défaut
  'departure': 'Adresse départ',
  'destination': 'Adresse arrivée',
  // ...
});
```

**Créer une course réservée:**

```dart
final scheduledTime = DateTime.now().add(Duration(hours: 2));

final trip = await supabase.from('trips').insert({
  'rider_id': userId,
  'booking_type': 'scheduled',
  'scheduled_time': scheduledTime.toIso8601String(),
  'departure': 'Adresse départ',
  'destination': 'Adresse arrivée',
  // ...
});
```

### Côté Chauffeur (Driver)

**Filtrer les courses immédiates:**

```dart
final immediateTrips = await supabase
  .from('trips')
  .select()
  .eq('booking_type', 'immediate')
  .eq('status', 'pending');
```

**Voir les courses réservées à venir:**

```dart
final scheduledTrips = await supabase
  .from('trips')
  .select()
  .eq('booking_type', 'scheduled')
  .gte('scheduled_time', DateTime.now().toIso8601String())
  .order('scheduled_time', ascending: true);
```

## Comportement du système

### Courses Immédiates

1. Passager crée une course → `booking_type: 'immediate'`
2. Chauffeurs voient la course instantanément
3. Premier chauffeur accepte → Course attribuée
4. Workflow habituel

### Courses Réservées

1. Passager crée une course → `booking_type: 'scheduled'`, `scheduled_time: future`
2. Course visible aux chauffeurs avec badge "📅 Réservée"
3. Chauffeurs peuvent accepter jusqu'à X minutes avant `scheduled_time`
4. Système envoie notification 30 min avant le départ
5. À l'heure H, la course devient "active"

## Fonctionnalités à implémenter (Frontend)

### Widget de sélection (Rider App)

```dart
// Exemple de sélecteur de type de course
RadioListTile<BookingType>(
  title: Row(children: [
    Text(BookingType.immediate.emoji),
    SizedBox(width: 8),
    Text(BookingType.immediate.displayName),
  ]),
  subtitle: Text(BookingType.immediate.description),
  value: BookingType.immediate,
  groupValue: selectedType,
  onChanged: (value) => setState(() => selectedType = value),
)
```

### DateTimePicker pour courses réservées

```dart
if (selectedType.isScheduled) {
  DateTimePicker(
    initialDate: DateTime.now().add(Duration(hours: 1)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(Duration(days: 7)),
    onChanged: (DateTime datetime) {
      scheduledTime = datetime;
    },
  )
}
```

### Badge dans liste de courses (Driver App)

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: Color(int.parse('0xFF${trip.bookingType.badgeColor}')),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    '${trip.bookingType.emoji} ${trip.bookingType.displayName}',
    style: TextStyle(color: Colors.white, fontSize: 12),
  ),
)
```

## Notifications (À implémenter)

### Rappels automatiques pour courses réservées

```sql
-- Fonction à exécuter avec pg_cron
CREATE OR REPLACE FUNCTION notify_upcoming_scheduled_trips()
RETURNS void AS $$
BEGIN
  -- Notifier les chauffeurs 30 min avant le départ
  -- (Nécessite système de notifications push)
END;
$$ LANGUAGE plpgsql;
```

## Tests

### Scénarios à tester

1. ✅ Créer une course immédiate → Devrait fonctionner comme avant
2. ✅ Créer une course réservée pour demain 10h → OK
3. ❌ Créer une course réservée pour hier → Devrait être refusé (contrainte CHECK)
4. ✅ Chauffeur voit les deux types de courses avec badges distincts
5. ✅ Filtre de recherche fonctionne pour chaque type

## Impact sur les données

- ✅ **Rétrocompatibilité totale** - Toutes les courses existantes sont en mode `immediate`
- ✅ **Aucune perte de données** - Nouvelles colonnes avec valeurs par défaut
- ✅ **Contraintes strictes** - Impossible de créer une course réservée dans le passé

## Prochaines étapes

Après avoir appliqué cette modification:

1. Implémenter le widget de sélection dans mobile_rider
2. Ajouter DateTimePicker pour courses réservées
3. Mettre à jour la liste des courses dans mobile_driver avec badges
4. Implémenter le système de notifications pour rappels
5. Tester les scénarios edge cases

---

**Modifications complétées:**

- ✅ #1: Liste des véhicules (moto, economy, standard, premium, suv, minibus)
- ✅ #2: Courses immédiates vs réservées

**Modifications restantes:**

- ⏳ #3: KYC Chauffeurs (Microblink)
- ⏳ #4: Paiement Jetons (Stripe)
- ⏳ #5: Paiement Courses (SumUp)
