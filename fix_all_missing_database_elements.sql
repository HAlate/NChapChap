-- =========================================
-- FIX COMPLET: Tous les éléments manquants dans la base de données
-- =========================================
-- Ce script crée TOUTES les colonnes et fonctions manquantes identifiées
-- Exécutez-le dans Supabase SQL Editor pour réparer la base de données

-- =========================================
-- 1. COLONNE: location_updated_at dans driver_profiles
-- =========================================
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_driver_profiles_location_updated_at 
ON driver_profiles(location_updated_at);

COMMENT ON COLUMN driver_profiles.location_updated_at IS 
'Horodatage de la dernière mise à jour de la position GPS du chauffeur. Utilisé pour le tracking en temps réel.';

-- =========================================
-- 2. COLONNE: driver_arrived_notification dans trips
-- =========================================
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS driver_arrived_notification TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN trips.driver_arrived_notification IS 
'Timestamp de la dernière notification manuelle envoyée par le chauffeur pour signaler son arrivée au passager';

-- =========================================
-- 3. FONCTION: accept_offer_and_update_trip
-- =========================================
DROP FUNCTION IF EXISTS accept_offer_and_update_trip(uuid, uuid, integer);

CREATE OR REPLACE FUNCTION accept_offer_and_update_trip(
  p_offer_id uuid,
  p_trip_id uuid,
  p_final_price integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_rider_id uuid;
BEGIN
  -- 1. Récupérer le driver_id de l'offre
  SELECT driver_id INTO v_driver_id
  FROM trip_offers
  WHERE id = p_offer_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Offre non trouvée';
  END IF;

  -- 2. Récupérer le rider_id du trip
  SELECT rider_id INTO v_rider_id
  FROM trips
  WHERE id = p_trip_id;

  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'Trip non trouvé';
  END IF;

  -- 3. Vérifier que le rider est bien celui qui appelle (sécurité)
  IF v_rider_id != auth.uid() THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;

  -- 4. Mettre à jour l'offre acceptée
  UPDATE trip_offers
  SET 
    status = 'accepted',
    final_price = p_final_price
  WHERE id = p_offer_id;

  -- 5. Mettre à jour le trip
  UPDATE trips
  SET 
    status = 'accepted',
    driver_id = v_driver_id,
    final_price = p_final_price,
    accepted_at = NOW()
  WHERE id = p_trip_id;

  -- 6. Marquer les autres offres comme non sélectionnées
  UPDATE trip_offers
  SET status = 'not_selected'
  WHERE trip_id = p_trip_id
    AND id != p_offer_id
    AND status = 'pending';

  RAISE NOTICE 'Offre % acceptée pour le trip % par le rider %', p_offer_id, p_trip_id, v_rider_id;
END;
$$;

GRANT EXECUTE ON FUNCTION accept_offer_and_update_trip(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION accept_offer_and_update_trip(uuid, uuid, integer) TO anon;

-- =========================================
-- 4. FONCTION: driver_accept_counter_offer
-- =========================================
DROP FUNCTION IF EXISTS driver_accept_counter_offer(uuid, uuid, integer);

CREATE OR REPLACE FUNCTION driver_accept_counter_offer(
  p_offer_id uuid,
  p_trip_id uuid,
  p_final_price integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_rider_id uuid;
BEGIN
  -- 1. Récupérer le driver_id de l'offre
  SELECT driver_id INTO v_driver_id
  FROM trip_offers
  WHERE id = p_offer_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Offre non trouvée';
  END IF;

  -- 2. Récupérer le rider_id depuis le trip
  SELECT rider_id INTO v_rider_id
  FROM trips
  WHERE id = p_trip_id;

  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'Trip non trouvé';
  END IF;

  -- 3. Vérifier que le DRIVER est bien celui qui appelle (sécurité)
  IF v_driver_id != auth.uid() THEN
    RAISE EXCEPTION 'Non autorisé: Seul le chauffeur de cette offre peut l''accepter';
  END IF;

  -- 4. Vérifier que la contre-offre existe (counter_price doit être non null)
  IF NOT EXISTS (
    SELECT 1 FROM trip_offers 
    WHERE id = p_offer_id 
    AND counter_price IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Aucune contre-offre à accepter';
  END IF;

  -- 5. Mettre à jour l'offre acceptée
  UPDATE trip_offers
  SET 
    status = 'accepted',
    final_price = p_final_price
  WHERE id = p_offer_id;

  -- 6. Mettre à jour le trip
  UPDATE trips
  SET 
    status = 'accepted',
    driver_id = v_driver_id,
    final_price = p_final_price,
    accepted_at = NOW()
  WHERE id = p_trip_id;

  -- 7. Marquer les autres offres comme non sélectionnées
  UPDATE trip_offers
  SET status = 'not_selected'
  WHERE trip_id = p_trip_id
    AND id != p_offer_id
    AND status IN ('pending', 'selected');

  RAISE NOTICE 'Contre-offre acceptée: Driver % accepte la contre-offre de % F CFA du rider % pour le trip %', 
    v_driver_id, p_final_price, v_rider_id, p_trip_id;
END;
$$;

GRANT EXECUTE ON FUNCTION driver_accept_counter_offer(uuid, uuid, integer) TO authenticated;

-- =========================================
-- 5. TABLE: debug_logs (pour le debugging des notifications)
-- =========================================
CREATE TABLE IF NOT EXISTS debug_logs (
    id BIGSERIAL PRIMARY KEY,
    function_name TEXT,
    param_name TEXT,
    param_value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour optimiser les requêtes de debug
CREATE INDEX IF NOT EXISTS idx_debug_logs_created_at ON debug_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_debug_logs_function_name ON debug_logs(function_name);

-- =========================================
-- 6. FONCTION: create_notification
-- =========================================
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT);
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_data JSONB DEFAULT NULL,
    p_read TEXT DEFAULT 'false'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_notification_id UUID;
    v_read_bool BOOLEAN;
BEGIN
    -- Logger ce que nous recevons
    INSERT INTO debug_logs (function_name, param_name, param_value)
    VALUES ('create_notification', 'p_read_input', p_read);
    
    -- Convertir TEXT en BOOLEAN
    v_read_bool := (p_read = 'true');
    
    -- Logger après conversion
    INSERT INTO debug_logs (function_name, param_name, param_value)
    VALUES ('create_notification', 'v_read_bool_after_conversion', v_read_bool::TEXT);
    
    INSERT INTO notifications (user_id, type, title, message, data, read, created_at)
    VALUES (p_user_id, p_type, p_title, p_message, p_data, v_read_bool, NOW())
    RETURNING id INTO v_notification_id;
    
    -- Logger après insertion
    INSERT INTO debug_logs (function_name, param_name, param_value)
    VALUES ('create_notification', 'inserted_with_read', v_read_bool::TEXT);
    
    RETURN v_notification_id;
END;
$$;

GRANT EXECUTE ON FUNCTION create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO anon;

-- =========================================
-- 7. POLICY RLS pour notifications INSERT
-- =========================================
DROP POLICY IF EXISTS "Anyone can create notifications" ON notifications;
DROP POLICY IF EXISTS "System can create notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON notifications;
DROP POLICY IF EXISTS "Allow all authenticated to insert notifications" ON notifications;

CREATE POLICY "Allow all authenticated to insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

-- =========================================
-- VÉRIFICATIONS COMPLÈTES
-- =========================================

-- Test 1: Vérifier les colonnes
SELECT 
  '✅ Colonnes' as check_category,
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'driver_profiles' AND column_name = 'location_updated_at')
    OR (table_name = 'trips' AND column_name = 'driver_arrived_notification')
  )
ORDER BY table_name, column_name;

-- Test 2: Vérifier les fonctions
SELECT 
  '✅ Fonctions' as check_category,
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname IN (
  'accept_offer_and_update_trip',
  'driver_accept_counter_offer',
  'create_notification'
)
ORDER BY proname;

-- Test 2.5: Vérifier la table debug_logs
SELECT 
  '✅ Tables' as check_category,
  table_name,
  (SELECT count(*) FROM debug_logs) as nombre_logs
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'debug_logs';

-- Test 3: Vérifier les permissions sur les fonctions
SELECT 
  '✅ Permissions' as check_category,
  routine_name as function_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name IN (
  'accept_offer_and_update_trip',
  'driver_accept_counter_offer',
  'create_notification'
)
ORDER BY routine_name, grantee;

-- Test 4: Vérifier les politiques RLS
SELECT 
  '✅ Politiques RLS' as check_category,
  tablename,
  policyname,
  cmd as command,
  CASE 
    WHEN with_check = 'true' THEN 'Permissif'
    ELSE 'Restrictif'
  END as policy_type
FROM pg_policies 
WHERE tablename = 'notifications'
  AND cmd = 'INSERT'
ORDER BY tablename, policyname;

-- =========================================
-- RÉSUMÉ
-- =========================================
SELECT 
  '=========================================' as separator,
  'RÉSUMÉ DES CORRECTIONS' as titre,
  '=========================================' as separator2
UNION ALL
SELECT 
  '✅ ' || count(*) || ' colonnes ajoutées',
  '  - location_updated_at (driver_profiles)',
  '  - driver_arrived_notification (trips)'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'driver_profiles' AND column_name = 'location_updated_at')
    OR (table_name = 'trips' AND column_name = 'driver_arrived_notification')
  )
UNION ALL
SELECT 
  '✅ ' || count(*) || ' fonctions créées',
  '  - accept_offer_and_update_trip',
  '  - driver_accept_counter_offer + create_notification'
FROM pg_proc 
WHERE proname IN (
  'accept_offer_and_update_trip',
  'driver_accept_counter_offer',
  'create_notification'
);

-- =========================================
-- INSTRUCTIONS FINALES
-- =========================================
SELECT 
  '1️⃣  Vérifiez que tous les checks ci-dessus sont ✅' as etape_1,
  '2️⃣  Redémarrez les apps mobile (hot restart)' as etape_2,
  '3️⃣  Testez le workflow complet: offre → acceptation → navigation' as etape_3,
  '4️⃣  Vérifiez que les notifications fonctionnent' as etape_4;
