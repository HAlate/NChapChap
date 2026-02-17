-- Ajouter 20 jetons à ce driver spécifique (b667cb5e-af11-4ca3-ad0b-6107c948f27d)
UPDATE token_balances
SET balance = balance + 20,
    updated_at = NOW()
WHERE user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d'
  AND token_type = 'course'
RETURNING user_id, token_type, balance as new_balance;
