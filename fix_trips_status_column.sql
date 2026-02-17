-- Script de correction pour ajouter la colonne status si elle n'existe pas

-- 1. Vérifier si l'enum trip_status existe, sinon le créer
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
        CREATE TYPE trip_status AS ENUM ('pending', 'accepted', 'started', 'completed', 'cancelled');
    END IF;
END $$;

-- 2. Ajouter la colonne status si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'trips' 
          AND column_name = 'status'
    ) THEN
        ALTER TABLE trips 
        ADD COLUMN status trip_status DEFAULT 'pending';
        
        -- Créer les index si nécessaire
        CREATE INDEX IF NOT EXISTS idx_trips_rider ON trips(rider_id, status);
        CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id, status);
        CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_trips_pending ON trips(status, vehicle_type) WHERE status = 'pending';
    END IF;
END $$;

-- 3. Vérifier que la fonction create_new_trip existe et la recréer si nécessaire
CREATE OR REPLACE FUNCTION public.create_new_trip(
    p_departure text,
    p_departure_lat double precision,
    p_departure_lng double precision,
    p_destination text,
    p_destination_lat double precision,
    p_destination_lng double precision,
    p_vehicle_type text,
    p_distance_km double precision
)
RETURNS trips
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_trip trips;
BEGIN
  INSERT INTO public.trips(
    rider_id, 
    departure, 
    departure_lat, 
    departure_lng, 
    destination, 
    destination_lat, 
    destination_lng, 
    vehicle_type, 
    distance_km, 
    status
  )
  VALUES (
    auth.uid(), 
    p_departure, 
    p_departure_lat, 
    p_departure_lng, 
    p_destination, 
    p_destination_lat, 
    p_destination_lng, 
    p_vehicle_type::vehicle_type, 
    p_distance_km, 
    'pending'
  )
  RETURNING * INTO new_trip;

  RETURN new_trip;
END;
$$;

-- 4. Donner les permissions
GRANT EXECUTE ON FUNCTION public.create_new_trip(text, double precision, double precision, text, double precision, double precision, text, double precision) TO authenticated;

-- 5. Vérification finale
SELECT 
    column_name, 
    data_type 
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trips' 
  AND column_name = 'status';
