-- ============================================
-- Enable Realtime for call_sessions table
-- This allows UPDATE events to be broadcast via Supabase Realtime
-- ============================================

-- Enable REPLICA IDENTITY FULL to broadcast all column changes
-- This is required for Realtime to send UPDATE events
ALTER TABLE call_sessions REPLICA IDENTITY FULL;

-- Verify Realtime is enabled (should already be enabled via Supabase UI)
-- If not, run this in Supabase SQL Editor:
-- ALTER PUBLICATION supabase_realtime ADD TABLE call_sessions;

-- Verify the change
SELECT tablename, relreplident 
FROM pg_class 
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
JOIN pg_tables ON pg_tables.tablename = pg_class.relname
WHERE tablename = 'call_sessions';

-- Result should show:
-- tablename      | relreplident
-- call_sessions  | f (means FULL)
