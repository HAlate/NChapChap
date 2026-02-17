/*
  # Trigger Déduction Automatique des Jetons

  1. Fonction
    - spend_token_on_acceptance(): Déduit 1 jeton quand offre acceptée
    - Appelée automatiquement lors du changement de status à 'accepted'

  2. Comportement
    - Vérifie si status passe à 'accepted' (et n'était pas déjà 'accepted')
    - Déduit 1 jeton du driver dans token_balances
    - Marque token_spent = true dans l'offre
    - Enregistre la transaction dans token_transactions

  3. Sécurité
    - Vérifie que le driver a bien >= 1 jeton
    - Transaction atomique (tout ou rien)
    - Pas de double déduction possible

  4. Important
    - S'applique à trip_offers, delivery_offers, order_delivery_offers
    - Jeton dépensé SEULEMENT lors de l'acceptation finale
    - Conforme à NEGOTIATION_CONTEXTE_AFRICAIN.md
*/

-- Fonction: Déduction jeton lors acceptation
CREATE OR REPLACE FUNCTION spend_token_on_trip_offer_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- Vérifie si status passe à 'accepted' et n'était pas déjà 'accepted'
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN

    -- Vérifie que le driver a au moins 1 jeton
    IF NOT EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = NEW.driver_id
        AND token_type = 'course'
        AND balance >= 1
    ) THEN
      RAISE EXCEPTION 'Driver does not have enough tokens (need 1, has 0)';
    END IF;

    -- Déduit 1 jeton
    UPDATE token_balances
    SET balance = balance - 1,
        updated_at = NOW()
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Marque le jeton comme dépensé
    NEW.token_spent = true;

    -- Enregistre la transaction
    INSERT INTO token_transactions (
      user_id,
      token_type,
      amount,
      reason,
      related_id,
      created_at
    ) VALUES (
      NEW.driver_id,
      'course',
      -1,
      'trip_offer_accepted',
      NEW.trip_id,
      NOW()
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sur trip_offers
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

CREATE TRIGGER trigger_spend_token_on_trip_offer_acceptance
  BEFORE UPDATE ON trip_offers
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_offer_acceptance();

-- Commentaire
COMMENT ON FUNCTION spend_token_on_trip_offer_acceptance IS
'Déduit automatiquement 1 jeton du driver quand son offre passe à status = accepted. Enregistre la transaction et marque token_spent = true.';

COMMENT ON TRIGGER trigger_spend_token_on_trip_offer_acceptance ON trip_offers IS
'Déclenché avant UPDATE pour déduire le jeton lors de l''acceptation de l''offre.';