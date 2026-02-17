-- ========================================
-- Mettre à jour la vue trip_offers_with_driver
-- ========================================
-- Ajouter les colonnes driver_lat_at_offer et driver_lng_at_offer

DROP VIEW IF EXISTS trip_offers_with_driver;
CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- COLONNES DE TRIP_OFFERS
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
  t.vehicle_type,  -- CORRECTION: vehicle_type vient de la table trips, pas trip_offers
  tof.status,
  tof.token_spent,
  tof.created_at,  -- Colonne created_at SANS alias pour le modèle TripOffer
  
  -- POSITION DU DRIVER AU MOMENT DE L'OFFRE
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
'Vue complète pour le système de négociation avec position du driver au moment de l''offre';

-- Donner les permissions
GRANT SELECT ON trip_offers_with_driver TO authenticated;
