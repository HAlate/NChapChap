-- ============================================================================
-- GUIDE: SUPPRESSION D'UTILISATEURS - CHAPCHAP
-- ============================================================================
-- ⚠️  ATTENTION: Ces opérations sont IRRÉVERSIBLES
-- ⚠️  Faites une sauvegarde avant toute suppression importante
-- ============================================================================

-- ============================================================================
-- OPTION 1: SUPPRIMER UN UTILISATF CFA SPÉCIFIQUE PAR EMAIL
-- ============================================================================

-- 1.1 Vérifier l'utilisateur avant suppression
SELECT 
    u.id,
    u.email,
    u.phone,
    u.full_name,
    u.user_type,
    u.created_at
FROM public.users u
WHERE u.email = 'driver_111111@uumo.app'; -- Remplacez par l'email souhaité

-- 1.2 Voir les données liées (trips, orders, etc.)
SELECT 
    'trips_as_driver' as type, COUNT(*) 
FROM trips 
WHERE driver_id = (SELECT id FROM users WHERE email = 'driver_111111@uumo.app')
UNION ALL
SELECT 
    'trips_as_rider' as type, COUNT(*) 
FROM trips 
WHERE rider_id = (SELECT id FROM users WHERE email = 'driver_111111@uumo.app')
UNION ALL
SELECT 
    'token_transactions' as type, COUNT(*) 
FROM token_transactions 
WHERE user_id = (SELECT id FROM users WHERE email = 'driver_111111@uumo.app');

-- 1.3 Supprimer l'utilisateur (CASCADE supprime automatiquement les données liées)
-- ⚠️ SUPPRESSION DÉFINITIVE
DELETE FROM auth.users 
WHERE email = 'driver_111111@uumo.app';

-- Note: La suppression de auth.users supprime automatiquement:
-- - L'entrée dans public.users (CASCADE)
-- - driver_profiles / rider_profiles (CASCADE)
-- - token_balances (CASCADE)
-- - trips, orders, etc. où user_id est référencé avec ON DELETE CASCADE

-- ============================================================================
-- OPTION 2: SUPPRIMER UN UTILISATF CFA PAR TÉLÉPHONE
-- ============================================================================

-- 2.1 Trouver l'utilisateur par téléphone
SELECT 
    id,
    email,
    phone,
    full_name,
    user_type
FROM public.users
WHERE phone = '111111'; -- Remplacez par le numéro de téléphone

-- 2.2 Supprimer par téléphone
DELETE FROM auth.users 
WHERE email IN (
    SELECT email FROM public.users WHERE phone = '111111'
);

-- ============================================================================
-- OPTION 3: SUPPRIMER TOUS LES UTILISATEURS DE TEST
-- ============================================================================

-- 3.1 Lister tous les utilisateurs de test (@uumo.app)
SELECT 
    id,
    email,
    phone,
    full_name,
    user_type,
    created_at
FROM public.users
WHERE email LIKE '%@uumo.app'
ORDER BY created_at DESC;

-- 3.2 Supprimer tous les utilisateurs de test
-- ⚠️ ATTENTION: Cela supprime TOUS les utilisateurs avec @uumo.app
DELETE FROM auth.users 
WHERE email LIKE '%@uumo.app';

-- ============================================================================
-- OPTION 4: SUPPRIMER UN UTILISATF CFA PAR ID
-- ============================================================================

-- 4.1 Vérifier l'ID
SELECT 
    id,
    email,
    phone,
    full_name,
    user_type
FROM public.users
WHERE id = 'uuid-de-l-utilisateur-ici';

-- 4.2 Supprimer par ID
DELETE FROM auth.users 
WHERE id = 'uuid-de-l-utilisateur-ici';

-- ============================================================================
-- OPTION 5: SUPPRIMER PLUSIEURS UTILISATEURS PAR TYPE
-- ============================================================================

-- 5.1 Lister tous les drivers
SELECT 
    id,
    email,
    phone,
    full_name,
    created_at
FROM public.users
WHERE user_type = 'driver'
ORDER BY created_at DESC;

