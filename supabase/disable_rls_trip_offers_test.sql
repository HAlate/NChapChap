-- Désactiver temporairement RLS sur trip_offers pour tester
ALTER TABLE trip_offers DISABLE ROW LEVEL SECURITY;

-- NOTE: N'oubliez pas de le réactiver après le test avec:
-- ALTER TABLE trip_offers ENABLE ROW LEVEL SECURITY;
