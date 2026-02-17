-- ========================================
-- Script pour ajouter des jetons à un driver
-- ========================================
-- Utilisation: Remplacez les valeurs ci-dessous puis exécutez

DO $$
DECLARE
  v_driver_phone text := '111111'; -- Changez par le téléphone du driver (sans préfixe)
  v_token_amount int := 50; -- Nombre de jetons à ajouter
  v_driver_id uuid;
  v_current_balance int;
  v_new_balance int;
BEGIN
  -- Trouver l'ID du driver par son téléphone
  SELECT id INTO v_driver_id
  FROM users
  WHERE phone = v_driver_phone AND user_type = 'driver';

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Driver avec le téléphone % non trouvé', v_driver_phone;
  END IF;

  -- Récupérer le solde actuel
  SELECT COALESCE(balance, 0) INTO v_current_balance
  FROM token_balances
  WHERE user_id = v_driver_id AND token_type = 'course';

  IF v_current_balance IS NULL THEN
    v_current_balance := 0;
  END IF;

  v_new_balance := v_current_balance + v_token_amount;

  -- Créer ou mettre à jour le solde de jetons
  INSERT INTO token_balances (user_id, token_type, balance, total_purchased, updated_at)
  VALUES (v_driver_id, 'course', v_token_amount, v_token_amount, now())
  ON CONFLICT (user_id, token_type) 
  DO UPDATE SET 
    balance = token_balances.balance + v_token_amount,
    total_purchased = token_balances.total_purchased + v_token_amount,
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
    notes,
    created_at
  ) VALUES (
    v_driver_id,
    'purchase',
    'course',
    v_token_amount,
    v_current_balance,
    v_new_balance,
    'admin',
    'Jetons ajoutés manuellement pour tests',
    now()
  );

  RAISE NOTICE '✅ Ajouté % jetons au driver (téléphone: %)', v_token_amount, v_driver_phone;
  RAISE NOTICE '📊 Solde avant: %  →  Solde après: %', v_current_balance, v_new_balance;
END $$;

-- ========================================
-- Vérifier le résultat
-- ========================================
SELECT 
  u.id,
  u.phone,
  u.full_name,
  u.email,
  COALESCE(tb.balance, 0) as jetons_disponibles,
  COALESCE(tb.total_purchased, 0) as total_achetes,
  COALESCE(tb.total_spent, 0) as total_depenses,
  tb.updated_at as derniere_maj
FROM users u
LEFT JOIN token_balances tb ON u.id = tb.user_id AND tb.token_type = 'course'
WHERE u.user_type = 'driver'
ORDER BY u.phone;
