-- Diagnostic approfondi du schéma auth et des extensions

-- 1. Vérifier les extensions critiques
SELECT 
  'Extensions' as check_type,
  extname,
  extversion,
  CASE 
    WHEN extname IN ('uuid-ossp', 'pgcrypto', 'pgjwt') THEN '✅ Critique pour auth'
    ELSE '⚠️ Optionnelle'
  END as importance
FROM pg_extension
WHERE extname IN ('uuid-ossp', 'pgcrypto', 'pgjwt', 'postgis')
ORDER BY extname;

-- 2. Vérifier la structure de auth.users
SELECT 
  'Colonnes auth.users' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth'
AND table_name = 'users'
ORDER BY ordinal_position;

-- 3. Vérifier les permissions sur le schéma auth
SELECT 
  'Permissions auth schema' as check_type,
  nspname as schema_name,
  nspowner::regrole as owner,
  has_schema_privilege('authenticator', nspname, 'USAGE') as authenticator_can_use
FROM pg_namespace
WHERE nspname = 'auth';

-- 4. Vérifier les fonctions dans le schéma auth
SELECT 
  'Fonctions auth' as check_type,
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'auth'
ORDER BY routine_name;

-- 5. Vérifier si l'utilisateur test peut être lu
SELECT 
  'Test user readable' as check_type,
  id,
  email,
  encrypted_password IS NOT NULL as has_password,
  email_confirmed_at IS NOT NULL as email_confirmed,
  created_at
FROM auth.users
WHERE email = 'driver_111111@uumo.app';

-- 6. Tester la fonction uuid_generate_v4()
SELECT 
  'Test uuid_generate_v4' as check_type,
  uuid_generate_v4() as generated_uuid;

-- 7. Vérifier les triggers sur auth.users (devrait être vide maintenant)
SELECT 
  'Triggers sur auth.users' as check_type,
  tgname,
  tgenabled,
  pg_get_triggerdef(oid) as definition
FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass
AND tgname NOT LIKE 'RI_ConstraintTrigger%'
ORDER BY tgname;

-- 8. Vérifier la table auth.identities
SELECT 
  'Auth identities count' as check_type,
  COUNT(*) as total
FROM auth.identities
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE 'driver_%@uumo.app'
);

-- 9. Vérifier les contraintes sur auth.users
SELECT 
  'Contraintes auth.users' as check_type,
  conname,
  contype,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'auth.users'::regclass
ORDER BY conname;

-- 10. Essayer une connexion directe via pgcrypto
SELECT 
  'Test password hash' as check_type,
  crypt('tototo', gen_salt('bf')) as hashed_password;

-- Message de diagnostic
SELECT 
  '🔍 Diagnostic terminé' as status,
  'Vérifiez les résultats ci-dessus' as instruction,
  'Recherchez les ❌ ou les erreurs' as note;
