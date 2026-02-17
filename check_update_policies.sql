-- ========================================
-- Vérifier les policies UPDATE sur trip_offers
-- ========================================

-- Query 1: Liste TOUTES les policies UPDATE sur trip_offers
SELECT 
  polname AS policy_name,
  polcmd AS command_type,
  pg_get_expr(polqual, polrelid) AS using_expression,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expression
FROM pg_policy
WHERE polrelid = 'trip_offers'::regclass
  AND polcmd = 'w'  -- 'w' = UPDATE
ORDER BY polname;

-- Query 2: Vérifier TOUTES les policies (tous types de commandes)
SELECT 
  polname AS policy_name,
  CASE polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
  END AS command_type,
  pg_get_expr(polqual, polrelid) AS using_expression
FROM pg_policy
WHERE polrelid = 'trip_offers'::regclass
ORDER BY polcmd, polname;
