-- ========================================
-- FIX: RLS bloque les événements Realtime pour le driver
-- ========================================
-- Le driver ne reçoit pas les UPDATE events même si le channel est SUBSCRIBED
-- C'est parce que les RLS policies bloquent les événements Realtime

-- 1. Vérifier les policies actuelles
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
WHERE tablename = 'trip_offers'
ORDER BY policyname;

-- 2. SOLUTION TEMPORAIRE: Désactiver RLS pour tester
-- ⚠️ NE PAS UTILISER EN PRODUCTION !
-- ALTER TABLE trip_offers DISABLE ROW LEVEL SECURITY;

-- 3. SOLUTION PERMANENTE: Créer une policy pour Realtime
-- Les événements Realtime nécessitent SELECT permission

-- Supprimer TOUTES les anciennes policies SELECT
DROP POLICY IF EXISTS "Drivers can view their own offers for realtime" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can receive realtime updates for their offers" ON trip_offers;
DROP POLICY IF EXISTS "Riders can view offers for their trips" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can view their own offers" ON trip_offers;
DROP POLICY IF EXISTS "Riders can view offers for their trip" ON trip_offers;

-- Policy pour que le driver puisse recevoir les événements Realtime de SES offres
CREATE POLICY "Drivers can receive realtime updates for their offers"
ON trip_offers
FOR SELECT
USING (
    auth.uid() = driver_id
);

-- Policy pour que le rider puisse voir les offres de SON trip
CREATE POLICY "Riders can view offers for their trips"
ON trip_offers
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM trips
        WHERE trips.id = trip_offers.trip_id
        AND trips.rider_id = auth.uid()
    )
);

-- 4. Vérifier que les policies sont créées
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'trip_offers'
AND policyname LIKE '%realtime%';
