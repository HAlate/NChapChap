-- Vérifier la définition actuelle du trigger
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'spend_token_on_trip_offer_acceptance';
