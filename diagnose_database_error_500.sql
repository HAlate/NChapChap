-- =========================================
-- DIAGNOSTIC: Erreur Database Error 500
-- =========================================
-- Ce script aide à identifier la cause exacte de l'erreur

-- =========================================
-- ÉTAPE 1: Vérifier l'état du trigger
-- =========================================
SELECT 
  '=== TRIGGER HANDLE_NEW_USER ===' as section;

SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ PROBLÈME: Fonction manquante'
    WHEN bool_or(prosecdef) = false THEN '⚠️ PROBLÈME: Manque SECURITY DEFINER'
    ELSE '✅ OK'
  END as status_fonction,
  COUNT(*) as nb_fonctions,
  bool_or(prosecdef) as security_definer,
  CASE 
    WHEN COUNT(*) = 0 THEN 'Exécuter: CREATE FUNCTION handle_new_user()'
    WHEN bool_or(prosecdef) = false THEN 'Ajouter SECURITY DEFINER à la fonction'
    ELSE 'Fonction correctement configurée'
  END as action_requise
FROM pg_proc 
WHERE proname = 'handle_new_user';

SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ PROBLÈME: Trigger manquant'
    WHEN MAX(tgenabled::text) != 'O' THEN '❌ PROBLÈME: Trigger désactivé'
    ELSE '✅ OK'
  END as status_trigger,
  COUNT(*) as nb_triggers,
  MAX(tgenabled::text) as enabled_status,
  CASE 
    WHEN COUNT(*) = 0 THEN 'Exécuter: CREATE TRIGGER on_auth_user_created'
    WHEN MAX(tgenabled::text) != 'O' THEN 'Activer le trigger'
    ELSE 'Trigger actif'
  END as action_requise
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- =========================================
-- ÉTAPE 2: Vérifier les politiques RLS
-- =========================================
SELECT 
  '=== POLITIQUES RLS ===' as section;

SELECT 
  relname as table_name,
  CASE 
    WHEN relrowsecurity THEN '✅ RLS Activé'
    ELSE '❌ RLS Désactivé'
  END as rls_status
FROM pg_class
WHERE relname = 'users' AND relkind = 'r';

SELECT 
  policyname,
  CASE cmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    ELSE cmd
  END as operation,
  CASE 
    WHEN policyname LIKE '%signup%' OR policyname LIKE '%insert%' THEN '✅ Policy INSERT trouvée'
    ELSE '⚠️ Vérifier les conditions'
  END as status
FROM pg_policies
WHERE tablename = 'users'
ORDER BY operation;

-- Compter les policies INSERT
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ PROBLÈME CRITIQUE: Aucune policy INSERT sur users'
    WHEN COUNT(*) > 1 THEN '⚠️ Attention: Plusieurs policies INSERT (peut causer des conflits)'
    ELSE '✅ OK: 1 policy INSERT'
  END as status_insert_policy,
  COUNT(*) as nb_policies_insert,
  CASE 
    WHEN COUNT(*) = 0 THEN 'Créer une policy INSERT permissive'
    WHEN COUNT(*) > 1 THEN 'Nettoyer les policies en double'
    ELSE 'Configuration correcte'
  END as action_requise
FROM pg_policies
WHERE tablename = 'users' 
AND cmd = 'a'; -- 'a' = INSERT

-- =========================================
-- ÉTAPE 3: Vérifier les permissions
-- =========================================
SELECT 
  '=== PERMISSIONS ===' as section;

SELECT 
  grantee,
  privilege_type,
  CASE 
    WHEN privilege_type IN ('INSERT', 'SELECT', 'UPDATE') THEN '✅ Permission nécessaire'
    ELSE '⚠️ Permission optionnelle'
  END as status
FROM information_schema.table_privileges
WHERE table_schema = 'public' 
AND table_name = 'users'
AND grantee IN ('authenticated', 'anon', 'postgres')
ORDER BY grantee, privilege_type;

-- Vérifier si les permissions manquent
SELECT 
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 FROM information_schema.table_privileges
      WHERE table_schema = 'public' 
      AND table_name = 'users'
      AND grantee IN ('authenticated', 'anon')
      AND privilege_type = 'INSERT'
    ) THEN '❌ PROBLÈME: Permission INSERT manquante pour authenticated/anon'
    ELSE '✅ OK: Permissions INSERT présentes'
  END as status_permissions,
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 FROM information_schema.table_privileges
      WHERE table_schema = 'public' 
      AND table_name = 'users'
      AND grantee IN ('authenticated', 'anon')
      AND privilege_type = 'INSERT'
    ) THEN 'Exécuter: GRANT INSERT ON users TO authenticated, anon'
    ELSE 'Permissions correctes'
  END as action_requise;

-- =========================================
-- ÉTAPE 4: Tester le trigger manuellement
-- =========================================
SELECT 
  '=== TEST MANUEL ===' as section;

