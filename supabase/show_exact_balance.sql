-- Voir le solde exact de ce driver spécifique
SELECT 
  user_id,
  token_type,
  balance,
  updated_at
FROM token_balances
WHERE user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d';
