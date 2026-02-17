-- Désactiver temporairement le trigger problématique
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- Recréer la fonction sans le problème de 'reason'
DROP FUNCTION IF EXISTS spend_token_on_trip_offer_acceptance();

CREATE FUNCTION spend_token_on_trip_offer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  current_balance integer;
BEGIN
  -- Seulement si le statut passe à 'accepted' et que le jeton n'a pas encore été dépensé
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') AND (NEW.token_spent IS NULL OR NEW.token_spent = false) THEN
    
    -- Récupère le solde actuel
    SELECT balance INTO current_balance
    FROM token_balances
    WHERE user_id = NEW.driver_id
    AND token_type = 'course';

    -- Vérifie si le solde est suffisant
    IF current_balance IS NULL OR current_balance < 1 THEN
      RAISE EXCEPTION 'Solde de jetons insuffisant';
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
      transaction_type,
      token_type,
      amount,
      balance_before,
      balance_after,
      reference_id,
      notes
    ) VALUES (
      NEW.driver_id,
      'debit',
      'course',
      -1,
      current_balance,
      current_balance - 1,
      NEW.trip_id,
      'trip_offer_accepted'
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recréer le trigger
CREATE TRIGGER trigger_spend_token_on_trip_offer_acceptance
  BEFORE UPDATE ON trip_offers
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_offer_acceptance();
