-- Voir toutes les politiques RLS de la table trip_offers
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'trip_offers'
ORDER BY policyname;
