-- =========================================
-- VÉRIFICATION COMPLÈTE DU SYSTÈME D'INSCRIPTION
-- =========================================

-- 1. Vérifier que le trigger existe et est activé
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  CASE tgenabled
    WHEN 'O' THEN '✅ Activé'
    WHEN 'D' THEN '❌ Désactivé'
    ELSE '⚠️ Inconnu'
  END as status
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- 2. Vérifier les politiques RLS sur la table users
SELECT 
  polname as policy_name,
  polcmd as command,
  CASE polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    ELSE 'ALL'
  END as operation
FROM pg_policy
WHERE polrelid = 'public.users'::regclass
ORDER BY polcmd;

-- 3. Vérifier la structure de la table users
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- 4. Test: Vérifier les utilisateurs existants
SELECT 
  id,
  email,
  phone,
  full_name,
  user_type,
  created_at
FROM public.users
ORDER BY created_at DESC
LIMIT 5;
