-- ============================================
-- Enable Realtime for call_signaling table
-- ============================================

-- 1. Set REPLICA IDENTITY to FULL (required for UPDATE/DELETE events)
ALTER TABLE call_signaling REPLICA IDENTITY FULL;

-- 2. Add table to supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE call_signaling;

-- 3. Verify configuration
SELECT 
    'call_signaling Configuration' as info,
    schemaname,
    tablename,
    CASE 
        WHEN relreplident = 'd' THEN 'DEFAULT'
        WHEN relreplident = 'f' THEN 'FULL'
        WHEN relreplident = 'i' THEN 'INDEX'
        WHEN relreplident = 'n' THEN 'NOTHING'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_tables t ON t.tablename = c.relname AND t.schemaname = n.nspname
WHERE c.relname = 'call_signaling';

-- 4. Verify it's in the publication
SELECT 
    'Publication Status' as info,
    pub.pubname,
    pg_class.relname as table_name
FROM pg_publication pub
JOIN pg_publication_tables pub_tables ON pub.pubname = pub_tables.pubname
JOIN pg_class ON pg_class.relname = pub_tables.tablename
WHERE pub.pubname = 'supabase_realtime' 
  AND pg_class.relname = 'call_signaling';

-- 5. If already in publication, refresh it (drop and re-add)
DO $$
BEGIN
    -- Try to drop (will fail silently if not in publication)
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime DROP TABLE call_signaling';
        RAISE NOTICE 'Dropped call_signaling from publication';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Table not in publication, skipping drop';
    END;
    
    -- Add to publication
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE call_signaling';
    RAISE NOTICE 'Added call_signaling to publication';
END $$;

-- 6. Final verification
SELECT 
    'Final Check' as info,
    COUNT(*) as tables_in_publication
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime' 
  AND tablename IN ('call_sessions', 'call_signaling');
