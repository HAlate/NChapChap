-- ========================================
-- Diagnostic: Vérifier colonne driver_arrived_notification
-- ========================================

-- 1. Vérifier si la colonne existe dans la table trips
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trips' 
  AND column_name = 'driver_arrived_notification';

-- 2. Si la colonne n'existe pas, l'ajouter
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns
        WHERE table_schema = 'public' 
          AND table_name = 'trips' 
          AND column_name = 'driver_arrived_notification'
    ) THEN
        ALTER TABLE trips
        ADD COLUMN driver_arrived_notification TIMESTAMP WITH TIME ZONE;
        
        COMMENT ON COLUMN trips.driver_arrived_notification IS 
        'Timestamp de la dernière notification manuelle envoyée par le chauffeur pour signaler son arrivée au passager';
        
        RAISE NOTICE 'Colonne driver_arrived_notification ajoutée avec succès';
    ELSE
        RAISE NOTICE 'Colonne driver_arrived_notification existe déjà';
    END IF;
END$$;

-- 3. Vérifier quelques trips pour voir si des notifications ont été envoyées
SELECT 
    id,
    status,
    driver_arrived_notification,
    created_at
FROM trips
WHERE status IN ('accepted', 'arrived_waiting', 'started')
ORDER BY created_at DESC
LIMIT 5;
