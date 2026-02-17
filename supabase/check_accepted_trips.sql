-- Vérifier le dernier trip accepté
SELECT 
  t.id,
  t.status,
  t.driver_id,
  t.final_price,
  t.accepted_at,
  u.email as driver_email
FROM trips t
LEFT JOIN users u ON t.driver_id = u.id
WHERE t.status = 'accepted'
ORDER BY t.accepted_at DESC
LIMIT 5;
