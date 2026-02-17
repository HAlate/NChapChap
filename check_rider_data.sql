-- ========================================
-- Vérifier les données du rider dans la vue
-- ========================================

-- 1. Vérifier tous les riders
SELECT 
  id,
  phone,
  full_name,
  email,
  user_type
FROM users
WHERE user_type = 'rider';

-- 2. Vérifier la vue available_trips_with_riders_view
SELECT 
  id as trip_id,
  rider_id,
  rider_full_name,
  rider_phone,
  rider_email,
  departure,
  destination,
  vehicle_type,
  status,
  created_at
FROM available_trips_with_riders_view
ORDER BY created_at DESC;

-- 3. Vérifier les trips pending avec jointure manuelle
SELECT 
  t.id as trip_id,
  t.rider_id,
  u.full_name as rider_full_name,
  u.phone as rider_phone,
  u.email as rider_email,
  t.departure,
  t.destination,
  t.vehicle_type,
  t.status,
  t.created_at
FROM trips t
LEFT JOIN users u ON t.rider_id = u.id
WHERE t.status = 'pending'
ORDER BY t.created_at DESC;
