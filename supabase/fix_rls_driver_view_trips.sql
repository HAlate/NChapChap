-- Politique RLS pour permettre aux drivers de voir les trips où ils ont fait une offre
CREATE POLICY "Drivers can view trips they have offers on"
ON trips
FOR SELECT
USING (
  EXISTS (
    SELECT 1 
    FROM trip_offers 
    WHERE trip_offers.trip_id = trips.id 
    AND trip_offers.driver_id = auth.uid()
  )
);
