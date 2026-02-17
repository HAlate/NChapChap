/*
  # Migration Tables Jetons

  1. Tables
    - token_packages: Packages de jetons disponibles à l'achat
    - token_balances: Soldes de jetons par utilisateur
    - token_transactions: Historique des transactions de jetons

  2. Sécurité
    - Enable RLS sur toutes les tables
    - Utilisateurs voient uniquement leurs propres données
    - Packages visibles par tous

  3. Important
    - Balance ne peut jamais être négatif
    - Transactions enregistrent balance avant/après
*/

-- Table token_packages
CREATE TABLE IF NOT EXISTS token_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  name text NOT NULL,
  token_type token_type NOT NULL,
  token_amount int NOT NULL CHECK (token_amount > 0),
  price_fcfa int NOT NULL CHECK (price_fcfa > 0),
  bonus_tokens int DEFAULT 0 CHECK (bonus_tokens >= 0),
  
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_token_packages_active ON token_packages(token_type, is_active)
  WHERE is_active = true;

-- Enable RLS
ALTER TABLE token_packages ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde voit packages actifs
DROP POLICY IF EXISTS "Anyone can view active token packages" ON token_packages;
CREATE POLICY "Anyone can view active token packages"
  ON token_packages
  FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Table token_balances
CREATE TABLE IF NOT EXISTS token_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  user_id uuid REFERENCES users(id) NOT NULL,
  token_type token_type NOT NULL,
  
  balance int DEFAULT 0 CHECK (balance >= 0),
  total_purchased int DEFAULT 0,
  total_spent int DEFAULT 0,
  
  updated_at timestamptz DEFAULT now(),
  
  UNIQUE(user_id, token_type)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_token_balances_user ON token_balances(user_id, token_type);

-- Enable RLS
ALTER TABLE token_balances ENABLE ROW LEVEL SECURITY;

-- Politique: Utilisateurs voient leur solde
DROP POLICY IF EXISTS "Users can view own token balance" ON token_balances;
CREATE POLICY "Users can view own token balance"
  ON token_balances
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Table token_transactions
CREATE TABLE IF NOT EXISTS token_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  user_id uuid REFERENCES users(id) NOT NULL,
  transaction_type transaction_type NOT NULL,
  token_type token_type NOT NULL,
  
  amount int NOT NULL,
  balance_before int NOT NULL,
  balance_after int NOT NULL,
  
  reference_id uuid,
  payment_method text,
  notes text,
  
  created_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_token_transactions_user ON token_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_transactions_type ON token_transactions(transaction_type, created_at DESC);

-- Enable RLS
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;

-- Politique: Utilisateurs voient leurs transactions
DROP POLICY IF EXISTS "Users can view own token transactions" ON token_transactions;
CREATE POLICY "Users can view own token transactions"
  ON token_transactions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());