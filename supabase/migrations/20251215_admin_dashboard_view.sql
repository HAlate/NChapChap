DROP VIEW IF EXISTS pending_token_purchases CASCADE;

CREATE OR REPLACE VIEW pending_token_purchases AS
SELECT 
    tp.id,
    tp.user_id,
    u.full_name as user_name,
    u.phone as user_phone,
    u.user_type,
    tp.package_id,
    pkg.name as package_name,
    tp.token_type,
    tp.token_amount,
    tp.price_paid,
    tp.currency_code,
    tp.payment_method,
    tp.payment_status as status,
    tp.created_at,
    tp.completed_at
FROM token_purchases tp
LEFT JOIN users u ON tp.user_id = u.id
LEFT JOIN token_packages pkg ON tp.package_id = pkg.id
WHERE tp.payment_status = 'pending'
ORDER BY tp.created_at DESC;

COMMENT ON VIEW pending_token_purchases IS 
'Vue pour dashboard admin - Affiche tous les achats de jetons en attente avec les détails de l''utilisateur et du package';