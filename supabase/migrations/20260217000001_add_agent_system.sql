-- Add agent to user_type
ALTER TYPE user_type ADD VALUE IF NOT EXISTS 'agent';

-- Insert Packages
-- We use ON CONFLICT DO NOTHING or check existence to avoid duplicates if run multiple times
INSERT INTO token_packages (name, token_type, token_amount, price_fcfa, bonus_tokens, is_active)
SELECT 'Pack Standard', 'course', 10, 200, 0, true
WHERE NOT EXISTS (SELECT 1 FROM token_packages WHERE price_fcfa = 200 AND token_amount = 10);

INSERT INTO token_packages (name, token_type, token_amount, price_fcfa, bonus_tokens, is_active)
SELECT 'Pack Premium', 'course', 50, 1000, 10, true
WHERE NOT EXISTS (SELECT 1 FROM token_packages WHERE price_fcfa = 1000 AND token_amount = 50);

-- Function for Agent to Sell Tokens
CREATE OR REPLACE FUNCTION agent_sell_tokens(
  p_driver_phone text,
  p_package_id uuid
)
RETURNS jsonb AS 
DECLARE
  v_driver_id uuid;
  v_package record;
  v_agent_id uuid;
  v_total_tokens int;
  v_new_balance int;
BEGIN
  v_agent_id := auth.uid();
  
  -- Check if caller is agent
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_agent_id AND user_type = 'agent') THEN
    RAISE EXCEPTION 'Unauthorized: Only agents can perform this action';
  END IF;

  -- Get Driver
  SELECT id INTO v_driver_id FROM users WHERE phone = p_driver_phone AND user_type = 'driver';
  
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Driver not found with phone %', p_driver_phone;
  END IF;

  -- Get Package
  SELECT * INTO v_package FROM token_packages WHERE id = p_package_id;
  
  IF v_package IS NULL THEN
    RAISE EXCEPTION 'Package not found';
  END IF;

  v_total_tokens := v_package.token_amount + COALESCE(v_package.bonus_tokens, 0);

  -- Credit Driver
  INSERT INTO token_balances (user_id, token_type, balance)
  VALUES (v_driver_id, v_package.token_type, v_total_tokens)
  ON CONFLICT (user_id, token_type)
  DO UPDATE SET balance = token_balances.balance + EXCLUDED.balance
  RETURNING balance INTO v_new_balance;

  -- Record Transaction
  INSERT INTO token_transactions (
    user_id, 
    token_type, 
    amount, 
    balance_before,
    balance_after,
    transaction_type, 
    notes,
    payment_method
  ) VALUES (
    v_driver_id,
    v_package.token_type,
    v_total_tokens,
    v_new_balance - v_total_tokens,
    v_new_balance,
    'purchase',
    'Achat via Agent ' || v_agent_id,
    'cash'
  );

  -- Record Purchase History (Optional but good for tracking)
  INSERT INTO token_purchases (
    user_id,
    package_id,
    token_type,
    token_amount,
    price_paid,
    payment_method,
    payment_status,
    completed_at
  ) VALUES (
    v_driver_id,
    v_package.id,
    v_package.token_type,
    v_total_tokens,
    v_package.price_fcfa,
    'cash',
    'completed',
    now()
  );

  RETURN jsonb_build_object(
    'success', true, 
    'driver_phone', p_driver_phone,
    'tokens_added', v_total_tokens,
    'new_balance', v_new_balance
  );
END;
 LANGUAGE plpgsql SECURITY DEFINER;
