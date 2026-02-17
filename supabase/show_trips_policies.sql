-- Voir toutes les politiques RLS de la table trips
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'trips'
ORDER BY policyname;
