-- Trouver toutes les politiques qui mentionnent trip_offers
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE qual LIKE '%trip_offers%' 
   OR with_check LIKE '%trip_offers%'
ORDER BY tablename, policyname;
