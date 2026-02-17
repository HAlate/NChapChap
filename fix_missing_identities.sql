-- Fix critique: Créer les identities manquantes dans auth.identities
-- Supabase Auth nécessite une entrée dans auth.identities pour chaque user

-- 1. Vérifier les identities existantes
SELECT 
  'État actuel' as status,
  COUNT(DISTINCT au.id) as total_users,
  COUNT(DISTINCT ai.user_id) as users_with_identity,
  COUNT(DISTINCT au.id) - COUNT(DISTINCT ai.user_id) as missing_identities
FROM auth.users au
LEFT JOIN auth.identities ai ON ai.user_id = au.id
WHERE au.email LIKE 'driver_%@uumo.app';

-- 2. Créer les identities manquantes pour les drivers de test
INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT 
  gen_random_uuid(),
  au.id,
  au.id::text,  -- provider_id doit être l'ID utilisateur pour provider 'email'
  jsonb_build_object(
    'sub', au.id::text,
    'email', au.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  NOW(),
  au.created_at,
  NOW()
FROM auth.users au
WHERE au.email LIKE 'driver_%@uumo.app'
AND NOT EXISTS (
  SELECT 1 
  FROM auth.identities ai 
  WHERE ai.user_id = au.id 
  AND ai.provider = 'email'
);

-- 3. Vérifier que toutes les identities sont créées
SELECT 
  'Vérification' as status,
  au.email,
  au.id as user_id,
  ai.id as identity_id,
  ai.provider,
  CASE 
    WHEN ai.id IS NOT NULL THEN '✅ Identity existe'
    ELSE '❌ Identity manquante'
  END as identity_status
FROM auth.users au
LEFT JOIN auth.identities ai ON ai.user_id = au.id AND ai.provider = 'email'
WHERE au.email LIKE 'driver_%@uumo.app'
ORDER BY au.email;

-- 4. Confirmer que l'email est vérifié
UPDATE auth.users
SET 
  email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
  confirmation_token = NULL,
  confirmation_sent_at = NULL
WHERE email LIKE 'driver_%@uumo.app'
AND email_confirmed_at IS NULL;

-- 5. Vérifier le statut final
SELECT 
  u.email,
  u.email_confirmed_at IS NOT NULL as email_confirmed,
  i.provider,
  i.identity_data->>'email_verified' as email_verified_in_identity,
  pu.user_type,
  dp.vehicle_type
FROM auth.users u
LEFT JOIN auth.identities i ON i.user_id = u.id AND i.provider = 'email'
LEFT JOIN public.users pu ON pu.id = u.id
LEFT JOIN driver_profiles dp ON dp.id = u.id
WHERE u.email = 'driver_111111@uumo.app';

-- 6. Message final
SELECT 
  '✅ Identities créées!' as status,
  'Relancez l''app et essayez: 111111 / tototo' as instruction,
  'L''erreur "Database error querying schema" devrait disparaître' as note;
