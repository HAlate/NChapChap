-- Script pour donner des jetons à un driver pour les tests

-- Remplacez 'DRIVER_USER_ID' par l'ID du driver
-- Pour trouver l'ID du driver, utilisez:
-- SELECT id, email, full_name FROM users WHERE user_type = 'driver';

DO $$
DECLARE
  driver_id uuid := 'DRIVER_USER_ID'; -- Remplacez par l'ID réel du driver
  token_amount int := 10; -- Nombre de jetons à donner
BEGIN
  -- Créer ou mettre à jour le solde de jetons
  INSERT INTO token_balances (user_id, token_type, balance, total_purchased)
  VALUES (driver_id, 'course', token_amount, token_amount)
  ON CONFLICT (user_id, token_type) 
  DO UPDATE SET 
    balance = token_balances.balance + token_amount,
    total_purchased = token_balances.total_purchased + token_amount,
    updated_at = now();

  -- Enregistrer la transaction
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    balance_before,
    balance_after,
    payment_method,
    notes
  )
  SELECT 
    driver_id,
    'purchase',
    'course',
    token_amount,
    COALESCE((SELECT balance FROM token_balances WHERE user_id = driver_id AND token_type = 'course'), 0) - token_amount,
    COALESCE((SELECT balance FROM token_balances WHERE user_id = driver_id AND token_type = 'course'), 0),
    'admin',
    'Jetons de test ajoutés manuellement';

  RAISE NOTICE 'Jetons ajoutés avec succès au driver %', driver_id;
END $$;

-- Pour voir le solde actuel du driver:
-- SELECT u.email, u.full_name, tb.balance, tb.total_purchased
-- FROM users u
-- LEFT JOIN token_balances tb ON u.id = tb.user_id AND tb.token_type = 'course'
-- WHERE u.user_type = 'driver';
