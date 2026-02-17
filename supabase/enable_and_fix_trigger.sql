-- Réactiver le trigger
ALTER TABLE trip_offers ENABLE TRIGGER trigger_spend_token_on_offer_acceptance;

-- Recréer la fonction avec SECURITY DEFINER pour bypasser RLS
CREATE OR REPLACE FUNCTION spend_token_on_offer_acceptance()
RETURNS TRIGGER 
SECURITY DEFINER -- Exécute avec les permissions du créateur, pas de l'appelant
LANGUAGE plpgsql
AS $$
DECLARE
  current_balance INT;
BEGIN
  -- Vérifie si status passe à 'accepted'
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN

    -- Récupère le solde actuel (bypass RLS)
    SELECT balance INTO current_balance
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Vérifie les jetons
    IF current_balance IS NULL OR current_balance < 1 THEN
      RAISE EXCEPTION 'Driver does not have enough tokens (need 1, has %)', COALESCE(current_balance, 0);
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
      reason,
      related_id,
      notes,
      created_at
    ) VALUES (
      NEW.driver_id,
      'spend',
      'course',
      -1,
      current_balance,
      current_balance - 1,
      NEW.trip_id,
      'trip_offer_accepted',
      NEW.trip_id,
      'Token spent for accepting trip offer',
      NOW()
    );

  END IF;

  RETURN NEW;
END;
$$;
