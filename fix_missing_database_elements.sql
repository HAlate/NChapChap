-- =========================================
-- FIX: Éléments manquants dans la base de données
-- =========================================
-- Erreurs détectées:
-- 1. Table 'geocode_cache' n'existe pas (erreur PGRST205)
-- 2. Colonne 'created_at' manquante dans la vue 'trip_offers_with_driver'

-- =========================================
-- SOLUTION 1: Créer la table geocode_cache
-- =========================================

CREATE TABLE IF NOT EXISTS public.geocode_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cache_key TEXT NOT NULL UNIQUE,
    query TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    results JSONB NOT NULL,
    hit_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_geocode_cache_key ON public.geocode_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_query ON public.geocode_cache(query);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_expires ON public.geocode_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_coords ON public.geocode_cache(latitude, longitude);

-- Commentaires
COMMENT ON TABLE public.geocode_cache IS 'Cache pour les requêtes de geocoding Mapbox';
COMMENT ON COLUMN public.geocode_cache.cache_key IS 'Hash unique de la requête (SHA-256)';
COMMENT ON COLUMN public.geocode_cache.query IS 'Requête de recherche originale';
COMMENT ON COLUMN public.geocode_cache.results IS 'Résultats JSON de la requête';
COMMENT ON COLUMN public.geocode_cache.hit_count IS 'Nombre de fois que cette entrée a été utilisée';
COMMENT ON COLUMN public.geocode_cache.expires_at IS 'Date d''expiration du cache (7 jours par défaut)';

-- Permissions
GRANT ALL ON public.geocode_cache TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.geocode_cache TO anon;

-- Politique RLS (permissive pour le cache)
ALTER TABLE public.geocode_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on geocode_cache"
  ON public.geocode_cache
  FOR ALL
  TO authenticated, anon
  USING (true)
  WITH CHECK (true);

-- =========================================
-- SOLUTION 2: Recréer la vue trip_offers_with_driver avec created_at
-- =========================================

DROP VIEW IF EXISTS trip_offers_with_driver;

CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- COLONNES DE TRIP_OFFERS
  tof.id AS offer_id,
  tof.trip_id,
  tof.driver_id,
  
  -- Prix de négociation
  tof.offered_price,
  tof.counter_price,
  tof.driver_counter_price,
  tof.final_price,
  
  -- Informations temporelles et logistiques
  tof.eta_minutes,
  tof.vehicle_type,
  tof.status,
  tof.token_spent,
  tof.created_at,  -- ✅ AJOUT: Colonne created_at qui manquait
  tof.created_at AS offer_created_at,
  
  -- INFORMATIONS DU CHAUFFEUR
  u.id AS driver_user_id,
  u.full_name AS driver_name,
  u.phone AS driver_phone,
  u.email AS driver_email,
  u.profile_photo_url AS driver_photo_url,
  
  dp.rating_average AS driver_rating,
  dp.total_trips AS driver_total_trips,
  dp.total_deliveries AS driver_total_deliveries,
  dp.vehicle_plate AS driver_vehicle_plate,
  dp.vehicle_brand AS driver_vehicle_brand,
  dp.vehicle_model AS driver_vehicle_model,
  dp.vehicle_year AS driver_vehicle_year,
  dp.is_available AS driver_is_available,
  dp.current_lat AS driver_current_lat,
  dp.current_lng AS driver_current_lng,
  dp.last_location_update AS driver_last_location_update,
  
  -- INFORMATIONS DU TRAJET
  t.status AS trip_status,
  t.rider_id,
  t.vehicle_type AS requested_vehicle_type,
  
  t.departure AS departure_address,
  t.departure_lat,
  t.departure_lng,
  
  t.destination AS destination_address,
  t.destination_lat,
  t.destination_lng,
  
  t.distance_km,
  t.proposed_price AS trip_proposed_price,
  t.final_price AS trip_final_price,
  t.payment_method,
  t.created_at AS trip_created_at,
  t.accepted_at AS trip_accepted_at,
  t.started_at AS trip_started_at,
  t.completed_at AS trip_completed_at,
  
  -- INFORMATIONS DU PASSAGER
  rider.id AS rider_user_id,
  rider.full_name AS rider_name,
  rider.phone AS rider_phone,
  rider.email AS rider_email,
  rider.profile_photo_url AS rider_photo_url
  
FROM trip_offers tof
JOIN users u ON tof.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
JOIN trips t ON tof.trip_id = t.id
JOIN users rider ON t.rider_id = rider.id;

COMMENT ON VIEW trip_offers_with_driver IS 
'Vue complète pour le système de négociation avec colonne created_at ajoutée';

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que la table geocode_cache existe
SELECT 
  'Table geocode_cache' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Existe'
    ELSE '❌ Manquante'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'geocode_cache';

-- Test 2: Vérifier que la vue a la colonne created_at
SELECT 
  'Colonne created_at dans vue' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Existe'
    ELSE '❌ Manquante'
  END as status
FROM information_schema.columns
WHERE table_name = 'trip_offers_with_driver' 
  AND column_name = 'created_at';

-- Test 3: Compter les colonnes de la vue
SELECT 
  'Nombre de colonnes dans vue' as check_name,
  COUNT(*)::text || ' colonnes' as status
FROM information_schema.columns
WHERE table_name = 'trip_offers_with_driver';

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1. Exécuter ce script dans Supabase SQL Editor' as etape_1,
  '2. Vérifier que tous les checks sont verts ✅' as etape_2,
  '3. Redémarrer l''app mobile (hot restart)' as etape_3,
  '4. Les erreurs geocode_cache et created_at doivent disparaître' as etape_4;
