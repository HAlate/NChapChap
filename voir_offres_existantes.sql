-- Voir les détails des 2 offres existantes
SELECT 
  tof.id,
  tof.trip_id,
  tof.driver_id,
  tof.offered_price,
  tof.eta_minutes,
  tof.status,
  u.full_name as driver_name,
  dp.rating_average,
  dp.total_trips
FROM trip_offers tof
LEFT JOIN users u ON u.id = tof.driver_id
LEFT JOIN driver_profiles dp ON dp.id = tof.driver_id
WHERE tof.trip_id IN ('5a5b5f01-67f0-4315-80a9-d12a654042c6', 'eb3e78d4-fe96-4b9a-a780-c92773693e02')
ORDER BY tof.created_at DESC;
