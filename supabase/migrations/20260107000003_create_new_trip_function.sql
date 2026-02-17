-- Migration: Fonction create_new_trip avec support booking_type et scheduled_time
-- Cette fonction crée un nouveau trip avec tous les paramètres nécessaires
-- Elle est appelée via RPC depuis les applications mobiles

CREATE OR REPLACE FUNCTION create_new_trip(
  p_departure text,
  p_departure_lat numeric,
  p_departure_lng numeric,
  p_destination text,
  p_destination_lat numeric,
  p_destination_lng numeric,
  p_vehicle_type vehicle_type,
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
  -- Récupérer l'ID de l'utilisateur authentifié
  v_rider_id := auth.uid();
  
  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Vérifier que pour une course réservée, scheduled_time est fourni et dans le futur
  IF p_booking_type = 'scheduled' THEN
    IF p_scheduled_time IS NULL THEN
      RAISE EXCEPTION 'scheduled_time is required for scheduled bookings';
    END IF;
    
    IF p_scheduled_time <= now() THEN
      RAISE EXCEPTION 'scheduled_time must be in the future';
    END IF;
  END IF;

  -- Insérer le nouveau trip
  INSERT INTO trips (
    rider_id,
    departure,
    departure_lat,
    departure_lng,
    destination,
    destination_lat,
    destination_lng,
    vehicle_type,
    distance_km,
    status,
    booking_type,
    scheduled_time
  )
  VALUES (
    v_rider_id,
    p_departure,
    p_departure_lat,
    p_departure_lng,
    p_destination,
    p_destination_lat,
    p_destination_lng,
    p_vehicle_type,
    p_distance_km,
    'pending',
    p_booking_type,
    p_scheduled_time
  )
  RETURNING id INTO v_trip_id;

  -- Construire le résultat JSON
  SELECT jsonb_build_object(
    'id', t.id,
    'rider_id', t.rider_id,
    'departure', t.departure,
    'departure_lat', t.departure_lat,
    'departure_lng', t.departure_lng,
    'destination', t.destination,
    'destination_lat', t.destination_lat,
    'destination_lng', t.destination_lng,
    'vehicle_type', t.vehicle_type,
    'distance_km', t.distance_km,
    'status', t.status,
    'booking_type', t.booking_type,
    'scheduled_time', t.scheduled_time,
    'created_at', t.created_at
  )
  INTO v_result
  FROM trips t
  WHERE t.id = v_trip_id;

  RETURN v_result;
END;
$$;

-- Commentaire de la fonction
COMMENT ON FUNCTION create_new_trip IS 
'Crée un nouveau trip avec support pour les réservations immédiates et planifiées. 
Appelée via RPC depuis les applications mobiles.';

-- Permissions
GRANT EXECUTE ON FUNCTION create_new_trip TO authenticated;
