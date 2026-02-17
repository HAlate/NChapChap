-- ========================================
-- Ajouter colonnes manquantes à trip_offers
-- ========================================
-- Ces colonnes sont nécessaires pour stocker la position du driver
-- au moment où il fait son offre

-- Ajouter les colonnes si elles n'existent pas
DO $$ 
BEGIN
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

-- Vérifier les colonnes
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trip_offers'
ORDER BY ordinal_position;
