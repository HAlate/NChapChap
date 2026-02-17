-- Voir tous les trips pending pour moto-taxi
SELECT 
  t.id,
  t.status,
  t.driver_id,
  t.vehicle_type,
  t.departure,
  t.destination,
  t.created_at
FROM trips t
WHERE t.status = 'pending'
  AND t.vehicle_type = 'moto-taxi'
ORDER BY t.created_at DESC
LIMIT 10;
