-- Vérifier si la fonction create_new_trip existe
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'create_new_trip';

-- Vérifier la structure de la table trips
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trips'
ORDER BY ordinal_position;

-- Tester la création d'une course (remplacez les valeurs)
-- SELECT * FROM create_new_trip(
--     'Test Départ', 
--     6.1372, 
--     1.2123, 
--     'Test Destination', 
--     6.1400, 
--     1.2200, 
--     'moto', 
--     5.5
-- );
