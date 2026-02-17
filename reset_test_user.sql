-- Diagnostic et création d'un nouvel utilisateur de test

-- 1. Vérifier l'utilisateur actuel
SELECT 
    id,
    email,
    email_confirmed_at,
    created_at,
    last_sign_in_at
FROM auth.users
WHERE email LIKE '%909090%@uumo.app';

-- 2. Vérifier dans public.users
SELECT 
    id,
    email,
    phone,
    full_name,
    user_type,
    created_at
FROM public.users
WHERE email LIKE '%909090%@uumo.app';

-- 3. OPTION A: Supprimer l'ancien utilisateur (si vous voulez recommencer)
-- Décommentez ces lignes pour supprimer:
/*
DELETE FROM public.users WHERE email LIKE '%909090%@uumo.app';
DELETE FROM auth.users WHERE email LIKE '%909090%@uumo.app';
*/

-- 4. OPTION B: Créer un nouvel utilisateur de test avec un mot de passe connu
-- Note: Vous devez créer cet utilisateur via l'application (register_screen.dart)
-- avec ces identifiants:
-- Téléphone: 111111
-- Email: rider_111111@uumo.app
-- Mot de passe: Test1234!
-- Nom: Test Rider

-- 5. Vérifier que le trigger fonctionne correctement
SELECT 
    t.tgname as trigger_name,
    t.tgenabled as enabled,
    pg_get_triggerdef(t.oid) as definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'users' 
AND t.tgname = 'on_auth_user_created';

-- 6. Vérifier les policies RLS
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
WHERE tablename = 'users'
ORDER BY policyname;