-- 5.2 Supprimer tous les drivers de test
DELETE FROM auth.users 
WHERE id IN (
    SELECT id 
    FROM public.users 
    WHERE user_type = 'driver' 
      AND email LIKE '%@uumo.app'
);

-- ============================================================================
-- OPTION 6: SUPPRIMER UN UTILISATF CFA MAIS GARDER L'HISTORIQUE
-- ============================================================================
-- Si vous voulez "désactiver" au lieu de supprimer:

-- 6.1 Marquer comme inactif
UPDATE public.users 
SET 
    status = 'inactive',
    email = CONCAT('deleted_', id::text, '@deleted.local'),
    phone = NULL,
    full_name = '[Utilisateur supprimé]'
WHERE email = 'user@example.com';

-- 6.2 Supprimer l'authentification mais garder les données
DELETE FROM auth.users 
WHERE email = 'user@example.com';

-- ============================================================================
-- OPTION 7: NETTOYAGE COMPLET (RÉINITIALISER LA BASE DE TEST)
-- ============================================================================
-- ⚠️ DANGER: Supprime TOUS les utilisateurs et TOUTES les données

-- Désactiver temporairement RLS pour la suppression
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE trips DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE token_balances DISABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions DISABLE ROW LEVEL SECURITY;

-- Supprimer toutes les données de test
DELETE FROM trip_offers;
DELETE FROM delivery_offers;
DELETE FROM trips;
DELETE FROM orders;
DELETE FROM token_transactions;
DELETE FROM token_balances;
DELETE FROM token_purchases;
DELETE FROM driver_profiles;
DELETE FROM restaurant_profiles;
DELETE FROM merchant_profiles;
DELETE FROM public.users WHERE email LIKE '%@uumo.app';
DELETE FROM auth.users WHERE email LIKE '%@uumo.app';

-- Réactiver RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- VÉRIFICATIONS POST-SUPPRESSION
-- ============================================================================

-- Vérifier que l'utilisateur a bien été supprimé
SELECT 
    'auth.users' as table_name,
    COUNT(*) as count
FROM auth.users
WHERE email LIKE '%@uumo.app'
UNION ALL
SELECT 
    'public.users' as table_name,
    COUNT(*) as count
FROM public.users
WHERE email LIKE '%@uumo.app'
UNION ALL
SELECT 
    'driver_profiles' as table_name,
    COUNT(*) as count
FROM driver_profiles
WHERE id IN (SELECT id FROM public.users WHERE email LIKE '%@uumo.app');

-- Afficher tous les utilisateurs restants
SELECT 
    user_type,
    COUNT(*) as total_users
FROM public.users
GROUP BY user_type
ORDER BY total_users DESC;

-- ============================================================================
-- NOTES IMPORTANTES
-- ============================================================================
/*
1. CASCADE: Les tables sont configurées avec ON DELETE CASCADE, donc:
   - Supprimer auth.users → supprime automatiquement public.users
   - Supprimer public.users → supprime driver_profiles, token_balances, etc.

2. Relations avec CASCADE:
   - users → driver_profiles (CASCADE)
   - users → token_balances (CASCADE)
   - users → token_transactions (CASCADE)
   - users → trips (SET NULL ou CASCADE selon config)
   - users → orders (SET NULL ou CASCADE selon config)

3. Pour une suppression SÛRE:
   - Toujours vérifier les données liées AVANT de supprimer
   - Faire une sauvegarde si nécessaire
   - Tester sur un environnement de staging d'abord

4. Alternatives à la suppression:
   - Désactiver: SET status = 'inactive'
   - Anonymiser: Remplacer les données personnelles
   - Archiver: Déplacer vers une table d'archive

5. Supprimer depuis l'application:
   - Les apps Flutter peuvent appeler auth.signOut() pour déconnecter
   - Pour supprimer le compte: Utiliser supabase.auth.admin.deleteUser()
     (nécessite service_role_key depuis le backend)

6. Si la suppression échoue:
   - Vérifier les policies RLS
   - Vérifier les contraintes FOREIGN KEY
   - Désactiver temporairement RLS si nécessaire (avec précaution)
*/
