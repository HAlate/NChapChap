-- ========================================
-- Fonction RPC: accept_offer_and_update_trip
-- ========================================
-- Cette fonction permet d'accepter une offre de manière atomique
-- Elle met à jour trip_offers et trips dans une seule transaction

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

  -- Note: Le jeton n'est PAS déduit ici
  -- Il sera déduit uniquement au démarrage de la course (trips.status = 'started')
  -- pour gérer les cas de No Show où le passager ne se présente pas

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

-- Commentaire
COMMENT ON FUNCTION accept_offer_and_update_trip IS
'Accepte une offre de trip de manière atomique. Met à jour trip_offers.status=accepted, trips.status=accepted et driver_id. Le jeton sera déduit uniquement au démarrage de la course (trips.status=started) pour gérer les No Show.';
