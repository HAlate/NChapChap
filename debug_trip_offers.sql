-- Debug: Vérifier les offres pour un trip spécifique
-- Remplacez 'VOTRE_TRIP_ID' par le Trip ID affiché dans l'app

-- Exemple: SELECT * FROM trip_offers WHERE trip_id = 'abc123...';

-- Liste des trip_id avec nombre d'offres
SELECT 
  t.id as trip_id,
  t.status,
  t.vehicle_type,
  u.full_name as rider_name,
  COUNT(tof.id) as nombre_offres
FROM trips t
LEFT JOIN users u ON u.id = t.rider_id
LEFT JOIN trip_offers tof ON tof.trip_id = t.id
WHERE t.status = 'pending'
GROUP BY t.id, t.status, t.vehicle_type, u.full_name
ORDER BY t.created_at DESC
LIMIT 10;

-- Détails des offres pour chaque trip
SELECT 
  tof.id as offer_id,
  tof.trip_id,
  tof.driver_id,
  tof.offered_price,
  tof.eta_minutes,
  tof.status as offer_status,
  tof.created_at,
  u.full_name as driver_name,
  dp.rating_average,
  dp.total_trips,
  dp.vehicle_plate
FROM trip_offers tof
LEFT JOIN users u ON u.id = tof.driver_id
LEFT JOIN driver_profiles dp ON dp.id = tof.driver_id
ORDER BY tof.created_at DESC
LIMIT 10;
