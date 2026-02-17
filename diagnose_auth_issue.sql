-- Script de diagnostic pour l'erreur "Database error querying schema"

-- 1. Vérifier si la table users existe
SELECT 
  'Table users' as check_type,
  EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'users'
  ) as exists;

-- 2. Vérifier la structure de la table users
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users'
ORDER BY ordinal_position;

-- 3. Vérifier si le trigger handle_new_user existe
SELECT 
  'Trigger handle_new_user' as check_type,
  COUNT(*) > 0 as exists
FROM pg_trigger
WHERE tgname = 'on_auth_user_created';

-- 4. Vérifier si la fonction handle_new_user() existe
SELECT 
  'Function handle_new_user' as check_type,
  COUNT(*) > 0 as exists
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'handle_new_user'
AND n.nspname = 'public';

-- 5. Vérifier les politiques RLS sur users
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users';

-- 6. Vérifier si RLS est activé sur users
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'users';

-- 7. Vérifier les types ENUM nécessaires
SELECT typname
FROM pg_type
WHERE typtype = 'e'
AND typname IN ('user_type', 'user_status', 'vehicle_type', 'payment_method', 'token_type', 'transaction_type')
ORDER BY typname;

-- 8. Vérifier si l'utilisateur test existe dans auth.users
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  raw_user_meta_data->>'phone' as phone,
  raw_user_meta_data->>'full_name' as full_name,
  raw_user_meta_data->>'user_type' as user_type
FROM auth.users
WHERE email = 'driver_111111@uumo.app';

-- 9. Vérifier si l'utilisateur existe dans public.users
SELECT 
  u.id,
  u.email,
  u.phone,
  u.full_name,
  u.user_type,
  u.created_at
FROM public.users u
WHERE u.email = 'driver_111111@uumo.app';

-- 10. Vérifier si le profil driver existe
SELECT 
  dp.id,
  dp.vehicle_type,
  dp.vehicle_brand,
  dp.vehicle_model,
  dp.vehicle_plate,
  dp.is_available,
  dp.rating,
  dp.total_trips,
  dp.token_balance
FROM driver_profiles dp
JOIN public.users u ON u.id = dp.id
WHERE u.email = 'driver_111111@uumo.app';
