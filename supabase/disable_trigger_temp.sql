-- Désactiver temporairement le trigger pour tester
ALTER TABLE trip_offers DISABLE TRIGGER trigger_spend_token_on_offer_acceptance;

-- Vérifier que le trigger est désactivé
SELECT 
  tgname,
  tgenabled
FROM pg_trigger
WHERE tgrelid = 'trip_offers'::regclass
  AND tgname = 'trigger_spend_token_on_offer_acceptance';
