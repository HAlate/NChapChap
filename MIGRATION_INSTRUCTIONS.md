# Instructions de Migration - Ajout du type 'any' pour les véhicules

## ⚠️ Problème

PostgreSQL ne permet pas d'utiliser une nouvelle valeur d'ENUM dans la même transaction où elle a été ajoutée. La migration doit donc être effectuée en **2 étapes séparées**.

---

## 📋 Procédure de Migration

### Option 1: Via Supabase SQL Editor (RECOMMANDÉ)

#### Étape 1: Ajouter 'any' à l'ENUM

1. Ouvrir **Supabase Dashboard** → **SQL Editor**
2. Copier-coller le contenu de **`add_any_vehicle_type_step1.sql`**
3. Cliquer sur **RUN**
4. ✅ Vérifier que le message de succès apparaît
5. ⏸️ **Attendre 5 secondes**

#### Étape 2: Mettre à jour la fonction

1. Dans le même **SQL Editor** (ou ouvrir un nouvel onglet)
2. Copier-coller le contenu de **`add_any_vehicle_type_step2.sql`**
3. Cliquer sur **RUN**
4. ✅ Vérifier que le message de succès apparaît

---

### Option 2: Via psql (ligne de commande)

```bash
# Étape 1
psql -U postgres -d your_database -f add_any_vehicle_type_step1.sql

# ⏸️ Attendre 5 secondes

# Étape 2
psql -U postgres -d your_database -f add_any_vehicle_type_step2.sql
```

---

### Option 3: Commandes séparées (SQL Editor)

#### Étape 1

```sql
ALTER TYPE vehicle_type ADD VALUE IF NOT EXISTS 'any';
```

**Exécuter** → **Fermer la transaction** → **Attendre 5 secondes**

#### Étape 2

```sql
CREATE OR REPLACE FUNCTION create_new_trip(
  p_departure text,
  p_departure_lat numeric,
  p_departure_lng numeric,
  p_destination text,
  p_destination_lat numeric,
  p_destination_lng numeric,
  p_vehicle_type vehicle_type DEFAULT 'any',
  p_distance_km numeric DEFAULT NULL,
  p_booking_type booking_type DEFAULT 'immediate',
  p_scheduled_time timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip_id uuid;
  v_rider_id uuid;
  v_result jsonb;
BEGIN
  v_rider_id := auth.uid();

  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  IF p_booking_type = 'scheduled' THEN
    IF p_scheduled_time IS NULL THEN
      RAISE EXCEPTION 'scheduled_time is required for scheduled bookings';
    END IF;

    IF p_scheduled_time <= now() THEN
      RAISE EXCEPTION 'scheduled_time must be in the future';
    END IF;
  END IF;

  INSERT INTO trips (
    rider_id, departure, departure_lat, departure_lng,
    destination, destination_lat, destination_lng,
    vehicle_type, distance_km, status, booking_type, scheduled_time
  )
  VALUES (
    v_rider_id, p_departure, p_departure_lat, p_departure_lng,
    p_destination, p_destination_lat, p_destination_lng,
    p_vehicle_type, p_distance_km, 'pending', p_booking_type, p_scheduled_time
  )
  RETURNING id INTO v_trip_id;

  SELECT jsonb_build_object(
    'id', t.id, 'rider_id', t.rider_id,
    'departure', t.departure, 'departure_lat', t.departure_lat, 'departure_lng', t.departure_lng,
    'destination', t.destination, 'destination_lat', t.destination_lat, 'destination_lng', t.destination_lng,
    'vehicle_type', t.vehicle_type, 'distance_km', t.distance_km,
    'status', t.status, 'booking_type', t.booking_type,
    'scheduled_time', t.scheduled_time, 'created_at', t.created_at
  )
  INTO v_result
  FROM trips t
  WHERE t.id = v_trip_id;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION create_new_trip IS
'Crée un nouveau trip avec support pour les réservations immédiates et planifiées.
Le vehicle_type peut être "any" pour accepter tous les types de véhicules.';

GRANT EXECUTE ON FUNCTION create_new_trip TO authenticated;
```

---

## ✅ Vérifications

Après avoir exécuté les 2 étapes, vérifier que tout fonctionne :

```sql
-- 1. Vérifier que 'any' existe dans l'ENUM
SELECT enumlabel
FROM pg_enum
WHERE enumtypid = 'vehicle_type'::regtype
ORDER BY enumsortorder;

-- Résultat attendu:
-- moto
-- car_economy
-- car_standard
-- car_premium
-- suv
-- minibus
-- any

-- 2. Vérifier la signature de la fonction
SELECT pg_get_function_arguments(oid)
FROM pg_proc
WHERE proname = 'create_new_trip';

-- Résultat attendu: doit contenir "p_vehicle_type vehicle_type DEFAULT 'any'::vehicle_type"

-- 3. Tester la fonction
SELECT create_new_trip(
  p_departure := 'Test Départ',
  p_departure_lat := 6.1256,
  p_departure_lng := 1.2228,
  p_destination := 'Test Destination',
  p_destination_lat := 6.1356,
  p_destination_lng := 1.2328
  -- vehicle_type utilise la valeur par défaut 'any'
);
```

---

## 🔧 En cas de problème

### Erreur: "unsafe use of new value"

➡️ Vous essayez d'utiliser 'any' dans la même transaction
➡️ **Solution**: Fermer la transaction, attendre 5 secondes, puis exécuter l'étape 2

### Erreur: "value already exists"

➡️ La valeur 'any' existe déjà
➡️ **Solution**: Passer directement à l'étape 2

### Erreur: "type vehicle_type does not exist"

➡️ Le type n'existe pas dans votre base
➡️ **Solution**: Vérifier que vous êtes sur la bonne base de données

---

## 📚 Fichiers de Migration

- `add_any_vehicle_type.sql` - Version complète avec commentaires
- `add_any_vehicle_type_step1.sql` - **ÉTAPE 1** uniquement
- `add_any_vehicle_type_step2.sql` - **ÉTAPE 2** uniquement

**Recommandation**: Utiliser les fichiers step1 et step2 pour une migration sans erreur.

---

## 🚀 Après la Migration

1. ✅ Tester l'application mobile_rider
2. ✅ Vérifier que les trips sont créés avec vehicle_type='any'
3. ✅ Confirmer que les drivers voient les nouveaux trips
4. ✅ Tester le filtre dans waiting_offers_screen

---

**Status**: ⏳ EN ATTENTE D'EXÉCUTION  
**Prérequis**: Accès admin à Supabase Dashboard  
**Durée**: ~2 minutes
