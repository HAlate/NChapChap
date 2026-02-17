-- Lister TOUS les triggers sur la table trip_offers
SELECT 
  tgname as trigger_name,
  pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'trip_offers'::regclass
  AND tgisinternal = false;
