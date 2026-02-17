/*
  # Mise à jour des types de véhicules
  
  Remplace les types de véhicules africains par des types internationaux standard:
  - moto: Moto/Scooter (2 roues motorisé)
  - car_economy: Voiture économique (compacte, petit budget)
  - car_standard: Voiture standard (berline classique)
  - car_premium: Voiture premium (confort supérieur)
  - suv: SUV (grand véhicule, plus d'espace)
  - minibus: Minibus 6-8 places (transport groupé)
*/

-- Étape 1: Supprimer les vues qui dépendent de vehicle_type
DROP VIEW IF EXISTS trip_offers_with_driver CASCADE;

-- Étape 2: Créer le nouveau type ENUM
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_type_new') THEN
    CREATE TYPE vehicle_type_new AS ENUM ('moto', 'car_economy', 'car_standard', 'car_premium', 'suv', 'minibus');
  END IF;
END $$;

-- Étape 3: Modifier les colonnes pour utiliser le nouveau type
-- (en convertissant temporairement en TEXT puis vers le nouveau type)

-- Table: driver_profiles
ALTER TABLE driver_profiles 
  ALTER COLUMN vehicle_type TYPE vehicle_type_new 
  USING CASE 
    WHEN vehicle_type::text = 'moto-taxi' THEN 'moto'::vehicle_type_new
    WHEN vehicle_type::text = 'tricycle' THEN 'car_economy'::vehicle_type_new
    WHEN vehicle_type::text = 'taxi' THEN 'car_standard'::vehicle_type_new
    ELSE 'car_standard'::vehicle_type_new
  END;

-- Table: trips
ALTER TABLE trips 
  ALTER COLUMN vehicle_type TYPE vehicle_type_new 
  USING CASE 
    WHEN vehicle_type::text = 'moto-taxi' THEN 'moto'::vehicle_type_new
    WHEN vehicle_type::text = 'tricycle' THEN 'car_economy'::vehicle_type_new
    WHEN vehicle_type::text = 'taxi' THEN 'car_standard'::vehicle_type_new
    ELSE 'car_standard'::vehicle_type_new
  END;

-- Table: trip_offers
ALTER TABLE trip_offers 
  ALTER COLUMN vehicle_type TYPE vehicle_type_new 
  USING CASE 
    WHEN vehicle_type::text = 'moto-taxi' THEN 'moto'::vehicle_type_new
    WHEN vehicle_type::text = 'tricycle' THEN 'car_economy'::vehicle_type_new
    WHEN vehicle_type::text = 'taxi' THEN 'car_standard'::vehicle_type_new
    ELSE 'car_standard'::vehicle_type_new
  END;

-- Table: delivery_offers (nullable)
ALTER TABLE delivery_offers 
  ALTER COLUMN vehicle_type TYPE vehicle_type_new 
  USING CASE 
    WHEN vehicle_type::text = 'moto-taxi' THEN 'moto'::vehicle_type_new
    WHEN vehicle_type::text = 'tricycle' THEN 'car_economy'::vehicle_type_new
    WHEN vehicle_type::text = 'taxi' THEN 'car_standard'::vehicle_type_new
    WHEN vehicle_type IS NULL THEN NULL
    ELSE 'car_standard'::vehicle_type_new
  END;

-- Étape 3: Supprimer l'ancien type et renommer le nouveau
DROP TYPE IF EXISTS vehicle_type CASCADE;
ALTER TYPE vehicle_type_new RENAME TO vehicle_type;

-- Étape 4: Recréer les vues qui dépendent de vehicle_type
-- Vue: trip_offers_with_driver
DROP VIEW IF EXISTS trip_offers_with_driver;
CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- COLONNES DE TRIP_OFFERS
  tof.id AS offer_id,
  tof.trip_id,
  tof.driver_id,
  
  -- Prix de négociation
  tof.offered_price,
  tof.counter_price,
  tof.driver_counter_price,
  tof.final_price,
  
  -- Informations temporelles et logistiques
  tof.eta_minutes,
  tof.vehicle_type,
  tof.status,
  tof.token_spent,
  tof.created_at AS offer_created_at,
  
  -- INFORMATIONS DU CHAUFFEUR
  u.id AS driver_user_id,
  u.full_name AS driver_name,
  u.phone AS driver_phone,
  u.email AS driver_email,
  u.profile_photo_url AS driver_photo_url,
  
  dp.rating_average AS driver_rating,
  dp.total_trips AS driver_total_trips,
  dp.total_deliveries AS driver_total_deliveries,
  dp.vehicle_plate AS driver_vehicle_plate,
  dp.vehicle_brand AS driver_vehicle_brand,
  dp.vehicle_model AS driver_vehicle_model,
  dp.vehicle_year AS driver_vehicle_year,
  dp.is_available AS driver_is_available,
  dp.current_lat AS driver_current_lat,
  dp.current_lng AS driver_current_lng,
  dp.last_location_update AS driver_last_location_update,
  
  -- INFORMATIONS DU TRAJET
  t.status AS trip_status,
  t.rider_id,
  t.vehicle_type AS requested_vehicle_type,
  
  t.departure AS departure_address,
  t.departure_lat,
  t.departure_lng,
  
  t.destination AS destination_address,
  t.destination_lat,
  t.destination_lng,
  
  t.distance_km,
  t.proposed_price AS trip_proposed_price,
  t.final_price AS trip_final_price,
  t.payment_method,
  t.created_at AS trip_created_at,
  t.accepted_at AS trip_accepted_at,
  t.started_at AS trip_started_at,
  t.completed_at AS trip_completed_at,
  
  -- INFORMATIONS DU PASSAGER
  rider.id AS rider_user_id,
  rider.full_name AS rider_name,
  rider.phone AS rider_phone,
  rider.email AS rider_email,
  rider.profile_photo_url AS rider_photo_url
  
FROM trip_offers tof
JOIN users u ON tof.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
JOIN trips t ON tof.trip_id = t.id
JOIN users rider ON t.rider_id = rider.id;

COMMENT ON VIEW trip_offers_with_driver IS 
'Vue complète pour le système de négociation avec types de véhicules internationaux';
