-- Créer une offre de test pour le dernier trip en attente
-- Remplacez les valeurs si nécessaire

WITH latest_trip AS (
  SELECT id 
  FROM trips 
  WHERE status = 'pending' 
  ORDER BY created_at DESC 
  LIMIT 1
),
latest_driver AS (
  SELECT id 
  FROM users 
  WHERE user_type = 'driver' 
  ORDER BY created_at DESC 
  LIMIT 1
)
INSERT INTO trip_offers (trip_id, driver_id, offered_price, eta_minutes, vehicle_type, status)
SELECT 
  latest_trip.id,
  latest_driver.id,
  15000,  -- Prix offert en FCFA
  10,     -- ETA en minutes
  'moto-taxi',
  'pending'
FROM latest_trip, latest_driver
RETURNING *;

-- Vérifier les offres créées
SELECT 
  tof.id,
  tof.trip_id,
  tof.offered_price,
  tof.status,
  u.full_name as driver_name
FROM trip_offers tof
LEFT JOIN users u ON u.id = tof.driver_id
ORDER BY tof.created_at DESC
LIMIT 5;
