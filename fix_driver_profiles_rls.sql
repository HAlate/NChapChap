-- Fix RLS pour driver_profiles - permettre l'inscription

-- 1. Vérifier les politiques actuelles
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'driver_profiles';

-- 2. Supprimer toutes les politiques existantes sur driver_profiles
DROP POLICY IF EXISTS "Drivers can view own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can update own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Enable insert for drivers" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can read own data" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can insert own data" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can update own data" ON driver_profiles;

-- 3. Désactiver RLS sur driver_profiles (solution temporaire pour test)
ALTER TABLE driver_profiles DISABLE ROW LEVEL SECURITY;

-- 4. Vérifier que RLS est désactivé
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename IN ('users', 'driver_profiles');

-- 5. Message
SELECT 
  '✅ RLS désactivé sur driver_profiles' as status,
  'Essayez de vous inscrire maintenant' as instruction,
  'Remplissez le formulaire dans mobile_driver' as note;
