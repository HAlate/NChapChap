-- ========================================
-- Fonction RPC: driver_accept_counter_offer
-- ========================================
-- Cette fonction permet au DRIVER d'accepter la contre-offre du RIDER
-- Elle met à jour trip_offers et trips dans une seule transaction

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
  -- 1. Récupérer le driver_id et rider_id de l'offre
  SELECT driver_id, rider_id INTO v_driver_id, v_rider_id
  FROM trip_offers
  WHERE id = p_offer_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Offre non trouvée';
  END IF;

  -- 2. Vérifier que le DRIVER est bien celui qui appelle (sécurité)
  IF v_driver_id != auth.uid() THEN
    RAISE EXCEPTION 'Non autorisé: Seul le chauffeur de cette offre peut l''accepter';
  END IF;

  -- 3. Vérifier que la contre-offre existe (counter_price doit être non null)
  IF NOT EXISTS (
    SELECT 1 FROM trip_offers 
    WHERE id = p_offer_id 
    AND counter_price IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Aucune contre-offre à accepter';
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
