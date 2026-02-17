-- SOLUTION RADICALE : Désactiver complètement le trigger
-- Cela permet d'accepter les offres sans déduction de jetons temporairement

-- 1. Désactiver le trigger
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- 2. Supprimer toutes les versions de la fonction
DROP FUNCTION IF EXISTS spend_token_on_trip_offer_acceptance() CASCADE;

-- Vérifier que tout est bien supprimé
SELECT * FROM pg_trigger WHERE tgname LIKE '%token%';
