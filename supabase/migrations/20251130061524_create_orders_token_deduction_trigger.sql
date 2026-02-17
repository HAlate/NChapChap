/*
  # Trigger Déduction Jetons pour Commandes Restaurants/Marchands

  1. Contexte
    - Restaurants et marchands possèdent des jetons
    - Type de jetons: 'delivery_food' (restaurants) ou 'delivery_product' (marchands)
    - Coût: 5 jetons par commande acceptée

  2. Fonctionnement
    - Trigger déclenché quand order.status passe à 'confirmed'
    - Vérifie que le provider (restaurant/marchand) a >= 5 jetons
    - Déduit 5 jetons du provider
    - Marque provider_token_spent = true
    - Enregistre la transaction

  3. Sécurité
    - Transaction atomique
    - Vérification du solde avant déduction
    - Pas de double déduction possible
    - Distingue delivery_food (restaurant) et delivery_product (marchand)

  4. Important
    - Jeton déduit UNIQUEMENT quand commande confirmée par le provider
    - Conforme au système: 5 jetons = 1 commande
*/

-- Fonction: Déduction 5 jetons lors confirmation commande
CREATE OR REPLACE FUNCTION spend_tokens_on_order_confirmation()
RETURNS TRIGGER AS $$
DECLARE
  v_token_type token_type;
  v_current_balance int;
BEGIN
  -- Vérifie si status passe à 'confirmed' et n'était pas déjà 'confirmed'
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN

    -- Détermine le type de jeton selon le provider_type
    IF NEW.provider_type = 'restaurant' THEN
      v_token_type := 'delivery_food';
    ELSIF NEW.provider_type = 'merchant' THEN
      v_token_type := 'delivery_product';
    ELSE
      RAISE EXCEPTION 'Invalid provider_type: %', NEW.provider_type;
    END IF;

    -- Récupère le solde actuel
    SELECT balance INTO v_current_balance
    FROM token_balances
    WHERE user_id = NEW.provider_id
      AND token_type = v_token_type;

    -- Vérifie que le provider a au moins 5 jetons
    IF v_current_balance IS NULL OR v_current_balance < 5 THEN
      RAISE EXCEPTION 'Provider does not have enough tokens (need 5, has %)', COALESCE(v_current_balance, 0);
    END IF;

    -- Déduit 5 jetons
    UPDATE token_balances
    SET balance = balance - 5,
        total_spent = total_spent + 5,
        updated_at = NOW()
    WHERE user_id = NEW.provider_id
      AND token_type = v_token_type;

    -- Marque les jetons comme dépensés
    NEW.provider_token_spent = true;

    -- Enregistre la transaction
    INSERT INTO token_transactions (
      user_id,
      token_type,
      amount,
      reason,
      related_id,
      created_at
    ) VALUES (
      NEW.provider_id,
      v_token_type,
      -5,
      'order_confirmed',
      NEW.id,
      NOW()
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sur orders
DROP TRIGGER IF EXISTS trigger_spend_tokens_on_order_confirmation ON orders;

CREATE TRIGGER trigger_spend_tokens_on_order_confirmation
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION spend_tokens_on_order_confirmation();

-- Commentaires
COMMENT ON FUNCTION spend_tokens_on_order_confirmation IS
'Déduit automatiquement 5 jetons du provider (restaurant/marchand) quand la commande passe à status = confirmed. Enregistre la transaction et marque provider_token_spent = true.';

COMMENT ON TRIGGER trigger_spend_tokens_on_order_confirmation ON orders IS
'Déclenché avant UPDATE pour déduire 5 jetons lors de la confirmation de la commande par le restaurant/marchand.';
