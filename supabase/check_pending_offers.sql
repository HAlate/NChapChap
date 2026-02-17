-- Créer une contre-proposition de test pour voir le flux
-- D'abord, trouver une offre pending
SELECT 
  to2.id as offer_id,
  to2.trip_id,
  to2.driver_id,
  to2.status,
  to2.offered_price,
  to2.counter_price,
  u.email as driver_email
FROM trip_offers to2
JOIN users u ON to2.driver_id = u.id
WHERE to2.status = 'pending'
ORDER BY to2.created_at DESC
LIMIT 5;
