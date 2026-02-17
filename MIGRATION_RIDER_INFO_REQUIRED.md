# Migrations manuelles requises

## Migration 1 : Ajout des informations du rider à la vue trip_offers_with_driver

### Problème résolu
L'écran de négociation du chauffeur (driver_negotiation_screen) n'affichait pas les informations du passager (nom, téléphone, rating), ni les adresses de départ et destination.

## Cause
La vue `trip_offers_with_driver` ne contenait que les informations du chauffeur et du trajet, mais pas celles du passager (rider).

## Solution
Une nouvelle migration SQL a été créée pour enrichir la vue avec les informations du rider.

## Fichiers modifiés

### 1. Migration SQL
**Fichier:** `supabase/migrations/20251216_add_rider_info_to_trip_offers_view.sql`

Cette migration modifie la vue `trip_offers_with_driver` pour inclure :
- `rider_name` : Nom complet du passager
- `rider_phone` : Numéro de téléphone du passager

### 2. Code Flutter modifié
**Fichier:** `mobile_driver/lib/features/negotiation/presentation/screens/driver_negotiation_screen.dart`

Le code a été mis à jour pour utiliser les nouveaux champs plats de la vue au lieu d'une structure imbriquée :

```dart
// AVANT (structure imbriquée - ne fonctionnait pas)
final trip = currentOffer['trip'] as Map<String, dynamic>?;
final rider = trip?['rider'] as Map<String, dynamic>?;
Text(rider?['full_name'] ?? 'Client')

// APRÈS (champs plats de la vue)
final riderName = currentOffer['rider_name'] as String?;
Text(riderName ?? 'Client')
```

**Fichier:** `mobile_driver/lib/services/driver_offer_service.dart`

Correction du `watchOffer()` pour toujours recharger les données depuis la vue au lieu de pousser directement le payload (qui ne contient que les champs de la table trip_offers sans enrichissement).

## Comment appliquer la migration

### Option 1 : Via l'interface web Supabase (RECOMMANDÉ)

1. Connectez-vous à votre projet Supabase : https://app.supabase.com
2. Allez dans **SQL Editor**
3. Créez une nouvelle requête
4. Copiez-collez le contenu du fichier `supabase/migrations/20251216_add_rider_info_to_trip_offers_view.sql`
5. Cliquez sur **Run** pour exécuter la migration

### Option 2 : Via Supabase CLI

```bash
# Assurez-vous que Supabase CLI est installé
npm install -g supabase

# Liez votre projet (si pas déjà fait)
supabase link --project-ref votre-project-ref

# Appliquez toutes les migrations en attente
supabase db push
```

### Option 3 : Via psql directement

Si vous avez accès direct à la base de données :

```bash
psql "votre-connection-string" -f supabase/migrations/20251216_add_rider_info_to_trip_offers_view.sql
```

## Vérification

