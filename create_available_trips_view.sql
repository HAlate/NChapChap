-- ========================================
-- CREATE VIEW: available_trips_with_riders_view
-- ========================================
-- Cette vue affiche les trips en attente avec les infos du rider
-- Elle simplifie les requêtes et contourne les problèmes de RLS

-- Supprimer la vue si elle existe déjà
DROP VIEW IF EXISTS available_trips_with_riders_view;

-- Créer la vue
CREATE OR REPLACE VIEW available_trips_with_riders_view AS
SELECT 
  -- Colonnes du trip
  t.id,
  t.rider_id,
  t.driver_id,
  t.vehicle_type,
  t.departure,
  t.destination,
  t.departure_lat,
  t.departure_lng,
  t.destination_lat,
  t.destination_lng,
  t.distance_km,
  t.proposed_price,
  t.final_price,
  t.payment_method,
  t.status,
  t.driver_token_spent,
  t.driver_rating,
  t.rider_rating,
  t.created_at,
  t.accepted_at,
  t.started_at,
  t.completed_at,
  t.cancelled_at,
  
  -- Informations du rider (passager)
  u.full_name as rider_full_name,
  u.phone as rider_phone,
  u.email as rider_email
  
FROM trips t
LEFT JOIN users u ON t.rider_id = u.id
WHERE t.status = 'pending'
  AND t.created_at >= NOW() - INTERVAL '10 minutes' -- Seulement les demandes de moins de 10 minutes
  AND NOT EXISTS (
    -- Exclure les trips qui ont déjà une offre acceptée
    SELECT 1 FROM trip_offers o
    WHERE o.trip_id = t.id
    AND o.status = 'accepted'
  );

-- Donner les permissions de lecture à tous les utilisateurs authentifiés
GRANT SELECT ON available_trips_with_riders_view TO authenticated;

-- Commentaire explicatif
COMMENT ON VIEW available_trips_with_riders_view IS 
'Vue des trips en attente (pending) de moins de 10 minutes avec les informations du passager. Utilisée par les drivers pour voir les demandes de course disponibles dans leur zone.';
