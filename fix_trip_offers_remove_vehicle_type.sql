-- ========================================
-- CORRECTION: Supprimer la colonne vehicle_type de trip_offers
-- ========================================
-- Cette colonne n'existe pas dans APPZEDGO et ne devrait pas être dans trip_offers
-- Le vehicle_type doit venir de la table trips via JOIN

-- 1. Supprimer la colonne vehicle_type si elle existe
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'trip_offers' 
          AND column_name = 'vehicle_type'
    ) THEN
        ALTER TABLE trip_offers DROP COLUMN vehicle_type;
        RAISE NOTICE 'Colonne vehicle_type supprimée de trip_offers';
    ELSE
        RAISE NOTICE 'Colonne vehicle_type n''existe pas dans trip_offers';
    END IF;
END $$;

-- 2. Vérifier la structure finale
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trip_offers'
ORDER BY ordinal_position;
