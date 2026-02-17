-- Donner 10 jetons au dernier driver créé
WITH driver_info AS (
  SELECT id, email, full_name 
  FROM users 
  WHERE user_type = 'driver' 
  ORDER BY created_at DESC 
  LIMIT 1
)
INSERT INTO token_balances (user_id, token_type, balance, total_purchased)
SELECT id, 'course', 10, 10 
FROM driver_info
ON CONFLICT (user_id, token_type) 
DO UPDATE SET 
  balance = token_balances.balance + 10,
  total_purchased = token_balances.total_purchased + 10,
  updated_at = now();

-- Afficher le résultat
SELECT 
  u.email,
  u.full_name,
  tb.balance as jetons_disponibles,
  tb.total_purchased as jetons_achetes
FROM users u
LEFT JOIN token_balances tb ON u.id = tb.user_id AND tb.token_type = 'course'
WHERE u.user_type = 'driver';
