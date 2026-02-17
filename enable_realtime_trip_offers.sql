-- ========================================
-- Activer Realtime pour trip_offers
-- ========================================

-- 1. Activer la réplication pour la table trip_offers
ALTER TABLE trip_offers REPLICA IDENTITY FULL;

-- 2. Vérifier la configuration
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'trip_offers';

-- 3. Vérifier la réplication
SELECT 
    schemaname,
    tablename,
    relreplident
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'trip_offers';

-- Note: Vous devez également activer Realtime dans l'interface Supabase:
-- 1. Allez dans Database > Replication
-- 2. Cochez la table 'trip_offers' dans la section "Tables"
-- 3. Cliquez sur "Save" ou "Apply changes"
