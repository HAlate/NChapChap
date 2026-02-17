-- ========================================
-- Vérifier les policies RLS actuelles sur trip_offers
-- ========================================

-- Query 1: Liste TOUTES les policies SELECT sur trip_offers
SELECT 
  polname AS policy_name,
  polcmd AS command_type,
  pg_get_expr(polqual, polrelid) AS using_expression,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expression
FROM pg_policy
WHERE polrelid = 'trip_offers'::regclass
  AND polcmd = 'r'  -- 'r' = SELECT
ORDER BY polname;

-- Query 2: Vérifier si RLS est activé sur trip_offers
SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE tablename = 'trip_offers';

-- Query 3: Vérifier la configuration Realtime
SELECT 
  schemaname,
  tablename,
  relreplident AS replica_identity
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE relname = 'trip_offers';

-- Query 4: Vérifier les publications Realtime
SELECT 
  pubname,
  puballtables,
  pubinsert,
  pubupdate,
  pubdelete
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- Query 5: Vérifier que trip_offers est dans la publication
SELECT 
  p.pubname,
  t.schemaname,
  t.tablename
FROM pg_publication p
JOIN pg_publication_tables t ON p.pubname = t.pubname
WHERE t.tablename = 'trip_offers';
