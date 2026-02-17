-- =========================================
-- DIAGNOSTIC: Invalid credentials
-- =========================================

-- 1. Vérifier si l'utilisateur existe dans auth.users
SELECT 
  id,
  email,
  phone,
  email_confirmed_at,
  created_at,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Email confirmé'
    ELSE '❌ Email non confirmé'
  END as email_status,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email = 'rider_909090@uumo.app';

-- 2. Vérifier dans public.users
SELECT 
  id,
  email,
  phone,
  full_name,
  user_type,
  status,
  created_at
FROM public.users
WHERE email = 'rider_909090@uumo.app'
   OR phone = '909090';

-- =========================================
-- SOLUTION 1: Réinitialiser le mot de passe
-- =========================================
-- Si l'utilisateur existe mais le mot de passe ne fonctionne pas,
-- supprime-le et réinscris-toi

-- Supprimer l'utilisateur (ATTENTION: données perdues)
-- DELETE FROM auth.users WHERE email = 'rider_909090@uumo.app';
-- DELETE FROM public.users WHERE email = 'rider_909090@uumo.app';

-- =========================================
-- SOLUTION 2: Créer un nouvel utilisateur de test
-- =========================================
-- Utilise un autre numéro de téléphone pour tester

-- Dans l'app, inscris-toi avec :
-- Téléphone: 123456789
-- Mot de passe: Test1234!
-- Nom: Test User

-- =========================================
-- SOLUTION 3: Vérifier le format de connexion
-- =========================================
-- L'app doit utiliser exactement:
-- Email: rider_909090@uumo.app
-- Password: [le mot de passe que tu as utilisé lors de l'inscription]

-- Si tu as oublié le mot de passe, tu dois supprimer l'utilisateur
-- et te réinscrire avec les mêmes identifiants
