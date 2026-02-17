/*
  # Cr\u00e9ation table payments - Gestion des Paiements

  1. Nouvelle Table
    - `payments` - Historique des paiements
      - `id` (uuid, primary key)
      - `payer_id` (uuid, r\u00e9f\u00e9rence users)
      - `payee_id` (uuid, r\u00e9f\u00e9rence users, nullable)
      - `amount` (int)
      - `payment_type` (payment_type_enum)
      - `payment_method` (payment_method)
      - `reference_id` (uuid, nullable) - trip_id, order_id, ou token_transaction_id
      - `reference_type` (text) - 'trip', 'order', 'token_purchase'
      - `status` (payment_status_enum)
      - `transaction_id` (text, nullable) - ID externe (mobile money)
      - `created_at`, `processed_at`

  2. Types ENUM
    - `payment_type_enum` - Types de paiements
    - `payment_status_enum` - Statuts paiements

  3. S\u00e9curit\u00e9
    - Enable RLS sur `payments`
    - Utilisateurs voient leurs paiements (donn\u00e9s ou re\u00e7us)
    - Syst\u00e8me cr\u00e9e paiements

  4. Index
    - Index sur payer_id et status
    - Index sur reference_id et reference_type

  5. Important
    - Track tous les paiements (trajets, livraisons, jetons)
    - Statut pending → processing → completed/failed
*/

-- Cr\u00e9er types ENUM
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_type_enum') THEN
    CREATE TYPE payment_type_enum AS ENUM (
      'trip',           -- Paiement trajet
      'delivery',       -- Paiement livraison
      'order',          -- Paiement commande
      'token_purchase'  -- Achat jetons
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
    CREATE TYPE payment_status_enum AS ENUM (
      'pending',     -- En attente
      'processing',  -- En traitement
      'completed',   -- Termin\u00e9
      'failed',      -- \u00c9chou\u00e9
      'refunded'     -- Rembours\u00e9
    );
  END IF;
END $$;

-- Cr\u00e9er table payments
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  payer_id uuid REFERENCES users(id) NOT NULL,
  payee_id uuid REFERENCES users(id),
  
  amount int NOT NULL CHECK (amount > 0),
  payment_type payment_type_enum NOT NULL,
  payment_method payment_method NOT NULL,
  
  -- R\u00e9f\u00e9rence (trip, order, token transaction)
  reference_id uuid,
  reference_type text,
  
  status payment_status_enum DEFAULT 'pending',
  
  -- ID transaction externe (mobile money, etc.)
  transaction_id text,
  
  -- M\u00e9tadonn\u00e9es
  metadata jsonb DEFAULT '{}'::jsonb,
  
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_payments_payer
  ON payments(payer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_payee
  ON payments(payee_id, created_at DESC)
  WHERE payee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payments_status
  ON payments(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_reference
  ON payments(reference_id, reference_type)
  WHERE reference_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payments_transaction
  ON payments(transaction_id)
  WHERE transaction_id IS NOT NULL;

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Politique: Utilisateurs voient leurs paiements (donnés)
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

-- Politique: Syst\u00e8me cr\u00e9e paiements (via service role)
-- Note: Cette politique sera utilis\u00e9e par le backend avec service_role key