-- Afficher un exemple d'utilisateur récent
SELECT 
  'Dernier utilisateur créé dans auth.users:' as info,
  au.id,
  au.email,
  au.created_at,
  CASE 
    WHEN u.id IS NOT NULL THEN '✅ Présent dans public.users'
    ELSE '❌ MANQUANT dans public.users (trigger a échoué!)'
  END as status_sync
FROM auth.users au
LEFT JOIN public.users u ON u.id = au.id
ORDER BY au.created_at DESC
LIMIT 5;

-- Compter les désynchronisations
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ OK: Tous les users auth sont dans public.users'
    ELSE '❌ PROBLÈME: ' || COUNT(*) || ' users manquants dans public.users'
  END as status_sync,
  COUNT(*) as users_manquants,
  CASE 
    WHEN COUNT(*) > 0 THEN 'Le trigger ne fonctionne pas correctement!'
    ELSE 'Synchronisation OK'
  END as diagnostic
FROM auth.users au
LEFT JOIN public.users u ON u.id = au.id
WHERE u.id IS NULL;

-- =========================================
-- ÉTAPE 5: Vérifier les erreurs récentes
-- =========================================
SELECT 
  '=== LOGS SYSTÈME ===' as section;

-- Note: Les vrais logs sont dans Supabase Dashboard > Logs
SELECT 
  'Vérifier les logs dans:' as info,
  '1. Supabase Dashboard → Project → Logs' as step_1,
  '2. Filtrer par "error" ou "handle_new_user"' as step_2,
  '3. Chercher les erreurs 500' as step_3;

-- =========================================
-- RÉSUMÉ ET RECOMMANDATIONS
-- =========================================
SELECT 
  '=== RÉSUMÉ ===' as section;

-- Diagnostic global
DO $$ 
DECLARE
  has_function boolean;
  has_trigger boolean;
  has_rls boolean;
  has_policy_insert boolean;
  has_permissions boolean;
  users_desynced int;
BEGIN
  -- Vérifications
  SELECT COUNT(*) > 0 INTO has_function FROM pg_proc WHERE proname = 'handle_new_user';
  SELECT COUNT(*) > 0 INTO has_trigger FROM pg_trigger WHERE tgname = 'on_auth_user_created';
  SELECT relrowsecurity INTO has_rls FROM pg_class WHERE relname = 'users' AND relkind = 'r';
  SELECT COUNT(*) > 0 INTO has_policy_insert FROM pg_policies WHERE tablename = 'users' AND cmd = 'a';
  SELECT COUNT(*) > 0 INTO has_permissions 
    FROM information_schema.table_privileges
    WHERE table_schema = 'public' AND table_name = 'users'
    AND grantee IN ('authenticated', 'anon') AND privilege_type = 'INSERT';
  SELECT COUNT(*) INTO users_desynced 
    FROM auth.users au LEFT JOIN public.users u ON u.id = au.id WHERE u.id IS NULL;

  -- Afficher le diagnostic
  RAISE NOTICE '==========================================';
  RAISE NOTICE 'DIAGNOSTIC COMPLET';
  RAISE NOTICE '==========================================';
  RAISE NOTICE 'Fonction handle_new_user: %', CASE WHEN has_function THEN '✅ OK' ELSE '❌ MANQUANTE' END;
  RAISE NOTICE 'Trigger on_auth_user_created: %', CASE WHEN has_trigger THEN '✅ OK' ELSE '❌ MANQUANT' END;
  RAISE NOTICE 'RLS activé sur users: %', CASE WHEN has_rls THEN '✅ OK' ELSE '❌ DÉSACTIVÉ' END;
  RAISE NOTICE 'Policy INSERT sur users: %', CASE WHEN has_policy_insert THEN '✅ OK' ELSE '❌ MANQUANTE' END;
  RAISE NOTICE 'Permissions INSERT: %', CASE WHEN has_permissions THEN '✅ OK' ELSE '❌ MANQUANTES' END;
  RAISE NOTICE 'Users désynchronisés: %', users_desynced;
  RAISE NOTICE '==========================================';
  
  IF NOT has_function OR NOT has_trigger THEN
    RAISE NOTICE '🔧 ACTION: Exécuter fix_database_error_500_new_user.sql';
  ELSIF NOT has_policy_insert THEN
    RAISE NOTICE '🔧 ACTION: Créer une policy INSERT sur users';
  ELSIF NOT has_permissions THEN
    RAISE NOTICE '🔧 ACTION: GRANT INSERT ON users TO authenticated, anon';
  ELSIF users_desynced > 0 THEN
    RAISE NOTICE '🔧 ACTION: Synchroniser les users manquants manuellement';
  ELSE
    RAISE NOTICE '✅ Configuration correcte. Si erreur persiste:';
    RAISE NOTICE '   1. Vérifier les logs Supabase Dashboard';
    RAISE NOTICE '   2. Vérifier l''app Flutter (code signup)';
    RAISE NOTICE '   3. Vérifier le format des données envoyées';
  END IF;
END $$;
