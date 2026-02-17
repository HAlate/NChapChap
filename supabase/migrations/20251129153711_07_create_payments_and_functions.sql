/*
  # Migration Table Payments et Fonctions Utilitaires

  1. Types ENUM
    - payment_type_enum: trip, delivery, order, token_purchase
    - payment_status_enum: pending, processing, completed, failed, refunded

  2. Table
    - payments: Historique des paiements

  3. Fonctions Utilitaires
    - spend_driver_token(): Dépenser jeton driver de manière atomique
    - add_tokens(): Ajouter jetons de manière atomique

  4. Sécurité
    - Enable RLS
    - Utilisateurs voient leurs paiements (donnés et reçus)
*/

-- Types ENUM
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_type_enum') THEN
    CREATE TYPE payment_type_enum AS ENUM ('trip', 'delivery', 'order', 'token_purchase');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
    CREATE TYPE payment_status_enum AS ENUM ('pending', 'processing', 'completed', 'failed', 'refunded');
  END IF;
END $$;

-- Table payments
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  payer_id uuid REFERENCES users(id) NOT NULL,
  payee_id uuid REFERENCES users(id),
  
  amount int NOT NULL CHECK (amount > 0),
  payment_type payment_type_enum NOT NULL,
  payment_method payment_method NOT NULL,
  
  reference_id uuid,
  reference_type text,
  
  status payment_status_enum DEFAULT 'pending',
  transaction_id text,
  
  metadata jsonb DEFAULT '{}'::jsonb,
  
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- Index
CREATE INDEX IF NOT EXISTS idx_payments_payer ON payments(payer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_payee ON payments(payee_id, created_at DESC)
  WHERE payee_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments(reference_id, reference_type)
  WHERE reference_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id)
  WHERE transaction_id IS NOT NULL;

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Politique: Utilisateurs voient paiements donnés
DROP POLICY IF EXISTS "Users can view own payments as payer" ON payments;
CREATE POLICY "Users can view own payments as payer"
  ON payments
  FOR SELECT
  TO authenticated
  USING (payer_id = auth.uid());

-- Politique: Utilisateurs voient paiements reçus
DROP POLICY IF EXISTS "Users can view payments as payee" ON payments;
CREATE POLICY "Users can view payments as payee"
  ON payments
  FOR SELECT
  TO authenticated
  USING (payee_id = auth.uid());

-- ============================================================================
-- FONCTIONS UTILITAIRES
-- ============================================================================

-- Fonction: Dépenser jeton driver
CREATE OR REPLACE FUNCTION spend_driver_token(
  p_driver_id uuid,
  p_token_type token_type,
  p_reference_id uuid,
  p_reference_type text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance int;
  v_balance_before int;
BEGIN
  -- Vérifier le solde actuel avec verrou
  SELECT balance INTO v_balance
  FROM token_balances
  WHERE user_id = p_driver_id AND token_type = p_token_type
  FOR UPDATE;

  -- Vérifier si suffisant
  IF v_balance IS NULL OR v_balance < 1 THEN
    RAISE EXCEPTION 'Insufficient token balance';
  END IF;

  v_balance_before := v_balance;

  -- Décrémenter le solde
  UPDATE token_balances
  SET
    balance = balance - 1,
    total_spent = total_spent + 1,
    updated_at = now()
  WHERE user_id = p_driver_id AND token_type = p_token_type;

  -- Enregistrer la transaction
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
    p_driver_id,
    'spend',
    p_token_type,
    -1,
    v_balance_before,
    v_balance_before - 1,
    p_reference_id,
    'Token spent for ' || p_reference_type
  );

  RETURN true;
END;
$$;

-- Fonction: Ajouter jetons
CREATE OR REPLACE FUNCTION add_tokens(
  p_user_id uuid,
  p_token_type token_type,
  p_amount int,
  p_payment_method text DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance_before int;
BEGIN
  -- Créer balance si n'existe pas
  INSERT INTO token_balances (user_id, token_type, balance)
  VALUES (p_user_id, p_token_type, 0)
  ON CONFLICT (user_id, token_type) DO NOTHING;

  -- Obtenir balance actuel avec verrou
  SELECT balance INTO v_balance_before
  FROM token_balances
  WHERE user_id = p_user_id AND token_type = p_token_type
  FOR UPDATE;

  -- Ajouter jetons
  UPDATE token_balances
  SET
    balance = balance + p_amount,
    total_purchased = total_purchased + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id AND token_type = p_token_type;

  -- Enregistrer transaction
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    balance_before,
    balance_after,
    reference_id,
    payment_method,
    notes
  ) VALUES (
    p_user_id,
    'purchase',
    p_token_type,
    p_amount,
    v_balance_before,
    v_balance_before + p_amount,
    p_reference_id,
    p_payment_method,
    'Token purchase'
  );

  RETURN true;
END;
$$;

-- Fonction: Refund jetons
CREATE OR REPLACE FUNCTION refund_tokens(
  p_user_id uuid,
  p_token_type token_type,
  p_amount int,
  p_reference_id uuid,
  p_reason text DEFAULT 'Refund'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance_before int;
BEGIN
  -- Obtenir balance actuel avec verrou
  SELECT balance INTO v_balance_before
  FROM token_balances
  WHERE user_id = p_user_id AND token_type = p_token_type
  FOR UPDATE;

  IF v_balance_before IS NULL THEN
    v_balance_before := 0;
    -- Créer balance si n'existe pas
    INSERT INTO token_balances (user_id, token_type, balance)
    VALUES (p_user_id, p_token_type, 0)
    ON CONFLICT (user_id, token_type) DO NOTHING;
  END IF;

  -- Ajouter jetons
  UPDATE token_balances
  SET
    balance = balance + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id AND token_type = p_token_type;

  -- Enregistrer transaction
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
    p_user_id,
    'refund',
    p_token_type,
    p_amount,
    v_balance_before,
    v_balance_before + p_amount,
    p_reference_id,
    p_reason
  );

  RETURN true;
END;
$$;