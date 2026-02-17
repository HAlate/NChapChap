-- Vérifier combien d'offres existent pour le driver dans la base
SELECT 
  COUNT(*) as total_offers,
  COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_offers,
  COUNT(CASE WHEN status = 'selected' THEN 1 END) as selected_offers,
  COUNT(CASE WHEN status = 'accepted' THEN 1 END) as accepted_offers,
  COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_offers
FROM trip_offers
WHERE driver_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d';

-- Voir quelques exemples d'offres
SELECT 
  id,
  trip_id,
  status,
  offered_price,
  counter_price,
  created_at
FROM trip_offers
WHERE driver_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d'
ORDER BY created_at DESC
LIMIT 5;
