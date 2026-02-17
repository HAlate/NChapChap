-- Voir toutes les transactions de jetons pour ce driver
SELECT 
  tt.id,
  tt.transaction_type,
  tt.token_type,
  tt.amount,
  tt.balance_before,
  tt.balance_after,
  tt.reason,
  tt.notes,
  tt.created_at
FROM token_transactions tt
WHERE tt.user_id = 'b667cb5e-af11-4ca3-ad0b-6107c948f27d'
ORDER BY tt.created_at DESC
LIMIT 20;
