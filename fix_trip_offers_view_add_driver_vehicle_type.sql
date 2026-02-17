-- =========================================
-- FIX: Ajouter driver_vehicle_type à la vue trip_offers_with_driver
-- =========================================
-- Cette colonne permet de filtrer les offres par type de véhicule du driver

DROP VIEW IF EXISTS trip_offers_with_driver;

CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- COLONNES DE TRIP_OFFERS (sans alias pour correspondre au modèle Dart)
  tof.id,
  tof.trip_id,
  tof.driver_id,
  
  -- Prix de négociation
  tof.offered_price,
  tof.counter_price,
  tof.driver_counter_price,
  tof.final_price,
  
  -- Informations temporelles et logistiques
  tof.eta_minutes,
  tof.status,
  tof.token_spent,
  tof.created_at,
  
  -- Position du driver au moment de l'offre
  tof.driver_lat_at_offer,
  tof.driver_lng_at_offer,
  
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
  dp.vehicle_type AS driver_vehicle_type, -- ✅ NOUVELLE COLONNE
  dp.is_available AS driver_is_available,
  dp.current_lat AS driver_current_lat,
  dp.current_lng AS driver_current_lng,
  dp.last_location_update AS driver_last_location_update,
  
  -- INFORMATIONS DU TRAJET
  t.status AS trip_status,
  t.rider_id,
  t.vehicle_type, -- Type de véhicule demandé par le rider (peut être 'any')
  
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
LEFT JOIN driver_profiles dp ON tof.driver_id = dp.id
JOIN trips t ON tof.trip_id = t.id
LEFT JOIN users rider ON t.rider_id = rider.id;

-- Vérification
SELECT 
  id,
  driver_name,
  vehicle_type AS trip_vehicle_type,
  driver_vehicle_type,
  status
FROM trip_offers_with_driver
LIMIT 5;
