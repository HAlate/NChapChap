-- ========================================
-- VÉRIFICATION CONFIGURATION REALTIME - TABLE TRIPS
-- ========================================
-- Ce script vérifie que Realtime est bien configuré pour trips

-- 1. Vérifier REPLICA IDENTITY (doit être FULL pour UPDATE/DELETE events)
SELECT 
    n.nspname as schemaname,
    c.relname as tablename,
    CASE 
        WHEN c.relreplident = 'd' THEN 'DEFAULT (clé primaire uniquement)'
        WHEN c.relreplident = 'f' THEN 'FULL (toutes les colonnes) ✅'
        WHEN c.relreplident = 'i' THEN 'INDEX'
        WHEN c.relreplident = 'n' THEN 'NOTHING'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'trips' AND n.nspname = 'public';

-- 2. Vérifier les publications Realtime (Supabase crée automatiquement 'supabase_realtime')
SELECT 
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- 3. Vérifier que trips est dans la publication
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'trips';

-- 4. Si trips n'est PAS dans la publication, l'ajouter
-- ALTER PUBLICATION supabase_realtime ADD TABLE trips;

-- 5. Si REPLICA IDENTITY n'est pas FULL, le définir
-- ALTER TABLE trips REPLICA IDENTITY FULL;

-- ========================================
-- RÉSULTATS ATTENDUS:
-- ========================================
-- 1. replica_identity = 'FULL (toutes les colonnes) ✅'
-- 2. supabase_realtime existe avec pubupdate = true
-- 3. trips est listé dans pg_publication_tables

-- Si l'un de ces éléments manque, Realtime ne fonctionnera pas correctement!
