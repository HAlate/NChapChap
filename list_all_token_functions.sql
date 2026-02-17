-- Lister TOUTES les fonctions qui utilisent token_transactions
SELECT 
  p.proname as function_name,
  pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE pg_get_functiondef(p.oid) ILIKE '%token_transactions%'
AND n.nspname = 'public';
