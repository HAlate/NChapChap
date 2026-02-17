-- Vérifier la structure actuelle de la vue trip_offers_with_driver
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'trip_offers_with_driver'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Vérifier si driver_vehicle_type existe déjà
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'trip_offers_with_driver'
      AND column_name = 'driver_vehicle_type'
      AND table_schema = 'public'
) AS driver_vehicle_type_exists;
