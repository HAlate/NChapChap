-- Migration: Intégration SumUp pour paiements par carte en fin de course
-- Permet aux chauffeurs d'accepter les paiements par carte bancaire

-- Étape 1: Ajouter payment_method ENUM pour SumUp
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'payment_method' AND e.enumlabel = 'sumup'
  ) THEN
    ALTER TYPE payment_method ADD VALUE 'sumup';
  END IF;
END $$;

-- Étape 2: Créer table pour stocker les transactions SumUp
CREATE TABLE IF NOT EXISTS sumup_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid REFERENCES trips(id) ON DELETE SET NULL,
  driver_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  rider_id uuid REFERENCES users(id) ON DELETE SET NULL,
  
  -- Informations SumUp
  transaction_code text UNIQUE NOT NULL,
  sumup_transaction_id text,
  card_type text, -- visa, mastercard, amex, etc.
  card_last4 text,
  
  -- Montant
  amount_cents integer NOT NULL,
  currency text NOT NULL DEFAULT 'usd',
  tip_amount_cents integer DEFAULT 0,
  total_amount_cents integer GENERATED ALWAYS AS (amount_cents + tip_amount_cents) STORED,
  
  -- Statut
  status text NOT NULL DEFAULT 'pending', -- pending, successful, failed, refunded
  error_message text,
  
  -- Métadonnées
  sumup_metadata jsonb DEFAULT '{}'::jsonb,
  receipt_url text,
  
  -- Timestamps
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  completed_at timestamptz,
  
  -- Constraints
  CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'successful', 'failed', 'refunded')),
  CONSTRAINT valid_amount CHECK (amount_cents > 0)
);

-- Étape 3: Ajouter colonnes de paiement aux trips
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS payment_method payment_method,
  ADD COLUMN IF NOT EXISTS card_payment_amount_cents integer,
  ADD COLUMN IF NOT EXISTS card_payment_currency text,
  ADD COLUMN IF NOT EXISTS card_payment_status text CHECK (card_payment_status IN ('pending', 'successful', 'failed')),
  ADD COLUMN IF NOT EXISTS sumup_transaction_id text;

