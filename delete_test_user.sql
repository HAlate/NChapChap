-- Supprimer complètement l'utilisateur de test pour recommencer

-- 1. Vérifier d'abord quel utilisateur existe
SELECT 
    'auth.users' as table_name,
    id,
    email,
    created_at,
    email_confirmed_at
FROM auth.users
WHERE email LIKE '%@uumo.app'
ORDER BY created_at DESC;

SELECT 
    'public.users' as table_name,
    id,
    email,
    phone,
    full_name
FROM public.users
WHERE email LIKE '%@uumo.app'
ORDER BY created_at DESC;

-- 2. Supprimer TOUS les utilisateurs de test @uumo.app
DELETE FROM public.users WHERE email LIKE '%@uumo.app';
DELETE FROM auth.users WHERE email LIKE '%@uumo.app';

-- 3. Vérifier la suppression
SELECT COUNT(*) as remaining_test_users
FROM auth.users
WHERE email LIKE '%@uumo.app';

-- Maintenant vous pouvez créer un nouvel utilisateur dans l'app avec:
-- Téléphone: 111111
-- Mot de passe: Test1234!
-- L'email sera automatiquement: rider_111111@uumo.app
