-- =====================================================
-- INSTALLATION COMPLÈTE DU SYSTÈME DE PAIEMENT ADMIN
-- À exécuter dans l'éditeur SQL de Supabase
-- =====================================================

-- 0. Créer la table mobile_money_numbers si elle n'existe pas
CREATE TABLE IF NOT EXISTS mobile_money_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code VARCHAR(2) NOT NULL, -- TG, BJ, CI, etc.
  country_name VARCHAR(100) NOT NULL,
  provider VARCHAR(50) NOT NULL, -- MTN, Moov, Orange, Togocom, etc.
  phone_number VARCHAR(20) NOT NULL,
  account_name VARCHAR(100) NOT NULL,
  ussd_pattern TEXT, -- Ex: *133*1*1*{amount}*{code}#
  is_active BOOLEAN DEFAULT true,
  instructions TEXT,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(country_code, provider, phone_number)
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_mobile_money_numbers_country 
  ON mobile_money_numbers(country_code, is_active);

-- Ajouter quelques opérateurs par défaut
INSERT INTO mobile_money_numbers (country_code, country_name, provider, phone_number, account_name, ussd_pattern, display_order)
VALUES 
  ('TG', 'Togo', 'MTN Mobile Money', '+22890000000', 'ZedGo Services', '*133*1*1*{amount}*{code}#', 1),
  ('TG', 'Togo', 'Moov Money', '+22896000000', 'ZedGo Services', '*555*1*{amount}*{code}#', 2),
  ('TG', 'Togo', 'Togocom TPay', '+22890000000', 'ZedGo Services', '*900*1*{amount}*{code}#', 3)
ON CONFLICT (country_code, provider, phone_number) DO NOTHING;

-- 1. Créer la vue pour les achats en attente
-- Note: Cette vue est déjà créée dans 20251215_mobile_money_payment.sql
-- On la supprime d'abord puis la recrée pour compatibilité avec le dashboard
DROP VIEW IF EXISTS pending_token_purchases CASCADE;
CREATE VIEW pending_token_purchases AS
SELECT 
    tp.id,
    tp.user_id as driver_id,
    u.full_name as driver_name,
    u.phone as driver_phone,
    tp.package_id,
    pkg.name as package_name,
    tp.token_amount,
    COALESCE(tp.bonus_tokens, 0) as bonus_tokens,
    COALESCE(tp.total_tokens, tp.token_amount) as total_tokens,
    tp.price_paid,
    COALESCE(tp.transaction_fee, 0) as transaction_fee,
    COALESCE(tp.total_amount, tp.price_paid) as total_amount,
    COALESCE(mm.provider, 'Mobile Money') as mobile_money_provider,
    COALESCE(mm.phone_number, 'N/A') as mobile_money_phone,
    COALESCE(tp.sms_notification, false) as sms_notification,
    COALESCE(tp.whatsapp_notification, false) as whatsapp_notification,
    tp.payment_status as status,
    tp.created_at,
    COALESCE(tp.updated_at, tp.created_at) as updated_at
FROM token_purchases tp
LEFT JOIN users u ON tp.user_id = u.id
LEFT JOIN token_packages pkg ON tp.package_id = pkg.id
LEFT JOIN mobile_money_numbers mm ON tp.mobile_money_number_id = mm.id
WHERE tp.payment_status = 'pending'
ORDER BY tp.created_at DESC;

-- 2. Fonction pour valider un achat
-- Note: Cette fonction est déjà créée dans 20251215_mobile_money_payment.sql
-- On la supprime et recrée avec un RETURN BOOLEAN pour compatibilité dashboard
DROP FUNCTION IF EXISTS validate_token_purchase(uuid, text);
CREATE FUNCTION validate_token_purchase(
    p_purchase_id UUID,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_purchase record;
BEGIN
    -- Récupérer les détails de l'achat
    SELECT * INTO v_purchase
    FROM token_purchases
    WHERE id = p_purchase_id
    AND payment_status = 'pending';

    -- Vérifier que l'achat existe
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Achat non trouvé ou déjà traité';
    END IF;

    -- Mettre à jour le statut de l'achat
    UPDATE token_purchases
    SET 
        payment_status = 'completed',
        validated_at = NOW(),
        completed_at = NOW(),
        admin_notes = COALESCE(p_admin_notes, admin_notes)
    WHERE id = p_purchase_id;

    -- Créditer les jetons via la fonction existante
    PERFORM add_tokens(
        v_purchase.user_id,
        'course',
        COALESCE(v_purchase.total_tokens, v_purchase.token_amount),
        p_purchase_id::text
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fonction pour rejeter un achat
-- Note: cancel_token_purchase existe dans migration, on crée reject_ pour le dashboard
DROP FUNCTION IF EXISTS cancel_token_purchase(uuid, text);
CREATE FUNCTION reject_token_purchase(
    p_purchase_id UUID,
    p_reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Mettre à jour le statut de l'achat
    UPDATE token_purchases
    SET 
        payment_status = 'failed',
        admin_notes = p_reason,
        updated_at = NOW()
    WHERE id = p_purchase_id
    AND payment_status = 'pending';

    -- Vérifier que l'achat a été trouvé
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Achat non trouvé ou déjà traité';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Les colonnes existent déjà dans la table token_purchases
-- (validated_at, completed_at, admin_notes sont déjà présentes)

-- 5. Donner les permissions
GRANT SELECT ON pending_token_purchases TO authenticated;
GRANT EXECUTE ON FUNCTION validate_token_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION reject_token_purchase TO authenticated;

-- 6. Commentaires
COMMENT ON VIEW pending_token_purchases IS 
'Vue pour dashboard admin - Affiche tous les paiements en attente de validation';

COMMENT ON FUNCTION validate_token_purchase IS 
'Valide un achat de jetons et crédite le compte du chauffeur';

COMMENT ON FUNCTION reject_token_purchase IS 
'Rejette un achat de jetons avec une raison';

-- =====================================================
-- VÉRIFICATION
-- =====================================================

-- Tester la vue
SELECT COUNT(*) as achats_en_attente FROM pending_token_purchases;

-- Voir un exemple
SELECT * FROM pending_token_purchases LIMIT 1;
