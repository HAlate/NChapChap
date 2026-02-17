-- ========================================
-- DIAGNOSTIC REALTIME - ÉTAPE 1: REPLICA IDENTITY
-- ========================================
-- C'EST LE PLUS IMPORTANT!

SELECT 
    c.relname as table_name,
    CASE 
        WHEN c.relreplident = 'd' THEN '❌ DEFAULT - UPDATE events NE MARCHERONT PAS'
        WHEN c.relreplident = 'f' THEN '✅ FULL - UPDATE events vont marcher'
        WHEN c.relreplident = 'i' THEN '⚠️ INDEX'
        WHEN c.relreplident = 'n' THEN '❌ NOTHING'
    END as replica_identity_status,
    CASE 
        WHEN c.relreplident = 'f' THEN '✅ Rien à faire'
        ELSE '❌ EXÉCUTEZ: ALTER TABLE trip_offers REPLICA IDENTITY FULL;'
    END as action_required
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'trip_offers' AND n.nspname = 'public';

-- ========================================
-- ÉTAPE 2: PUBLICATION
-- ========================================

SELECT 
    pt.tablename,
    pt.pubname,
    '✅ Table est publiée pour Realtime' as status
FROM pg_publication_tables pt
WHERE pt.pubname = 'supabase_realtime' 
  AND pt.tablename = 'trip_offers';

-- ========================================
-- ÉTAPE 3: CONFIG PUBLICATION
-- ========================================

SELECT 
    pubname,
    pubupdate,
    pubdelete,
    CASE 
        WHEN pubupdate = true THEN '✅ UPDATE events activés'
        ELSE '❌ UPDATE events désactivés'
    END as update_status
FROM pg_publication
WHERE pubname = 'supabase_realtime';
