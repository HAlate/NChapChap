-- ============================================================================
-- Script de Configuration - Opérateurs Mobile Money
-- ============================================================================
-- Fichier: configuration_operateurs_mobile_money.sql
-- Date: 2025-12-15
-- Description: Insertion des opérateurs Mobile Money par pays
-- ============================================================================

-- ============================================================================
-- TOGO (TG)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  ussd_pattern,
  is_active
) VALUES
  ('MTN Mobile Money', '+228 XX XX XX XX', 'TG', 'Togo', '*133*1*1*{amount}*{code}#', true),
  ('Moov Money', '+228 YY YY YY YY', 'TG', 'Togo', '*555*1*{amount}*{code}#', true),
  ('Togocom Cash', '+228 ZZ ZZ ZZ ZZ', 'TG', 'Togo', '*900*1*{amount}*{code}#', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- BÉNIN (BJ)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  ussd_pattern,
  is_active
) VALUES
  ('MTN Mobile Money', '+229 XX XX XX XX', 'BJ', 'Bénin', '*133*1*1*{amount}*{code}#', true),
  ('Moov Money', '+229 YY YY YY YY', 'BJ', 'Bénin', '*555*1*{amount}*{code}#', true),
  ('Celtiis Cash', '+229 ZZ ZZ ZZ ZZ', 'BJ', 'Bénin', '*901*{amount}*{code}#', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- CÔTE D'IVOIRE (CI)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('MTN Mobile Money', '+225 XX XX XX XX XX', 'CI', 'Côte d''Ivoire', true),
  ('Moov Money', '+225 YY YY YY YY YY', 'CI', 'Côte d''Ivoire', true),
  ('Orange Money', '+225 ZZ ZZ ZZ ZZ ZZ', 'CI', 'Côte d''Ivoire', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SÉNÉGAL (SN)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('Orange Money', '+221 XX XXX XX XX', 'SN', 'Sénégal', true),
  ('Free Money', '+221 YY YYY YY YY', 'SN', 'Sénégal', true),
  ('Wave', '+221 ZZ ZZZ ZZ ZZ', 'SN', 'Sénégal', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- BURKINA FASO (BF)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('Orange Money', '+226 XX XX XX XX', 'BF', 'Burkina Faso', true),
  ('Moov Money', '+226 YY YY YY YY', 'BF', 'Burkina Faso', true),
  ('Coris Money', '+226 ZZ ZZ ZZ ZZ', 'BF', 'Burkina Faso', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- MALI (ML)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('Orange Money', '+223 XX XX XX XX', 'ML', 'Mali', true),
  ('Moov Money', '+223 YY YY YY YY', 'ML', 'Mali', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- NIGER (NE)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('Orange Money', '+227 XX XX XX XX', 'NE', 'Niger', true),
  ('Moov Money', '+227 YY YY YY YY', 'NE', 'Niger', true),
  ('Airtel Money', '+227 ZZ ZZ ZZ ZZ', 'NE', 'Niger', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- GHANA (GH)
-- ============================================================================

INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  country_name,
  is_active
) VALUES
  ('MTN Mobile Money', '+233 XXX XXX XXX', 'GH', 'Ghana', true),
  ('Vodafone Cash', '+233 YYY YYY YYY', 'GH', 'Ghana', true),
  ('AirtelTigo Money', '+233 ZZZ ZZZ ZZZ', 'GH', 'Ghana', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Vérification des insertions
-- ============================================================================

SELECT 
  country_name,
  country_code,
  COUNT(*) as nombre_operateurs
FROM mobile_money_numbers
GROUP BY country_name, country_code
ORDER BY country_name;

-- ============================================================================
-- Mise à jour des profils chauffeurs existants
-- ============================================================================

-- Attribuer pays par défaut (Togo) aux chauffeurs sans country_code
UPDATE driver_profiles 
SET country_code = 'TG' 
WHERE country_code IS NULL;

-- Vérifier la répartition des chauffeurs par pays
SELECT 
  country_code,
  COUNT(*) as nombre_chauffeurs
FROM driver_profiles
GROUP BY country_code
ORDER BY nombre_chauffeurs DESC;

-- ============================================================================
-- Requêtes de test
-- ============================================================================

-- Voir tous les opérateurs actifs par pays
SELECT 
  country_name,
  provider,
  phone_number,
  is_active
FROM mobile_money_numbers
WHERE is_active = true
ORDER BY country_name, provider;

-- Simuler la sélection pour un chauffeur du Togo
SELECT 
  id,
  provider,
  phone_number
FROM mobile_money_numbers
WHERE country_code = 'TG'
  AND is_active = true
ORDER BY provider;

-- ============================================================================
-- NOTES IMPORTANTES
-- ============================================================================

/*
⚠️ REMPLACER LES NUMÉROS DE TÉLÉPHONE

Les numéros ci-dessus (XX XX XX XX) sont des PLACEHOLDERS.
Vous devez les remplacer par les VRAIS numéros de réception des paiements.

Exemple pour MTN Togo:
  '+228 90 12 34 56' (numéro réel de l'entreprise)

🔐 SÉCURITÉ

Ces numéros seront VISIBLES par les chauffeurs dans le dropdown.
Ils doivent être des numéros dédiés à la réception de paiements.

📱 FORMAT DES NUMÉROS

- Togo: +228 XX XX XX XX (8 chiffres)
- Bénin: +229 XX XX XX XX (8 chiffres)
- Côte d'Ivoire: +225 XX XX XX XX XX (10 chiffres)
- Sénégal: +221 XX XXX XX XX (9 chiffres)
- Burkina Faso: +226 XX XX XX XX (8 chiffres)
- Mali: +223 XX XX XX XX (8 chiffres)
- Niger: +227 XX XX XX XX (8 chiffres)
- Ghana: +233 XXX XXX XXX (9 chiffres)

🎨 COULEURS PAR OPÉRATF CFA (Automatique dans l'app)

MTN      → Jaune (#FFCC00)
Moov     → Bleu (#0066CC)
Orange   → Orange (#FF6600)
Togocom  → Orange (#FF6600)
Celtiis  → Vert (#00AA00)
Airtel   → Rouge (#CC0000)
Wave     → Bleu (#0099FF)
Vodafone → Rouge (#E60000)
Coris    → Vert (#008000)
Free     → Bleu (#3366FF)

📊 ACTIVATION/DÉSACTIVATION

Pour désactiver un opérateur temporairement:
UPDATE mobile_money_numbers 
SET is_active = false 
WHERE id = '<operator-uuid>';

Pour réactiver:
UPDATE mobile_money_numbers 
SET is_active = true 
WHERE id = '<operator-uuid>';

*/
