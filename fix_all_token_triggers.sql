-- Corriger TOUS les triggers qui utilisent 'reason' et 'related_id' 
-- Ces colonnes n'existent pas, il faut utiliser 'notes' et 'reference_id'

-- 1. Corriger le trigger des trip_offers
CREATE OR REPLACE FUNCTION spend_token_on_trip_offer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  token_balance_record RECORD;
BEGIN
  -- Seulement si le statut passe à 'accepted' et que le jeton n'a pas encore été dépensé
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' AND NEW.token_spent = false THEN
    
    -- Vérifie le solde de jetons
    SELECT * INTO token_balance_record
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    IF NOT FOUND OR token_balance_record.balance < 1 THEN
      RAISE EXCEPTION 'Solde de jetons insuffisant pour accepter cette offre';
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
      token_balance_record.balance,
      token_balance_record.balance - 1,
      NEW.trip_id,
      'trip_offer_accepted'
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Corriger le trigger des orders
CREATE OR REPLACE FUNCTION spend_token_on_order_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  token_balance_record RECORD;
BEGIN
  -- Seulement si le statut passe à 'accepted' et que le jeton n'a pas encore été dépensé
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' AND NEW.token_spent = false THEN
    
    -- Vérifie le solde de jetons
    SELECT * INTO token_balance_record
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'livraison';

    IF NOT FOUND OR token_balance_record.balance < 1 THEN
      RAISE EXCEPTION 'Solde de jetons insuffisant pour accepter cette commande';
    END IF;

    -- Déduit 1 jeton
    UPDATE token_balances
    SET balance = balance - 1,
        updated_at = NOW()
    WHERE user_id = NEW.driver_id
      AND token_type = 'livraison';

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
      'livraison',
      -1,
      token_balance_record.balance,
      token_balance_record.balance - 1,
      NEW.id,
      'order_accepted'
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
