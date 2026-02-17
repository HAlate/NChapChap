/*
  # Ajout Tables Achats de Jetons et Transactions

  1. Contexte
    - Les tables token_packages existent déjà
    - Ajout des tables pour gérer achats et transactions de paiement
    - Fonction pour confirmer paiement et créditer jetons automatiquement
    - Adapté pour paiements modernes (Stripe, PayPal, etc.)

  2. Tables Ajoutées
    - token_purchases - Historique achats de jetons
    - payment_transactions - Transactions de paiement détaillées

  3. Workflow
    - User initie achat → token_purchases (pending)
    - Transaction créée → payment_transactions (pending)
    - Paiement confirmé (webhook) → confirm_payment_and_credit_tokens()
    - Jetons crédités automatiquement
*/

-- ============================================
-- ENUM: Statut Paiement (si pas déjà existant)
-- ============================================

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed',
    'cancelled',
    'refunded'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- TABLE: token_purchases
-- ============================================

CREATE TABLE IF NOT EXISTS token_purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  user_id uuid NOT NULL REFERENCES users(id),
  package_id uuid NOT NULL REFERENCES token_packages(id),
  
  token_type token_type NOT NULL,
  token_amount int NOT NULL,
  
  price_paid int NOT NULL,
  currency_code text NOT NULL DEFAULT 'USD',
  
  payment_method payment_method NOT NULL,
  payment_status payment_status DEFAULT 'pending',
  
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_token_purchases_user ON token_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_token_purchases_status ON token_purchases(payment_status);
CREATE INDEX IF NOT EXISTS idx_token_purchases_created ON token_purchases(created_at DESC);

-- ============================================
-- TABLE: payment_transactions
-- ============================================

CREATE TABLE IF NOT EXISTS payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  purchase_id uuid NOT NULL REFERENCES token_purchases(id),
  user_id uuid NOT NULL REFERENCES users(id),
  
  amount int NOT NULL,
  currency_code text NOT NULL DEFAULT 'USD',
  
  payment_method payment_method NOT NULL,
  
  -- Payment provider details (Stripe, PayPal, etc.)
  payment_provider text, -- 'stripe', 'paypal', 'apple_pay', 'google_pay'
  provider_payment_id text, -- ID du paiement chez le provider
  provider_customer_id text, -- ID client chez le provider
  
  -- Transaction IDs
  transaction_ref text UNIQUE,
  external_transaction_id text,
  
  status payment_status DEFAULT 'pending',
  
  -- Timestamps
  initiated_at timestamptz DEFAULT now(),
  processed_at timestamptz,
  completed_at timestamptz,
  
  -- Metadata
  metadata jsonb,
  notes text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_tx_purchase ON payment_transactions(purchase_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_user ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_tx_ref ON payment_transactions(transaction_ref);

-- ============================================
-- FUNCTION: Générer référence transaction
-- ============================================

CREATE OR REPLACE FUNCTION generate_transaction_ref()
RETURNS text AS $$
DECLARE
  v_timestamp text;
  v_random text;
BEGIN
  v_timestamp := TO_CHAR(NOW(), 'YYYYMMDDHH24MISS');
  v_random := UPPER(SUBSTRING(MD5(RANDOM()::text) FROM 1 FOR 6));
  RETURN 'TXN-' || v_timestamp || '-' || v_random;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Confirmer paiement et créditer jetons
-- ============================================

CREATE OR REPLACE FUNCTION confirm_payment_and_credit_tokens(
  p_transaction_ref text,
  p_external_transaction_id text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_transaction record;
  v_purchase record;
  v_new_balance int;
BEGIN
  -- Récupérer transaction
  SELECT * INTO v_transaction
  FROM payment_transactions
  WHERE transaction_ref = p_transaction_ref
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found: %', p_transaction_ref;
  END IF;
  
  IF v_transaction.status != 'pending' THEN
    RAISE EXCEPTION 'Transaction already processed: %', v_transaction.status;
  END IF;
  
  -- Récupérer purchase
  SELECT * INTO v_purchase
  FROM token_purchases
  WHERE id = v_transaction.purchase_id
  FOR UPDATE;
  
  -- Mettre à jour transaction
  UPDATE payment_transactions
  SET 
    status = 'completed',
    external_transaction_id = p_external_transaction_id,
    processed_at = now(),
    completed_at = now(),
    updated_at = now()
  WHERE id = v_transaction.id;
  
  -- Mettre à jour purchase
  UPDATE token_purchases
  SET 
    payment_status = 'completed',
    completed_at = now()
  WHERE id = v_purchase.id;
  
  -- Créditer jetons
  INSERT INTO token_balances (user_id, token_type, balance)
  VALUES (v_purchase.user_id, v_purchase.token_type, v_purchase.token_amount)
  ON CONFLICT (user_id, token_type)
  DO UPDATE SET balance = token_balances.balance + v_purchase.token_amount
  RETURNING balance INTO v_new_balance;
  
  -- Enregistrer transaction jetons
  INSERT INTO token_transactions (
    user_id,
    token_type,
    amount,
    transaction_type,
    description,
    metadata
  ) VALUES (
    v_purchase.user_id,
    v_purchase.token_type,
    v_purchase.token_amount,
    'purchase',
    'Achat de jetons - ' || p_transaction_ref,
    jsonb_build_object(
      'purchase_id', v_purchase.id,
      'transaction_ref', p_transaction_ref,
      'package_id', v_purchase.package_id,
      'external_transaction_id', p_external_transaction_id
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_purchase.user_id,
    'token_type', v_purchase.token_type,
    'tokens_credited', v_purchase.token_amount,
    'new_balance', v_new_balance,
    'transaction_ref', p_transaction_ref
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Token Purchases: Users see only their purchases
ALTER TABLE token_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own purchases" ON token_purchases;
CREATE POLICY "Users can view own purchases"
  ON token_purchases FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own purchases" ON token_purchases;
CREATE POLICY "Users can create own purchases"
  ON token_purchases FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Payment Transactions: Users see only their transactions
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own transactions" ON payment_transactions;
CREATE POLICY "Users can view own transactions"
  ON payment_transactions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================
-- COMMENTAIRES
-- ============================================

COMMENT ON TABLE token_purchases IS
'Historique des achats de jetons effectués par les utilisateurs (drivers, restaurants, marchands)';

COMMENT ON TABLE payment_transactions IS
'Transactions de paiement détaillées avec références Mobile Money et statuts de traitement';

COMMENT ON FUNCTION generate_transaction_ref IS
'Génère une référence unique pour identifier une transaction de paiement';

COMMENT ON FUNCTION confirm_payment_and_credit_tokens IS
'Confirme un paiement (Stripe, PayPal, etc.) et crédite automatiquement les jetons au compte utilisateur. Appelée après webhook de confirmation du provider';
