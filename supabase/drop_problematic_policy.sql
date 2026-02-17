-- Supprimer la politique problématique si elle existe
DROP POLICY IF EXISTS "Drivers can view trips they have offers on" ON trips;