Après avoir appliqué la migration, vous pouvez vérifier que la vue contient bien les nouvelles colonnes :

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trip_offers_with_driver'
ORDER BY ordinal_position;
```

Vous devriez voir les colonnes suivantes (parmi d'autres) :
- `rider_name` (text)
- `rider_phone` (text)
- `departure_address` (text)
- `destination_address` (text)
- `distance_km` (double precision)

## Test

Après l'application de la migration :

1. Créez une nouvelle course en tant que passager (mobile_rider)
2. Faites une offre en tant que chauffeur (mobile_driver)
3. Ouvrez l'écran de négociation
4. Vérifiez que les informations suivantes s'affichent correctement :
   - Nom du passager
   - Numéro de téléphone du passager (icône téléphone)
   - Adresse de départ (avec icône orange)
   - Adresse de destination (avec icône rouge)
   - Distance en km

## Logs de débogage

Des logs ont été ajoutés pour faciliter le débogage :

```dart
print('[DEBUG NEGO] riderName: $riderName');
print('[DEBUG NEGO] departureAddress: $departureAddress');
print('[DEBUG NEGO] destinationAddress: $destinationAddress');
```

Ces logs apparaîtront dans la console lors de l'affichage de l'écran de négociation et permettent de vérifier que les données sont bien récupérées.

## Notes importantes

- Cette migration est **compatible** avec les données existantes
- Elle n'affecte **pas** les données, seulement la vue (SELECT)
- Les anciens clients qui utilisent l'ancienne structure continueront de fonctionner (grâce aux fallbacks `?? 'Client'`, etc.)
- Les logs de debug peuvent être retirés une fois que tout fonctionne correctement

## Rollback (si nécessaire)

Si vous devez annuler la migration, exécutez :

```sql
-- Restaurer l'ancienne version de la vue
CREATE OR REPLACE VIEW trip_offers_with_driver AS
SELECT 
  tof.id,
  tof.trip_id,
  tof.driver_id,
  tof.offered_price,
  tof.counter_price,
  tof.driver_counter_price,
  tof.final_price,
  tof.eta_minutes,
  t.vehicle_type,
  tof.status,
  tof.token_spent,
  tof.created_at,
  u.full_name as driver_name,
  u.phone as driver_phone,
  dp.rating_average as driver_rating,
  dp.total_trips as driver_total_trips,
  dp.vehicle_plate as driver_vehicle_plate,
  dp.current_lat as driver_lat_at_offer,
  dp.current_lng as driver_lng_at_offer,
  t.departure as departure_address,
  t.destination as destination_address,
  t.departure_lat,
  t.departure_lng,
  t.destination_lat,
  t.destination_lng
FROM trip_offers tof
JOIN users u ON tof.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
JOIN trips t ON tof.trip_id = t.id;
```

---

## Migration 2 : Ajout du champ driver_arrived_notification

### Problème résolu
Permettre au chauffeur de notifier manuellement le passager de son arrivée avec une notification écrite et sonore ("ding ding").

### Cause
Aucun mécanisme n'existait pour que le chauffeur puisse envoyer une notification manuelle au passager en dehors du changement de statut.

### Solution
Ajout d'un champ `driver_arrived_notification` dans la table `trips` pour tracer les notifications d'arrivée.

### Fichier de migration
**Fichier:** `supabase/migrations/20251216_add_driver_arrived_notification.sql`

```sql
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS driver_arrived_notification TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN trips.driver_arrived_notification IS 
'Timestamp de la dernière notification manuelle envoyée par le chauffeur';
```

### Comment appliquer

Utilisez la même méthode que pour la Migration 1 (Option 1, 2 ou 3).

Si vous utilisez l'interface Supabase :
1. Allez dans **SQL Editor**
2. Copiez-collez le contenu de `supabase/migrations/20251216_add_driver_arrived_notification.sql`
3. Cliquez sur **Run**

### Vérification

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trips' AND column_name = 'driver_arrived_notification';
```

Vous devriez voir :
- `driver_arrived_notification` (timestamp with time zone)

### Test

1. Créez une course et acceptez une offre
2. Dans l'écran de tracking du chauffeur, cliquez sur "Je suis arrivé"
3. Le passager doit :
   - Entendre deux "ding" (intervalle 300ms)
   - Voir un dialogue : "Votre chauffeur est arrivé !"
   - Le nom du chauffeur apparaît dans le message

### Notes importantes

- Cette migration ajoute une colonne nullable (pas de valeur par défaut requise)
- Compatible avec les données existantes
- Aucun impact sur les courses en cours

---

## Ordre d'application des migrations

Il est recommandé d'appliquer les migrations dans l'ordre suivant :

1. **Migration 1** : `20251216_add_rider_info_to_trip_offers_view.sql`
2. **Migration 2** : `20251216_add_driver_arrived_notification.sql`

Vous pouvez aussi les exécuter ensemble dans une seule session SQL :

```sql
-- Migration 1
CREATE OR REPLACE VIEW trip_offers_with_driver AS
SELECT 
  -- [contenu complet de la migration 1]
  ...
;

-- Migration 2
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS driver_arrived_notification TIMESTAMP WITH TIME ZONE;
```

## Support

Pour plus de détails sur l'implémentation complète des notifications, consultez :
- [IMPLEMENTATION_NOTIFICATIONS_ARRIVEE.md](IMPLEMENTATION_NOTIFICATIONS_ARRIVEE.md)
