-- Modification de la vue trip_offers_with_driver pour inclure les informations du rider (passager)
-- Cette modification ajoute les informations du rider pour que les chauffeurs puissent voir
-- le nom, téléphone et rating du passager dans l'écran de négociation
-- IMPORTANT: Cette vue est utilisée dans le système de négociation - toutes les colonnes doivent être précises
--
-- WORKFLOW DE NÉGOCIATION BIDIRECTIONNELLE:
-- 1. Driver propose un prix initial (offered_price)
-- 2. Rider peut accepter OU faire une contre-offre (counter_price)
-- 3. Driver peut accepter la contre-offre du rider OU faire sa propre contre-offre (driver_counter_price)
-- 4. Négociation continue jusqu'à accord mutuel (final_price)
--
-- EXEMPLE:
-- Driver: 5000 → Rider: 4000 → Driver: 4500 → Accepté: 4500

DROP VIEW IF EXISTS trip_offers_with_driver;
CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- ============================================
  -- COLONNES DE TRIP_OFFERS (Système de négociation)
  -- ============================================
  tof.id AS offer_id,
  tof.trip_id,
  tof.driver_id,
  
  -- Prix de négociation
  tof.offered_price,        -- Prix proposé par le driver
  tof.counter_price,        -- Contre-offre du rider (nullable)
  tof.driver_counter_price, -- Contre-offre du driver en réponse au rider (nullable)
  tof.final_price,          -- Prix final accepté (nullable)
  
  -- Informations temporelles et logistiques
  tof.eta_minutes,          -- Temps estimé d'arrivée du driver
  tof.vehicle_type,         -- Type de véhicule de cette offre
  tof.status,               -- pending/selected/accepted/not_selected/rejected
  tof.token_spent,          -- Boolean: jeton dépensé ou non
  tof.created_at AS offer_created_at,
  
  -- ============================================
  -- INFORMATIONS DU CHAUFFF CFA (Driver)
  -- ============================================
  u.id AS driver_user_id,
  u.full_name AS driver_name,
  u.phone AS driver_phone,
  u.email AS driver_email,
  u.profile_photo_url AS driver_photo_url,
  
  -- Profil et statistiques du chauffeur
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
  
  -- ============================================
  -- INFORMATIONS DU TRAJET (Trip)
  -- ============================================
  t.status AS trip_status,
  t.rider_id,
  t.vehicle_type AS requested_vehicle_type,
  
  -- Départ
  t.departure AS departure_address,
  t.departure_lat,
  t.departure_lng,
  
  -- Destination
  t.destination AS destination_address,
  t.destination_lat,
  t.destination_lng,
  
  -- Détails du trajet
  t.distance_km,
  t.proposed_price AS trip_proposed_price,
  t.final_price AS trip_final_price,
  t.payment_method,
  t.created_at AS trip_created_at,
  t.accepted_at AS trip_accepted_at,
  t.started_at AS trip_started_at,
  t.completed_at AS trip_completed_at,
  
  -- ============================================
  -- INFORMATIONS DU PASSAGER (Rider) - NOUVEAU
  -- ============================================
  rider.id AS rider_user_id,
  rider.full_name AS rider_name,
  rider.phone AS rider_phone,
  rider.email AS rider_email,
  rider.profile_photo_url AS rider_photo_url
  
FROM trip_offers tof
-- Jointure driver
JOIN users u ON tof.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
-- Jointure trip
JOIN trips t ON tof.trip_id = t.id
-- Jointure rider (NOUVEAU)
JOIN users rider ON t.rider_id = rider.id;

-- ============================================
-- DOCUMENTATION
-- ============================================
COMMENT ON VIEW trip_offers_with_driver IS 
'Vue complète pour le système de négociation: inclut toutes les infos des offres, chauffeurs, trajets et passagers. Utilisée dans les écrans de négociation driver et rider.';
