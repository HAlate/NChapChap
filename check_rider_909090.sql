-- Vérifier l'état de l'utilisateur rider_909090@uumo.app

-- 1. Vérifier dans auth.users
SELECT 
  'auth.users' as table_name,
  id,
  email,
  email_confirmed_at IS NOT NULL as email_confirmed,
  created_at
FROM auth.users
WHERE email = 'rider_909090@uumo.app';

-- 2. Vérifier dans auth.identities
SELECT 
  'auth.identities' as table_name,
  id,
  user_id,
  provider,
  provider_id
FROM auth.identities
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email = 'rider_909090@uumo.app'
);

-- 3. Vérifier dans public.users
SELECT 
  'public.users' as table_name,
  id,
  email,
  phone,
  full_name,
  user_type
FROM public.users
WHERE email = 'rider_909090@uumo.app';

-- 4. Si l'utilisateur n'existe pas, afficher un message
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM auth.users WHERE email = 'rider_909090@uumo.app')
    THEN '✅ Utilisateur existe dans auth.users'
    ELSE '❌ Utilisateur MANQUANT dans auth.users - doit se réinscrire'
  END as status_auth,
  CASE 
    WHEN EXISTS (SELECT 1 FROM public.users WHERE email = 'rider_909090@uumo.app')
    THEN '✅ Utilisateur existe dans public.users'
    ELSE '❌ Utilisateur MANQUANT dans public.users'
  END as status_public,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM auth.identities 
      WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'rider_909090@uumo.app')
    )
    THEN '✅ Identity existe'
    ELSE '❌ Identity MANQUANTE'
  END as status_identity;

-- 5. Solution si l'utilisateur manque
SELECT 
  '⚠️ Si l''utilisateur est manquant:' as note,
  '1. Utilisez l''écran d''inscription dans mobile_rider' as solution_1,
  '2. Créez un nouveau compte avec 909090 comme téléphone' as solution_2,
  'Ou exécutez fix_rider_909090.sql pour le recréer' as solution_3;
