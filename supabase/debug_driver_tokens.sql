-- Vérifier le solde exact du driver qui fait l'offre
SELECT 
  u.id as user_id,
  u.email,
  tb.token_type,
  tb.balance,
  tb.updated_at
FROM users u
LEFT JOIN token_balances tb ON u.id = tb.user_id
WHERE u.email LIKE '%@driver.app'
ORDER BY u.created_at DESC;

-- Vérifier l'offre en question
SELECT 
  to2.id as offer_id,
  to2.trip_id,
  to2.driver_id,
  to2.status,
  to2.token_spent,
  u.email as driver_email
FROM trip_offers to2
JOIN users u ON to2.driver_id = u.id
WHERE to2.id = 'd8edd0d5-7e89-469f-b311-ecad4650db74';
