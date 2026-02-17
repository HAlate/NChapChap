-- Vérifier les offres existantes
SELECT 
  tof.id,
  tof.trip_id,
  tof.driver_id,
  tof.offered_price,
  tof.status,
  tof.created_at,
  u.full_name as driver_name,
  u.phone as driver_phone
FROM trip_offers tof
LEFT JOIN users u ON u.id = tof.driver_id
ORDER BY tof.created_at DESC
LIMIT 10;

-- Vérifier les trips en attente
SELECT 
  t.id,
  t.rider_id,
  t.status,
  t.vehicle_type,
  t.created_at,
  u.full_name as rider_name
FROM trips t
LEFT JOIN users u ON u.id = t.rider_id
WHERE t.status = 'pending'
ORDER BY t.created_at DESC
LIMIT 10;
