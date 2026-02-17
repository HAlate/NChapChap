-- ============================================
-- Fix Realtime for call_sessions table
-- This ensures UPDATE events are broadcast
-- ============================================

-- 1. Vérifier que la table est dans la publication
SELECT * FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'call_sessions';

-- Si pas de résultat, ajouter la table:
ALTER PUBLICATION supabase_realtime ADD TABLE call_sessions;

-- 2. Vérifier REPLICA IDENTITY (doit être FULL)
SELECT relname, relreplident 
FROM pg_class 
WHERE relname = 'call_sessions';
-- 'd' = DEFAULT, 'f' = FULL (on veut 'f')

-- Si pas FULL, activer:
ALTER TABLE call_sessions REPLICA IDENTITY FULL;

-- 3. Redémarrer la publication pour forcer la mise à jour
ALTER PUBLICATION supabase_realtime DROP TABLE call_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE call_sessions;

-- 4. Vérification finale
SELECT 
    schemaname,
    tablename,
    'Table is in publication' as status
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'call_sessions'
UNION ALL
SELECT 
    n.nspname as schemaname,
    c.relname as tablename,
    CASE c.relreplident
        WHEN 'd' THEN '⚠️ REPLICA IDENTITY is DEFAULT (should be FULL)'
        WHEN 'f' THEN '✅ REPLICA IDENTITY is FULL'
        ELSE '❌ REPLICA IDENTITY unknown'
    END as status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'call_sessions'
AND n.nspname = 'public';
