-- Créer une offre pour le trip le plus récent (277ba707-a660-4efa-8403-3e1bd8d4411b)
INSERT INTO trip_offers (trip_id, driver_id, offered_price, eta_minutes, vehicle_type, status)
SELECT 
  '277ba707-a660-4efa-8403-3e1bd8d4411b',
  u.id,
  15000,
  10,
  'moto-taxi',
  'pending'
FROM users u
WHERE u.user_type = 'driver'
ORDER BY u.created_at DESC
LIMIT 1
RETURNING *;
