-- Ajouter 10 jetons au driver le plus récent
WITH latest_driver AS (
  SELECT id, email
  FROM users
  WHERE email LIKE '%@driver.app'
  ORDER BY created_at DESC
  LIMIT 1
)
UPDATE token_balances
SET balance = balance + 10,
    updated_at = NOW()
FROM latest_driver
WHERE token_balances.user_id = latest_driver.id
  AND token_balances.token_type = 'course'
RETURNING 
  (SELECT email FROM latest_driver) as driver_email,
  token_type,
  balance as new_balance;
