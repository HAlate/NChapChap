-- Voir la définition de la fonction actuellement utilisée
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'spend_token_on_offer_acceptance';
