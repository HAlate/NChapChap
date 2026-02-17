-- Migration: Intégration Stripe pour paiements par carte
-- Permet aux utilisateurs d'acheter des jetons via Stripe (cartes, Apple Pay, Google Pay)

-- Étape 1: Ajouter payment_method ENUM pour Stripe
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'payment_method' AND e.enumlabel = 'stripe'
  ) THEN
    ALTER TYPE payment_method ADD VALUE 'stripe';
  END IF;
END $$;

-- Étape 2: Créer table pour stocker les Payment Intents Stripe
CREATE TABLE IF NOT EXISTS stripe_payment_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  
  -- Informations Stripe
  payment_intent_id text UNIQUE NOT NULL,
  client_secret text NOT NULL,
  amount_cents integer NOT NULL, -- Montant en centimes
  currency text NOT NULL DEFAULT 'usd', -- usd, eur, gbp, etc.
  
  -- Package de jetons
  token_package_id uuid REFERENCES token_packages(id),
  token_amount integer NOT NULL,
  bonus_tokens integer DEFAULT 0,
  
  -- Statut du paiement
  status text NOT NULL DEFAULT 'pending', -- pending, succeeded, failed, canceled
  payment_method_type text, -- card, apple_pay, google_pay
  
  -- Métadonnées
  error_message text,
  stripe_metadata jsonb DEFAULT '{}'::jsonb,
  
  -- Timestamps
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  completed_at timestamptz,
  
  -- Indexes
  CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'canceled'))
);

-- Étape 3: Ajouter colonnes Stripe à token_transactions
ALTER TABLE token_transactions
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id text,
  ADD COLUMN IF NOT EXISTS payment_currency text,
  ADD COLUMN IF NOT EXISTS payment_amount_cents integer;

