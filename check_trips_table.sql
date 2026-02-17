-- Vérifier si la table trips existe et ses colonnes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'trips'
ORDER BY ordinal_position;

-- Vérifier l'enum trip_status
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = 'trip_status'::regtype 
ORDER BY enumsortorder;

-- Vérifier les politiques RLS sur la table trips
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'trips';
