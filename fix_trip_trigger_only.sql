-- Corriger le trigger des trip_offers seulement
-- Utilise 'notes' au lieu de 'reason' et 'reference_id' au lieu de 'related_id'

CREATE OR REPLACE FUNCTION spend_token_on_trip_offer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  token_balance_record RECORD;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' AND NEW.token_spent = false THEN
    
    SELECT * INTO token_balance_record
    FROM token_balances
    WHERE user_id = NEW.driver_id
    AND token_type = 'course';

    IF NOT FOUND OR token_balance_record.balance < 1 THEN
      RAISE EXCEPTION 'Solde de jetons insuffisant pour accepter cette offre';
    END IF;

    UPDATE token_balances
    SET balance = balance - 1,
        updated_at = NOW()
    WHERE user_id = NEW.driver_id
    AND token_type = 'course';

    NEW.token_spent = true;

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