-- Étape 4: Créer index pour les recherches
CREATE INDEX IF NOT EXISTS idx_stripe_payment_intents_user 
  ON stripe_payment_intents(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_intents_status 
  ON stripe_payment_intents(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_intents_payment_intent_id 
  ON stripe_payment_intents(payment_intent_id);

CREATE INDEX IF NOT EXISTS idx_token_transactions_stripe 
  ON token_transactions(stripe_payment_intent_id);

-- Étape 5: Fonction pour créer un Payment Intent
CREATE OR REPLACE FUNCTION create_stripe_payment_intent(
  p_user_id uuid,
  p_token_package_id uuid,
  p_amount_cents integer,
  p_currency text,
  p_payment_intent_id text,
  p_client_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_package record;
  v_intent_id uuid;
BEGIN
  -- Récupérer les informations du package
  SELECT * INTO v_package
  FROM token_packages
  WHERE id = p_token_package_id AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Package de jetons non trouvé ou inactif';
  END IF;
  
  -- Créer le Payment Intent dans notre DB
  INSERT INTO stripe_payment_intents (
    user_id,
    payment_intent_id,
    client_secret,
    amount_cents,
    currency,
    token_package_id,
    token_amount,
    bonus_tokens,
    status
  ) VALUES (
    p_user_id,
    p_payment_intent_id,
    p_client_secret,
    p_amount_cents,
    p_currency,
    p_token_package_id,
    v_package.token_amount,
    v_package.bonus_tokens,
    'pending'
  )
  RETURNING id INTO v_intent_id;
  
  RETURN jsonb_build_object(
    'intent_id', v_intent_id,
    'payment_intent_id', p_payment_intent_id,
    'client_secret', p_client_secret,
    'amount_cents', p_amount_cents,
    'currency', p_currency,
    'token_amount', v_package.token_amount,
    'bonus_tokens', v_package.bonus_tokens
  );
END;
$$;

-- Étape 6: Fonction pour confirmer un paiement Stripe réussi
CREATE OR REPLACE FUNCTION confirm_stripe_payment(
  p_payment_intent_id text,
  p_payment_method_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_intent record;
  v_transaction_id uuid;
  v_new_balance integer;
BEGIN
  -- Récupérer le Payment Intent
  SELECT * INTO v_intent
  FROM stripe_payment_intents
  WHERE payment_intent_id = p_payment_intent_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment Intent non trouvé';
  END IF;
  
  -- Vérifier que le paiement n'a pas déjà été traité
  IF v_intent.status = 'succeeded' THEN
    RAISE EXCEPTION 'Ce paiement a déjà été traité';
  END IF;
  
  -- Mettre à jour le statut du Payment Intent
  UPDATE stripe_payment_intents
  SET 
    status = 'succeeded',
    payment_method_type = p_payment_method_type,
    completed_at = now(),
    updated_at = now()
  WHERE payment_intent_id = p_payment_intent_id;
  
  -- Créer la transaction de jetons
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    payment_method,
    stripe_payment_intent_id,
    payment_currency,
    payment_amount_cents,
    description
  ) VALUES (
    v_intent.user_id,
    'purchase',
    'course', -- Par défaut, adapter selon le package
    v_intent.token_amount + v_intent.bonus_tokens,
    'stripe',
    p_payment_intent_id,
    v_intent.currency,
    v_intent.amount_cents,
    format('Achat de %s jetons (+%s bonus) via Stripe', 
           v_intent.token_amount, 
           v_intent.bonus_tokens)
  )
  RETURNING id INTO v_transaction_id;
  
  -- Mettre à jour le solde de jetons
  INSERT INTO token_balances (user_id, token_type, balance)
  VALUES (v_intent.user_id, 'course', v_intent.token_amount + v_intent.bonus_tokens)
  ON CONFLICT (user_id, token_type)
  DO UPDATE SET 
    balance = token_balances.balance + v_intent.token_amount + v_intent.bonus_tokens,
    updated_at = now()
  RETURNING balance INTO v_new_balance;
  
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'tokens_added', v_intent.token_amount + v_intent.bonus_tokens,
    'new_balance', v_new_balance
  );
END;
$$;

-- Étape 7: Fonction pour annuler un paiement
CREATE OR REPLACE FUNCTION cancel_stripe_payment(
  p_payment_intent_id text,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE stripe_payment_intents
  SET 
    status = 'failed',
    error_message = p_error_message,
    updated_at = now()
  WHERE payment_intent_id = p_payment_intent_id;
END;
$$;

-- Étape 8: Mettre à jour les prix des packages pour le marché international
-- Convertir les prix FCFA en USD (approximativement 1 USD = 600 FCFA)
UPDATE token_packages
SET 
  price_fcfa = CASE name
    WHEN 'Starter Pack' THEN 500  -- ~5 USD
    WHEN 'Pro Pack' THEN 1000     -- ~10 USD
    WHEN 'Premium Pack' THEN 2000 -- ~20 USD
    ELSE price_fcfa
  END
WHERE name IN ('Starter Pack', 'Pro Pack', 'Premium Pack');

-- Ajouter une colonne pour le prix en USD (centimes)
ALTER TABLE token_packages
  ADD COLUMN IF NOT EXISTS price_usd_cents integer;

-- Définir les prix en USD
UPDATE token_packages
SET price_usd_cents = CASE name
  WHEN 'Starter Pack' THEN 500   -- 5.00 USD
  WHEN 'Pro Pack' THEN 1000      -- 10.00 USD
  WHEN 'Premium Pack' THEN 2000  -- 20.00 USD
  ELSE 500
END;

-- Étape 9: Enable RLS
ALTER TABLE stripe_payment_intents ENABLE ROW LEVEL SECURITY;

-- Politique: Les utilisateurs voient leurs propres Payment Intents
DROP POLICY IF EXISTS "Users can view own payment intents" ON stripe_payment_intents;
CREATE POLICY "Users can view own payment intents"
  ON stripe_payment_intents
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Politique: Les utilisateurs peuvent créer leurs propres Payment Intents
DROP POLICY IF EXISTS "Users can create own payment intents" ON stripe_payment_intents;
CREATE POLICY "Users can create own payment intents"
  ON stripe_payment_intents
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Étape 10: Vue pour l'historique des paiements Stripe
CREATE OR REPLACE VIEW stripe_payment_history AS
SELECT 
  spi.id,
  spi.user_id,
  u.full_name,
  u.email,
  spi.payment_intent_id,
  spi.amount_cents,
  spi.currency,
  spi.token_amount,
  spi.bonus_tokens,
  spi.status,
  spi.payment_method_type,
  spi.error_message,
  spi.created_at,
  spi.completed_at,
  tp.name AS package_name
FROM stripe_payment_intents spi
JOIN users u ON spi.user_id = u.id
LEFT JOIN token_packages tp ON spi.token_package_id = tp.id
ORDER BY spi.created_at DESC;

-- Commentaires
COMMENT ON TABLE stripe_payment_intents IS 
'Stocke les Payment Intents Stripe pour l''achat de jetons. Synchronisé avec l''API Stripe.';

COMMENT ON FUNCTION create_stripe_payment_intent IS 
'Crée un Payment Intent dans notre DB après création sur Stripe.';

COMMENT ON FUNCTION confirm_stripe_payment IS 
'Confirme un paiement Stripe réussi et crédite les jetons à l''utilisateur. Appelé par webhook.';

COMMENT ON FUNCTION cancel_stripe_payment IS 
'Marque un paiement Stripe comme échoué. Appelé par webhook.';

COMMENT ON VIEW stripe_payment_history IS 
'Vue pour afficher l''historique des paiements Stripe avec infos utilisateur.';

-- Grants
GRANT EXECUTE ON FUNCTION create_stripe_payment_intent TO authenticated;
GRANT EXECUTE ON FUNCTION confirm_stripe_payment TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_stripe_payment TO authenticated;
GRANT SELECT ON stripe_payment_history TO authenticated;
