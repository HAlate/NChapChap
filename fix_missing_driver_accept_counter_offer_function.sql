-- =========================================
-- FIX: Fonction manquante driver_accept_counter_offer
-- =========================================
-- Erreur: "Could not find the function public.driver_accept_counter_offer(p_final_price, p_offer_id, p_trip_id)"
-- Cette fonction permet au driver d'accepter la contre-offre du rider

-- =========================================
-- SOLUTION: Créer la fonction RPC
-- =========================================

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

  -- Note: Le jeton n'est PAS déduit ici
  -- Il sera déduit uniquement au démarrage de la course (trips.status = 'started')
  -- pour gérer les cas de No Show où le passager ne se présente pas

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

  -- Log de succès
  RAISE NOTICE 'Contre-offre acceptée: Driver % accepte la contre-offre de % F CFA du rider % pour le trip %', 
    v_driver_id, p_final_price, v_rider_id, p_trip_id;
END;
$$;

-- Donner les permissions
GRANT EXECUTE ON FUNCTION driver_accept_counter_offer(uuid, uuid, integer) TO authenticated;

-- Commentaire
COMMENT ON FUNCTION driver_accept_counter_offer IS
'Permet au chauffeur d''accepter la contre-offre du passager. Vérifie que l''appelant est bien le chauffeur de l''offre. Met à jour trip_offers.status=accepted, trips.status=accepted et driver_id. Le jeton sera déduit au démarrage de la course (trips.status=started).';

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que la fonction existe
SELECT 
  'Fonction driver_accept_counter_offer' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Fonction existe'
    ELSE '❌ Fonction manquante'
  END as status,
  COUNT(*) as count
FROM pg_proc 
WHERE proname = 'driver_accept_counter_offer';

-- Test 2: Vérifier les paramètres de la fonction
SELECT 
  'Paramètres de la fonction' as check_name,
  proargnames as parameter_names,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'driver_accept_counter_offer';

-- Test 3: Vérifier les permissions
SELECT 
  'Permissions sur la fonction' as check_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'driver_accept_counter_offer';

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1. Exécuter ce script dans Supabase SQL Editor' as etape_1,
  '2. Vérifier que tous les checks sont verts ✅' as etape_2,
  '3. Redémarrer l''app mobile (hot restart)' as etape_3,
  '4. Réessayer d''accepter la contre-offre' as etape_4;

-- =========================================
-- NOTES
-- =========================================
-- 
-- Cette fonction est appelée depuis:
-- - mobile_driver/lib/services/driver_offer_service.dart (ligne 537)
-- 
-- WORKFLOW de négociation:
-- 1. Driver fait une offre initiale
-- 2. Rider fait une contre-offre (counter_price)
-- 3. Driver accepte la contre-offre avec cette fonction
-- 4. Trip status passe à 'accepted', driver est assigné
-- 5. Les autres offres sont marquées 'not_selected'
-- 
-- SÉCURITÉ:
-- - SECURITY DEFINER permet d'exécuter avec les droits du propriétaire
-- - Vérification que auth.uid() = driver_id de l'offre
-- - Vérification qu'une contre-offre existe (counter_price IS NOT NULL)
-- - Permissions accordées à authenticated et anon
--
