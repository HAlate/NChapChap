-- Vérifier l'offre qui pose problème
SELECT 
  o.id as offer_id,
  o.trip_id,
  o.status as offer_status,
  o.counter_price,
  t.id as trip_id_found,
  t.status as trip_status,
  t.departure,
  t.destination,
  t.rider_id
FROM trip_offers o
LEFT JOIN trips t ON t.id = o.trip_id
WHERE o.id = '05757985-c3be-48ca-a253-92a07e2e9fbc';
