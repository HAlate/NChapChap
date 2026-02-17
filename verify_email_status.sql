-- =========================================
-- VÉRIFICATION: Status des utilisateurs
-- =========================================

-- 1. Vérifier tous les utilisateurs @uumo.app
SELECT 
  id,
  email,
  email_confirmed_at,
  phone,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmé'
    ELSE '❌ Non confirmé'
  END as status,
  created_at
FROM auth.users
WHERE email LIKE '%@uumo.app'
ORDER BY created_at DESC;

-- 2. Forcer la confirmation pour UN utilisateur spécifique
-- Remplace '909090' par le numéro de téléphone de l'utilisateur
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email = 'rider_909090@uumo.app';

-- 3. Vérifier à nouveau
SELECT 
  email,
  email_confirmed_at,
  phone,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmé'
    ELSE '❌ Non confirmé'
  END as status
FROM auth.users
WHERE email = 'rider_909090@uumo.app';
