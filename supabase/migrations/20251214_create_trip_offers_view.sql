-- Vue pour les offres de trajet avec les informations du chauffeur
-- Cette vue joint trip_offers avec users et driver_profiles pour obtenir toutes les infos nécessaires

DROP VIEW IF EXISTS trip_offers_with_driver;
CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- Colonnes de trip_offers
  tof.id,
  tof.trip_id,
  tof.driver_id,
  tof.offered_price,
  tof.counter_price,
  tof.final_price,
  tof.eta_minutes,
  t.vehicle_type,
  tof.status,
  tof.token_spent,
  tof.created_at,
  
  -- Informations du chauffeur depuis users
  u.full_name as driver_name,
  u.phone as driver_phone,
  
  -- Informations du profil chauffeur
  dp.rating_average as driver_rating,
  dp.total_trips as driver_total_trips,
  dp.vehicle_plate as driver_vehicle_plate,
  dp.current_lat as driver_lat_at_offer,
  dp.current_lng as driver_lng_at_offer,
  
  -- Informations du trajet
  t.departure as departure_address,
  t.destination as destination_address,
  t.departure_lat,
  t.departure_lng,
  t.destination_lat,
  t.destination_lng
  
FROM trip_offers tof
JOIN users u ON tof.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
JOIN trips t ON tof.trip_id = t.id;

-- Ajouter un commentaire pour la documentation
COMMENT ON VIEW trip_offers_with_driver IS 
'Vue enrichie des offres de trajet avec toutes les informations du chauffeur et du trajet';
