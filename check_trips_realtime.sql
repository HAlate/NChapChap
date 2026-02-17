-- Vérifier si Realtime est activé pour la table trips

-- 1. Vérifier la publication Realtime
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN tablename = ANY(
            SELECT unnest(string_to_array(
                replace(replace(pubtables, '"', ''), ' ', ''), ','
            ))
            FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime'
        ) THEN '✅ Realtime ENABLED'
        ELSE '❌ Realtime NOT enabled'
    END as realtime_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'trips';

-- 2. Vérifier REPLICA IDENTITY
SELECT 
    c.relname as table_name,
    CASE c.relreplident
        WHEN 'd' THEN '⚠️ DEFAULT - Updates may not broadcast all columns'
        WHEN 'f' THEN '✅ FULL - All columns broadcast on updates'
        WHEN 'n' THEN '❌ NOTHING - No replication'
        ELSE 'Unknown'
    END as replica_identity
FROM pg_class c
WHERE c.relname = 'trips' 
AND c.relnamespace = 'public'::regnamespace;

-- 3. Si Realtime n'est pas activé, exécutez:
-- ALTER PUBLICATION supabase_realtime ADD TABLE trips;
-- ALTER TABLE trips REPLICA IDENTITY FULL;
