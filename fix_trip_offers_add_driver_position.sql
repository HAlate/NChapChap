-- =========================================
-- FIX: Colonnes manquantes et erreurs dans trip_offers
-- =========================================
-- Erreur 1: "could not find driver_lat_at_offer column of trips_offers"
-- Erreur 2: "null value column 'vehicle_type' of relation 'trip_offers'"
-- Ces colonnes stockent la position GPS du driver au moment de l'offre
-- La colonne vehicle_type ne doit plus être NOT NULL (ou supprimée)

-- =========================================
-- SOLUTION 1: Ajouter les colonnes manquantes
-- =========================================

DO $$ 
BEGIN
    -- Ajouter driver_lat_at_offer
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'trip_offers' 
          AND column_name = 'driver_lat_at_offer'
    ) THEN
        ALTER TABLE trip_offers 
        ADD COLUMN driver_lat_at_offer double precision;
        RAISE NOTICE '✅ Colonne driver_lat_at_offer ajoutée';
    ELSE
        RAISE NOTICE 'ℹ️  Colonne driver_lat_at_offer existe déjà';
    END IF;

    -- Ajouter driver_lng_at_offer
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'trip_offers' 
          AND column_name = 'driver_lng_at_offer'
    ) THEN
        ALTER TABLE trip_offers 
        ADD COLUMN driver_lng_at_offer double precision;
        RAISE NOTICE '✅ Colonne driver_lng_at_offer ajoutée';
    ELSE
        RAISE NOTICE 'ℹ️  Colonne driver_lng_at_offer existe déjà';
    END IF;
END $$;

-- =========================================
-- SOLUTION 2: Supprimer la colonne vehicle_type de trip_offers
-- =========================================
-- Le vehicle_type vient de la table trips via JOIN, pas besoin dans trip_offers

DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'trip_offers' 
          AND column_name = 'vehicle_type'
    ) THEN
        ALTER TABLE trip_offers DROP COLUMN vehicle_type CASCADE;
        RAISE NOTICE '✅ Colonne vehicle_type supprimée de trip_offers';
    ELSE
        RAISE NOTICE 'ℹ️  Colonne vehicle_type n''existe pas dans trip_offers';
    END IF;
END $$;

-- Ajouter commentaires pour documentation
COMMENT ON COLUMN trip_offers.driver_lat_at_offer IS 'Latitude du driver au moment de l''offre';
COMMENT ON COLUMN trip_offers.driver_lng_at_offer IS 'Longitude du driver au moment de l''offre';

-- =========================================
-- Mettre à jour la vue trip_offers_with_driver
-- =========================================
-- La vue doit inclure ces nouvelles colonnes

DROP VIEW IF EXISTS trip_offers_with_driver;

CREATE VIEW trip_offers_with_driver AS
SELECT 
  -- COLONNES DE TRIP_OFFERS (sans alias pour correspondre au modèle Dart)
  tof.id,
  tof.trip_id,
  tof.driver_id,
  
  -- Prix de négociation
  tof.offered_price,
  tof.counter_price,
  tof.driver_counter_price,
  tof.final_price,
  
  -- Informations temporelles et logistiques
  tof.eta_minutes,
  tof.status,
  tof.token_spent,
  tof.created_at,
  
  -- Position du driver au moment de l'offre (NOUVELLES COLONNES)
  tof.driver_lat_at_offer,
  tof.driver_lng_at_offer,
  
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
  t.vehicle_type,
  
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
'Vue complète pour le système de négociation avec position GPS du driver';

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que les colonnes existent
SELECT 
  'Colonnes driver position' as check_name,
  CASE 
    WHEN COUNT(*) = 2 THEN '✅ Les 2 colonnes existent'
    WHEN COUNT(*) = 1 THEN '⚠️  Une seule colonne existe'
    ELSE '❌ Aucune colonne'
  END as status,
  string_agg(column_name, ', ') as columns_found
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trip_offers'
  AND column_name IN ('driver_lat_at_offer', 'driver_lng_at_offer');

-- Test 2: Vérifier la structure de trip_offers
SELECT 
  'Structure table trip_offers' as check_name,
  COUNT(*)::text || ' colonnes' as status
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trip_offers';

-- Test 3: Lister toutes les colonnes de trip_offers
SELECT 
  ordinal_position,
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trip_offers'
ORDER BY ordinal_position;

-- Test 4: Vérifier que la vue a les nouvelles colonnes
SELECT 
  'Colonnes dans vue trip_offers_with_driver' as check_name,
  CASE 
    WHEN COUNT(*) = 2 THEN '✅ Les 2 colonnes sont dans la vue'
    WHEN COUNT(*) = 1 THEN '⚠️  Une seule colonne dans la vue'
    ELSE '❌ Colonnes manquantes dans la vue'
  END as status
FROM information_schema.columns
WHERE table_name = 'trip_offers_with_driver'
  AND column_name IN ('driver_lat_at_offer', 'driver_lng_at_offer');

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1. Exécuter ce script dans Supabase SQL Editor' as etape_1,
  '2. Vérifier que tous les checks sont verts ✅' as etape_2,
  '3. Hot restart de l''app mobile' as etape_3,
  '4. L''erreur "could not find driver_lat_at_offer" doit disparaître' as etape_4;

-- =========================================
-- NOTES
-- =========================================
-- 
-- Ces colonnes permettent de:
-- -OLONNES driver_lat_at_offer et driver_lng_at_offer:
-- - Afficher la distance exacte entre le driver et le point de départ
-- - Calculer l'ETA réel au moment de l'offre
-- - Tracer la position du driver sur la carte pour le rider
-- - Améliorer la transparence du système de négociation
--
-- SUPPRESSION de vehicle_type dans trip_offers:
-- - Le vehicle_type existe déjà dans la table trips
-- - La vue trip_offers_with_driver fait le JOIN pour l'obtenir
-- - Évite la redondance et les erreurs NULL
-- - Le code mobile_driver n'envoie plus ce champ lors de createOffer()
