-- ========================================
-- FIX FINAL: Simplifier RLS pour Realtime
-- ========================================
-- Problème identifié (d'après diagnostic):
-- 1. Doublon de policies SELECT pour drivers (#1 et #2)
-- 2. Policies rider avec subquery EXISTS complexe qui bloque Realtime (#3 SELECT et #5 UPDATE)
-- 3. Realtime ne peut pas évaluer EXISTS() pour notifier les événements

-- Policies actuelles:
-- SELECT: "Drivers can receive realtime updates for their offers" (simple) ✅
-- SELECT: "Drivers can view own trip offers" (simple, DOUBLON) ❌
-- SELECT: "Riders can view offers for their trips" (EXISTS subquery) ❌
-- UPDATE: "Drivers can update own trip offers" (simple) ✅
-- UPDATE: "Riders can update offers for their trips" (EXISTS subquery) ❌
-- INSERT: "Drivers can create trip offers if tokens available" ✅

-- ========================================
-- ÉTAPE 1: Supprimer les policies en doublon et complexes
-- ========================================

-- Supprimer TOUTES les policies SELECT
DROP POLICY IF EXISTS "Drivers can receive realtime updates for their offers" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can view own trip offers" ON trip_offers;
DROP POLICY IF EXISTS "Riders can view offers for their trips" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can view their own offers" ON trip_offers;
DROP POLICY IF EXISTS "Riders can view offers for their trip" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can view their own offers for realtime" ON trip_offers;

-- Supprimer les policies UPDATE avec subqueries
DROP POLICY IF EXISTS "Riders can update offers for their trips" ON trip_offers;

-- ========================================
-- ÉTAPE 2: Créer UNE SEULE policy SELECT simple pour drivers
-- ========================================

CREATE POLICY "Drivers can view their offers"
ON trip_offers FOR SELECT
USING (auth.uid() = driver_id);

-- ========================================
-- ÉTAPE 3: Ajouter rider_id à trip_offers pour simplifier les policies
-- ========================================

-- Vérifier si rider_id existe déjà
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public'
    AND table_name = 'trip_offers' 
    AND column_name = 'rider_id'
  ) THEN
    -- Ajouter la colonne rider_id
    ALTER TABLE trip_offers ADD COLUMN rider_id UUID REFERENCES auth.users(id);
    
    -- Remplir rider_id depuis trips
    UPDATE trip_offers
    SET rider_id = trips.rider_id
    FROM trips
    WHERE trip_offers.trip_id = trips.id;
    
    -- Créer un trigger pour maintenir rider_id à jour
    CREATE OR REPLACE FUNCTION sync_trip_offers_rider_id()
    RETURNS TRIGGER AS $trigger$
    BEGIN
      -- Lors de l'insertion d'une offre, copier rider_id depuis trips
      IF TG_OP = 'INSERT' THEN
        NEW.rider_id := (SELECT rider_id FROM trips WHERE id = NEW.trip_id);
      END IF;
      RETURN NEW;
    END;
    $trigger$ LANGUAGE plpgsql;
    
    DROP TRIGGER IF EXISTS sync_rider_id_trigger ON trip_offers;
    CREATE TRIGGER sync_rider_id_trigger
    BEFORE INSERT ON trip_offers
    FOR EACH ROW
    EXECUTE FUNCTION sync_trip_offers_rider_id();
    
    RAISE NOTICE '✅ Colonne rider_id ajoutée et trigger créé';
  ELSE
    RAISE NOTICE '✅ Colonne rider_id existe déjà';
  END IF;
END $$;

-- ========================================
-- ÉTAPE 4: Créer policy SELECT simple pour riders
-- ========================================

CREATE POLICY "Riders can view offers"
ON trip_offers FOR SELECT
USING (auth.uid() = rider_id);

-- ========================================
-- ÉTAPE 5: Créer policy UPDATE simple pour riders
-- ========================================

CREATE POLICY "Riders can update offers"
ON trip_offers FOR UPDATE
USING (auth.uid() = rider_id)
WITH CHECK (auth.uid() = rider_id);

-- ========================================
-- ÉTAPE 6: Vérification finale
-- ========================================

-- Lister toutes les policies après modification
SELECT 
  polname AS policy_name,
  CASE polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
  END AS command_type,
  pg_get_expr(polqual, polrelid) AS using_expression
FROM pg_policy
WHERE polrelid = 'trip_offers'::regclass
ORDER BY polcmd, polname;

-- Vérifier que rider_id est bien rempli
SELECT 
  COUNT(*) as total_offers,
  COUNT(rider_id) as offers_with_rider_id,
  COUNT(*) - COUNT(rider_id) as missing_rider_id
FROM trip_offers;
