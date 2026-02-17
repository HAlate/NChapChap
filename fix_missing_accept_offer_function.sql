-- =========================================
-- FIX: Fonction manquante accept_offer_and_update_trip
-- =========================================
-- Erreur: "Could not find the function public.accept_offer_and_update_trip"
-- Cette fonction permet d'accepter une offre de manière atomique

-- =========================================
-- SOLUTION: Créer la fonction RPC
-- =========================================

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

  -- Note: Les jetons ne sont plus utilisés dans cette version
  -- La fonction ne déduit plus de jetons

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

  -- Log de succès
  RAISE NOTICE 'Offre % acceptée pour le trip % par le rider %', p_offer_id, p_trip_id, v_rider_id;
END;
$$;

-- Donner les permissions
GRANT EXECUTE ON FUNCTION accept_offer_and_update_trip(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION accept_offer_and_update_trip(uuid, uuid, integer) TO anon;

-- Commentaire
COMMENT ON FUNCTION accept_offer_and_update_trip IS
'Accepte une offre de trip de manière atomique. Met à jour trip_offers.status=accepted, trips.status=accepted et driver_id.';

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que la fonction existe
SELECT 
  'Fonction accept_offer_and_update_trip' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Fonction existe'
    ELSE '❌ Fonction manquante'
  END as status,
  COUNT(*) as count
FROM pg_proc 
WHERE proname = 'accept_offer_and_update_trip';

-- Test 2: Vérifier les paramètres de la fonction
SELECT 
  'Paramètres de la fonction' as check_name,
  proargnames as parameter_names,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'accept_offer_and_update_trip';

-- Test 3: Vérifier les permissions
SELECT 
  'Permissions sur la fonction' as check_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'accept_offer_and_update_trip';

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1. Exécuter ce script dans Supabase SQL Editor' as etape_1,
  '2. Vérifier que tous les checks sont verts ✅' as etape_2,
  '3. Redémarrer l''app mobile (hot restart)' as etape_3,
  '4. Réessayer d''accepter une offre' as etape_4;

-- =========================================
-- NOTES
-- =========================================
-- 
-- Cette fonction est appelée depuis:
-- - mobile_rider/lib/services/rider_offer_service.dart
-- - mobile_rider/lib/services/trip_service.dart
-- 
-- Elle effectue les opérations suivantes:
-- 1. Vérifie que l'offre et le trip existent
-- 2. Vérifie que l'appelant est bien le rider du trip
-- 3. Marque l'offre comme "accepted"
-- 4. Met à jour le trip avec le driver et le prix final
-- 5. Marque les autres offres comme "not_selected"
-- 
-- SÉCURITÉ:
-- - SECURITY DEFINER permet d'exécuter avec les droits du propriétaire
-- - Vérification que auth.uid() = rider_id du trip
-- - Permissions accordées à authenticated et anon
--
