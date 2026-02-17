# 🔍 Diagnostic - Position du chauffeur dans Rider Tracking

## ✅ Modifications effectuées

### 1. **Logs de débogage ajoutés**

**Côté Driver (mobile_driver)** :
- `tracking_service.dart` : Logs lors de l'envoi de la position à Supabase
- Affiche les coordonnées envoyées et confirme l'envoi

**Côté Rider (mobile_rider)** :
- `rider_tracking_screen.dart` : Logs détaillés du stream Supabase
- Affiche quand le stream reçoit des mises à jour
- Affiche les coordonnées reçues et l'état de `_driverPosition`

### 2. **Stream optimisé**
- Utilise maintenant `.eq('id', driverId)` pour filtrer directement au niveau du stream
- Logs plus détaillés pour identifier les problèmes

## 🧪 Comment tester

### Étape 1 : Lancer l'app Driver
```bash
cd mobile_driver
flutter run
```

1. Accepter une course
2. Activer le mode test (bouton 🐛 en haut à droite)
3. Cliquer sur "Allez vers le point de départ"
4. **Observer les logs dans la console** :
   ```
   [TrackingService] Updating driver location: Lat=..., Lng=...
   [TrackingService] Location updated successfully in database
   ```

### Étape 2 : Lancer l'app Rider
```bash
cd mobile_rider
flutter run
```

1. Ouvrir l'écran de tracking
2. **Observer les logs dans la console** :
   ```
   [RIDER_TRACKING] Setting up driver location stream for: [driver_id]
   [RIDER_TRACKING] Stream received profiles: 1 items
   [RIDER_TRACKING] Driver profile update - Lat: ..., Lng: ...
   [RIDER_TRACKING] Driver location listener triggered
   [RIDER_TRACKING] Updating _driverPosition to: ...
   ```

## ⚠️ Problèmes possibles

### Problème 1 : Le stream ne reçoit pas de mises à jour
**Symptôme** : Seul le log initial apparaît, pas de "Driver location listener triggered"

**Cause** : Supabase Realtime n'est pas activé sur la table `driver_profiles`

**Solution** :
1. Aller dans Supabase Dashboard
2. Table Editor → `driver_profiles`
3. Onglet "Realtime" (ou Settings)
4. Activer "Enable Realtime" pour cette table
5. Sauvegarder

### Problème 2 : Les logs montrent `current_lat: null`
**Symptôme** : Le stream reçoit des données mais `current_lat` est null

**Cause** : Les colonnes ne sont pas créées ou mal nommées

**Solution** :
Vérifier que la table `driver_profiles` contient bien :
- `current_lat` (type: `float8` ou `double precision`)
- `current_lng` (type: `float8` ou `double precision`)
- `location_updated_at` (type: `timestamp with time zone`)

### Problème 3 : "Driver profile not found"
**Symptôme** : Erreur dans les logs du stream

**Cause** : L'ID du driver ne correspond pas

**Solution** :
Vérifier dans les logs :
```
[RIDER_TRACKING] Extracted driverId: [id]
```
Puis vérifier dans Supabase que ce `driver_id` existe dans `driver_profiles`

### Problème 4 : Position initiale correcte mais pas de mise à jour
**Symptôme** : Le marqueur apparaît à la bonne position initiale mais ne bouge pas

**Cause** : Le listener ne se déclenche pas ou Realtime désactivé

**Solution** :
1. Vérifier que Realtime est activé (voir Problème 1)
2. Vérifier que les Row Level Security (RLS) policies permettent la lecture :
   ```sql
   -- Politique pour permettre aux riders de lire les positions
   CREATE POLICY "Riders can view driver locations"
   ON driver_profiles
   FOR SELECT
   TO authenticated
   USING (true);
   ```

## 🔧 Requête SQL de diagnostic

Exécuter dans Supabase SQL Editor pour vérifier les données :

```sql
-- Voir les dernières positions des drivers
SELECT 
  id,
  full_name,
  current_lat,
  current_lng,
  location_updated_at,
  (EXTRACT(EPOCH FROM (NOW() - location_updated_at))) as seconds_since_update
FROM driver_profiles
WHERE current_lat IS NOT NULL
ORDER BY location_updated_at DESC
LIMIT 10;
```

Si `seconds_since_update` est > 10, le driver ne met pas à jour sa position.

## 📊 Vérification Realtime

Dans Supabase Dashboard :
1. Project Settings → API
2. Section "Realtime"
3. Vérifier que le statut est "Enabled"
4. Vérifier que `driver_profiles` est dans la liste des tables Realtime

## ✅ Solution finale

Une fois Realtime activé, le flux devrait être :

**Driver** (toutes les 2 secondes en mode test, tous les 10m en mode réel) :
```
Position GPS → updateDriverLocation() → Supabase driver_profiles
```

**Rider** (en temps réel via Realtime) :
```
Supabase Realtime → driverLocationStreamProvider → Listener → setState(_driverPosition) → Marqueur mis à jour sur la carte
```

## 🎯 Résultat attendu

Avec les logs activés, vous devriez voir :
- **Driver** : Logs toutes les 2 secondes montrant l'envoi de position
- **Rider** : Logs toutes les 2 secondes montrant la réception et la mise à jour
- **Carte** : Le marqueur bleu du driver se déplace en temps réel vers le point de départ

---

**Note** : Si après activation de Realtime le problème persiste, redémarrer les deux apps Flutter pour rafraîchir les connexions Supabase.
