# Debug: Problème Notification Rider

## Problème

Le rider ne reçoit pas la notification "Votre chauffeur est arrivé !" quand le driver clique sur "Je suis arrivé au point de départ".

## Architecture de la Notification

### Côté Driver

1. **Bouton**: "Je suis arrivé au point de départ"
2. **Action**: Appelle `_handleArrivedAtPickup()` (ligne 342)
3. **Service**: `TrackingService.notifyRiderDriverArrived(tripId)` (ligne 103)
4. **Update DB**: Mise à jour `trips.driver_arrived_notification` avec timestamp ISO8601

### Côté Rider

1. **Stream**: `tripStreamProvider` écoute les changements de la table `trips`
2. **Listener**: Ligne 606-627 dans `rider_tracking_screen.dart`
3. **Condition**: `notificationTime != null && notificationTime != _lastNotificationTime && mounted`
4. **Action**: Appelle `_notifyDriverArrived()` (ligne 298)
   - Joue SystemSound.alert x2 ("ding ding")
   - Affiche AlertDialog "Votre chauffeur est arrivé !"

## Modifications Apportées

### 1. Logs Détaillés Côté Driver

**Fichier**: `mobile_driver/lib/services/tracking_service.dart`

```dart
Future<void> notifyRiderDriverArrived(String tripId) async {
  print('[TRACKING_SERVICE] 📢 Sending driver arrived notification for trip: $tripId');
  final timestamp = DateTime.now().toIso8601String();
  print('[TRACKING_SERVICE] Timestamp: $timestamp');

  await _supabase.from('trips').update({
    'driver_arrived_notification': timestamp,
  }).eq('id', tripId);

  print('[TRACKING_SERVICE] ✅ Notification sent successfully');
}
```

### 2. Logs Détaillés Côté Rider

**Fichier**: `mobile_rider/lib/features/order/presentation/screens/rider_tracking_screen.dart`

```dart
ref.listen<AsyncValue<Map<String, dynamic>>>(
  tripStreamProvider(widget.tripId), (prev, next) {
    print('[RIDER_TRACKING] ===== TRIP UPDATE RECEIVED =====');
    print('[RIDER_TRACKING] Previous value: ${prev?.value}');
    print('[RIDER_TRACKING] Next value: ${next.value}');

    final notificationTime = next.value?['driver_arrived_notification'] as String?;
    print('[RIDER_TRACKING] Notification check: $notificationTime (last: $_lastNotificationTime)');
    print('[RIDER_TRACKING] Comparison: notificationTime != null? ${notificationTime != null}');
    print('[RIDER_TRACKING] Comparison: notificationTime != _lastNotificationTime? ${notificationTime != _lastNotificationTime}');
    print('[RIDER_TRACKING] Comparison: mounted? $mounted');

    if (notificationTime != null && notificationTime != _lastNotificationTime && mounted) {
      print('[RIDER_TRACKING] 🔔 TRIGGERING driver arrived notification!');
      _lastNotificationTime = notificationTime;
      _notifyDriverArrived();
    } else {
      print('[RIDER_TRACKING] ❌ Notification NOT triggered - Condition failed');
    }
  }
);
```

### 3. Script SQL de Diagnostic

**Fichier**: `check_notification_column.sql`

Vérifie:

- Existence de la colonne `driver_arrived_notification` dans la table `trips`
- Ajoute la colonne si elle n'existe pas
- Affiche les 5 derniers trips avec leur statut de notification

## Procédure de Test

### Étape 1: Vérifier la Base de Données

1. Ouvrir Supabase Dashboard → SQL Editor
2. Exécuter `check_notification_column.sql`
3. Vérifier que la colonne existe
4. Si elle n'existe pas, le script la créera automatiquement

### Étape 2: Hot Reload les Apps

```bash
# Terminal driver
r

# Terminal rider
r
# Si l'app rider a crashé (Exit Code: 1), relancer:
flutter run
```

### Étape 3: Test Complet avec Logs

1. **Créer un trip** (rider) et faire une contre-offre
2. **Accepter la contre-offre** (driver)
3. **Cliquer "Allez vers le point de départ"** (driver)
4. **Cliquer "Je suis arrivé au point de départ"** (driver)
5. **Observer les logs dans les deux consoles**

#### Logs Attendus Côté Driver:

```
[TRACKING_SERVICE] 📢 Sending driver arrived notification for trip: [trip_id]
[TRACKING_SERVICE] Timestamp: 2026-01-09T...
[TRACKING_SERVICE] ✅ Notification sent successfully
```

#### Logs Attendus Côté Rider:

```
[RIDER_TRACKING] ===== TRIP UPDATE RECEIVED =====
[RIDER_TRACKING] Next value: {..., driver_arrived_notification: 2026-01-09T...}
[RIDER_TRACKING] Notification check: 2026-01-09T... (last: null)
[RIDER_TRACKING] Comparison: notificationTime != null? true
[RIDER_TRACKING] Comparison: notificationTime != _lastNotificationTime? true
[RIDER_TRACKING] Comparison: mounted? true
[RIDER_TRACKING] 🔔 TRIGGERING driver arrived notification!
```

#### Son et Dialog Attendus:

- 🔊 SystemSound.alert joué 2 fois (300ms intervalle)
- 📱 AlertDialog "Votre chauffeur est arrivé !"

## Causes Possibles du Problème

### 1. Colonne Manquante ❌

**Symptôme**: Pas de logs `[TRACKING_SERVICE] ✅ Notification sent successfully`
**Solution**: Exécuter `check_notification_column.sql`

### 2. Stream Realtime Non Actif ⚠️

**Symptôme**: Logs driver OK, mais aucun log `[RIDER_TRACKING] ===== TRIP UPDATE RECEIVED =====`
**Solution**:

- Relancer complètement l'app rider (pas juste hot reload)
- Vérifier configuration Realtime dans Supabase (Table Editor → trips → Enable Realtime)

### 3. Condition du Listener Non Satisfaite 🔍

**Symptôme**: Logs `[RIDER_TRACKING] ❌ Notification NOT triggered`
**Solutions**:

- Si `notificationTime == null`: Problème DB (voir cause 1)
- Si `notificationTime == _lastNotificationTime`: Notification déjà affichée (comportement normal)
- Si `mounted == false`: Widget démonté (relancer app)

### 4. App Rider Crashée 💥

**Symptôme**: Terminal rider montre `Exit Code: 1`
**Solution**: `flutter run` dans le terminal rider

### 5. Délai Propagation Realtime ⏱️

**Symptôme**: Notification arrive avec 2-5 secondes de retard
**Solution**: C'est normal avec Supabase Realtime, pas un bug

## Vérifications Supplémentaires

### Vérifier Manuellement dans Supabase

1. Dashboard → Table Editor → trips
2. Trouver le trip actif
3. Après clic "Je suis arrivé", rafraîchir la table
4. Vérifier que `driver_arrived_notification` contient un timestamp

### Vérifier RLS Policies

Si la colonne est null après update:

```sql
-- Vérifier les policies sur la table trips
SELECT * FROM pg_policies WHERE tablename = 'trips';
```

La policy doit permettre UPDATE par les drivers authentifiés.

## Next Steps Si Problème Persiste

1. **Vérifier logs complets** des deux apps
2. **Screenshot de la DB** après clic "Je suis arrivé"
3. **Tester avec Realtime disabled** puis réactivé dans Supabase
4. **Vérifier version Supabase client** dans `pubspec.yaml` (>=2.0.0 requis pour Realtime v2)
