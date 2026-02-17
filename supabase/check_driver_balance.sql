-- Vérifier UNIQUEMENT les soldes de jetons
SELECT 
  u.id as user_id,
  u.email,
  tb.token_type,
  tb.balance,
  tb.updated_at
FROM users u
LEFT JOIN token_balances tb ON u.id = tb.user_id
WHERE u.email = '97123456@driver.app';

-- Vérifier si ce driver a une ligne dans token_balances
SELECT COUNT(*) as count_token_balances
FROM token_balances
WHERE user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d';
