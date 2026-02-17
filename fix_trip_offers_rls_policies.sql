-- ========================================
-- Vérification et correction des RLS pour trip_offers
-- ========================================

-- 1. Vérifier les policies existantes
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

-- 2. Supprimer les anciennes policies si nécessaire
DROP POLICY IF EXISTS "Riders can view offers for their trips" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can view their own offers" ON trip_offers;
DROP POLICY IF EXISTS "Drivers can insert offers" ON trip_offers;
DROP POLICY IF EXISTS "Riders can update selected offer" ON trip_offers;

-- 3. Créer les policies correctes

-- Policy: Les riders voient les offres pour leurs trips
CREATE POLICY "Riders can view offers for their trips"
ON trip_offers
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM trips
    WHERE trips.id = trip_offers.trip_id
    AND trips.rider_id = auth.uid()
  )
);

-- Policy: Les drivers voient leurs propres offres
CREATE POLICY "Drivers can view their own offers"
ON trip_offers
FOR SELECT
TO authenticated
USING (driver_id = auth.uid());

-- Policy: Les drivers peuvent créer des offres
CREATE POLICY "Drivers can insert offers"
ON trip_offers
FOR INSERT
TO authenticated
WITH CHECK (
  driver_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM token_balances
    WHERE user_id = auth.uid()
    AND token_type = 'course'
    AND balance >= 1
  )
);

-- Policy: Les riders peuvent mettre à jour le status des offres (sélection)
CREATE POLICY "Riders can update selected offer"
ON trip_offers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM trips
    WHERE trips.id = trip_offers.trip_id
    AND trips.rider_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trips
    WHERE trips.id = trip_offers.trip_id
    AND trips.rider_id = auth.uid()
  )
);

-- Policy: Les drivers peuvent mettre à jour leurs offres (contre-prix)
CREATE POLICY "Drivers can update their own offers"
ON trip_offers
FOR UPDATE
TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- 4. Vérifier que RLS est activé
ALTER TABLE trip_offers ENABLE ROW LEVEL SECURITY;

-- 5. Afficher les policies finales
SELECT 
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE tablename = 'trip_offers'
ORDER BY policyname;
