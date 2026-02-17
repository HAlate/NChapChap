-- Vérifier le statut des jetons après acceptation d'offre
-- Check token balances
SELECT 
  u.email,
  dp.vehicle_type,
  tb.token_type,
  tb.balance as current_balance
FROM token_balances tb
JOIN users u ON tb.user_id = u.id
LEFT JOIN driver_profiles dp ON u.id = dp.id
WHERE tb.token_type = 'course'
ORDER BY tb.updated_at DESC;

-- Check recent token transactions
SELECT 
  tt.id,
  u.email,
  tt.transaction_type,
  tt.token_type,
  tt.amount,
  tt.balance_before,
  tt.balance_after,
  tt.reason,
  tt.notes,
  tt.created_at
FROM token_transactions tt
JOIN users u ON tt.user_id = u.id
ORDER BY tt.created_at DESC
LIMIT 10;

-- Check accepted offers
SELECT 
  to2.id,
  to2.trip_id,
  to2.driver_id,
  to2.offered_price,
  to2.status,
  to2.token_spent,
  to2.created_at,
  to2.accepted_at
FROM trip_offers to2
WHERE to2.status = 'accepted'
ORDER BY to2.created_at DESC
LIMIT 5;
