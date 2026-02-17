-- Vérifier l'état de l'offre acceptée
SELECT 
  to2.id,
  to2.trip_id,
  to2.driver_id,
  to2.status,
  to2.token_spent,
  to2.offered_price,
  to2.created_at
FROM trip_offers to2
WHERE to2.id = 'd8edd0d5-7e89-469f-b311-ecad4650db74';

-- Vérifier l'état du trip
SELECT 
  t.id,
  t.status,
  t.driver_id,
  t.final_price,
  t.accepted_at
FROM trips t
WHERE t.id = '377f4378-e961-4144-8d83-a7d6e7ebd144';

-- Vérifier les jetons du driver
SELECT 
  tb.user_id,
  tb.token_type,
  tb.balance,
  tb.updated_at
FROM token_balances tb
WHERE tb.user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d'
  AND tb.token_type = 'course';

-- Vérifier la transaction
SELECT 
  tt.id,
  tt.transaction_type,
  tt.amount,
  tt.balance_before,
  tt.balance_after,
  tt.reason,
  tt.created_at
FROM token_transactions tt
WHERE tt.user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d'
ORDER BY tt.created_at DESC
LIMIT 1;