-- Étape 4: Créer index pour les recherches
CREATE INDEX IF NOT EXISTS idx_sumup_transactions_driver 
  ON sumup_transactions(driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sumup_transactions_trip 
  ON sumup_transactions(trip_id);

CREATE INDEX IF NOT EXISTS idx_sumup_transactions_status 
  ON sumup_transactions(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sumup_transactions_code 
  ON sumup_transactions(transaction_code);

CREATE INDEX IF NOT EXISTS idx_trips_sumup_transaction 
  ON trips(sumup_transaction_id);

-- Étape 5: Fonction pour créer une transaction SumUp
CREATE OR REPLACE FUNCTION create_sumup_transaction(
  p_trip_id uuid,
  p_driver_id uuid,
  p_rider_id uuid,
  p_amount_cents integer,
  p_currency text,
  p_tip_amount_cents integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_transaction_code text;
  v_transaction_id uuid;
BEGIN
  -- Générer un code de transaction unique
  v_transaction_code := 'SUMUP-' || upper(substr(md5(random()::text), 1, 8));
  
  -- Créer la transaction SumUp
  INSERT INTO sumup_transactions (
    trip_id,
    driver_id,
    rider_id,
    transaction_code,
    amount_cents,
    currency,
    tip_amount_cents,
    status
  ) VALUES (
    p_trip_id,
    p_driver_id,
    p_rider_id,
    v_transaction_code,
    p_amount_cents,
    p_currency,
    p_tip_amount_cents,
    'pending'
  )
  RETURNING id INTO v_transaction_id;
  
  -- Mettre à jour le trip
  UPDATE trips
  SET 
    payment_method = 'sumup',
    card_payment_amount_cents = p_amount_cents,
    card_payment_currency = p_currency,
    card_payment_status = 'pending'
  WHERE id = p_trip_id;
  
  RETURN jsonb_build_object(
    'transaction_id', v_transaction_id,
    'transaction_code', v_transaction_code,
    'amount_cents', p_amount_cents,
    'tip_amount_cents', p_tip_amount_cents,
    'total_amount_cents', p_amount_cents + p_tip_amount_cents,
    'currency', p_currency
  );
END;
$$;

-- Étape 6: Fonction pour confirmer une transaction SumUp
CREATE OR REPLACE FUNCTION confirm_sumup_transaction(
  p_transaction_code text,
  p_sumup_transaction_id text,
  p_card_type text DEFAULT NULL,
  p_card_last4 text DEFAULT NULL,
  p_receipt_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_transaction record;
BEGIN
  -- Récupérer la transaction
  SELECT * INTO v_transaction
  FROM sumup_transactions
  WHERE transaction_code = p_transaction_code;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction non trouvée';
  END IF;
  
  -- Vérifier que la transaction n'a pas déjà été traitée
  IF v_transaction.status = 'successful' THEN
    RAISE EXCEPTION 'Cette transaction a déjà été confirmée';
  END IF;
  
  -- Mettre à jour la transaction
  UPDATE sumup_transactions
  SET 
    status = 'successful',
    sumup_transaction_id = p_sumup_transaction_id,
    card_type = p_card_type,
    card_last4 = p_card_last4,
    receipt_url = p_receipt_url,
    completed_at = now(),
    updated_at = now()
  WHERE transaction_code = p_transaction_code;
  
  -- Mettre à jour le trip
  UPDATE trips
  SET 
    card_payment_status = 'successful',
    sumup_transaction_id = p_sumup_transaction_id,
    status = 'completed'
  WHERE id = v_transaction.trip_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction.id,
    'trip_id', v_transaction.trip_id,
    'amount_paid', v_transaction.total_amount_cents
  );
END;
$$;

-- Étape 7: Fonction pour annuler/échouer une transaction SumUp
CREATE OR REPLACE FUNCTION fail_sumup_transaction(
  p_transaction_code text,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip_id uuid;
BEGIN
  -- Mettre à jour la transaction
  UPDATE sumup_transactions
  SET 
    status = 'failed',
    error_message = p_error_message,
    updated_at = now()
  WHERE transaction_code = p_transaction_code
  RETURNING trip_id INTO v_trip_id;
  
  -- Mettre à jour le trip
  IF v_trip_id IS NOT NULL THEN
    UPDATE trips
    SET card_payment_status = 'failed'
    WHERE id = v_trip_id;
  END IF;
END;
$$;

-- Étape 8: Fonction pour calculer le montant total d'une course (avec tip optionnel)
CREATE OR REPLACE FUNCTION calculate_trip_amount(
  p_trip_id uuid,
  p_tip_percentage integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip record;
  v_base_amount_cents integer;
  v_tip_amount_cents integer;
  v_total_amount_cents integer;
BEGIN
  -- Récupérer le trip
  SELECT * INTO v_trip
  FROM trips
  WHERE id = p_trip_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Course non trouvée';
  END IF;
  
  -- Calculer le montant de base (en centimes)
  -- Pour l'exemple, utilisons 2 USD/km + 5 USD base
  v_base_amount_cents := (500 + (v_trip.distance_km * 200))::integer;
  
  -- Calculer le pourboire
  IF p_tip_percentage > 0 THEN
    v_tip_amount_cents := (v_base_amount_cents * p_tip_percentage / 100)::integer;
  ELSE
    v_tip_amount_cents := 0;
  END IF;
  
  v_total_amount_cents := v_base_amount_cents + v_tip_amount_cents;
  
  RETURN jsonb_build_object(
    'base_amount_cents', v_base_amount_cents,
    'tip_amount_cents', v_tip_amount_cents,
    'total_amount_cents', v_total_amount_cents,
    'currency', 'usd',
    'distance_km', v_trip.distance_km
  );
END;
$$;

-- Étape 9: Vue pour l'historique des paiements SumUp
CREATE OR REPLACE VIEW sumup_payment_history AS
SELECT 
  st.id,
  st.transaction_code,
  st.sumup_transaction_id,
  st.driver_id,
  d.full_name AS driver_name,
  st.rider_id,
  r.full_name AS rider_name,
  st.trip_id,
  st.amount_cents,
  st.tip_amount_cents,
  st.total_amount_cents,
  st.currency,
  st.card_type,
  st.card_last4,
  st.status,
  st.error_message,
  st.receipt_url,
  st.created_at,
  st.completed_at,
  t.departure,
  t.destination
FROM sumup_transactions st
JOIN users d ON st.driver_id = d.id
LEFT JOIN users r ON st.rider_id = r.id
LEFT JOIN trips t ON st.trip_id = t.id
ORDER BY st.created_at DESC;

-- Étape 10: Enable RLS
ALTER TABLE sumup_transactions ENABLE ROW LEVEL SECURITY;

-- Politique: Les chauffeurs voient leurs propres transactions
DROP POLICY IF EXISTS "Drivers can view own transactions" ON sumup_transactions;
CREATE POLICY "Drivers can view own transactions"
  ON sumup_transactions
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Les passagers voient leurs transactions
DROP POLICY IF EXISTS "Riders can view own transactions" ON sumup_transactions;
CREATE POLICY "Riders can view own transactions"
  ON sumup_transactions
  FOR SELECT
  TO authenticated
  USING (rider_id = auth.uid());

-- Politique: Les chauffeurs peuvent créer des transactions
DROP POLICY IF EXISTS "Drivers can create transactions" ON sumup_transactions;
CREATE POLICY "Drivers can create transactions"
  ON sumup_transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'driver'
    )
  );

-- Politique: Les chauffeurs peuvent mettre à jour leurs transactions
DROP POLICY IF EXISTS "Drivers can update own transactions" ON sumup_transactions;
CREATE POLICY "Drivers can update own transactions"
  ON sumup_transactions
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid());

-- Commentaires
COMMENT ON TABLE sumup_transactions IS 
'Stocke les transactions de paiement par carte via SumUp pour les courses.';

COMMENT ON FUNCTION create_sumup_transaction IS 
'Crée une transaction SumUp et génère un code de transaction unique.';

COMMENT ON FUNCTION confirm_sumup_transaction IS 
'Confirme une transaction SumUp réussie et met à jour le statut de la course.';

COMMENT ON FUNCTION fail_sumup_transaction IS 
'Marque une transaction SumUp comme échouée.';

COMMENT ON FUNCTION calculate_trip_amount IS 
'Calcule le montant total d''une course avec pourboire optionnel.';

COMMENT ON VIEW sumup_payment_history IS 
'Vue pour afficher l''historique des paiements SumUp avec détails du trajet.';

-- Grants
GRANT EXECUTE ON FUNCTION create_sumup_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION confirm_sumup_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION fail_sumup_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_trip_amount TO authenticated;
GRANT SELECT ON sumup_payment_history TO authenticated;
