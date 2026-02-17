-- Solution finale: Supprimer et recréer les drivers de test PROPREMENT
-- Le problème vient probablement du fait que les users ont été insérés manuellement
-- au lieu d'être créés via Supabase Auth API

-- 1. SUPPRIMER COMPLÈTEMENT tous les drivers de test
-- Ordre important: driver_profiles -> public.users -> auth.identities -> auth.users

DELETE FROM driver_profiles 
WHERE id IN (
    SELECT id FROM public.users WHERE email LIKE 'driver_%@uumo.app'
);

DELETE FROM public.users 
WHERE email LIKE 'driver_%@uumo.app';

DELETE FROM auth.identities 
WHERE user_id IN (
    SELECT id FROM auth.users WHERE email LIKE 'driver_%@uumo.app'
);

DELETE FROM auth.users 
WHERE email LIKE 'driver_%@uumo.app';

-- 2. Vérifier que tout est supprimé
SELECT 
  'Nettoyage vérifié' as status,
  (SELECT COUNT(*) FROM auth.users WHERE email LIKE 'driver_%@uumo.app') as auth_users,
  (SELECT COUNT(*) FROM auth.identities WHERE provider_id IN 
    (SELECT id::text FROM auth.users WHERE email LIKE 'driver_%@uumo.app')) as identities,
  (SELECT COUNT(*) FROM public.users WHERE email LIKE 'driver_%@uumo.app') as public_users,
  (SELECT COUNT(*) FROM driver_profiles WHERE id IN 
    (SELECT id FROM public.users WHERE email LIKE 'driver_%@uumo.app')) as profiles;

-- 3. Message important
SELECT 
  '⚠️ Drivers de test supprimés' as status,
  'Utilisez maintenant l''écran d''inscription dans mobile_driver pour créer un nouveau driver' as instruction_1,
  'OU utilisez le script create_driver_via_api.sh pour créer via API REST' as instruction_2,
  'NE PAS insérer manuellement dans auth.users - cela cause l''erreur 500' as important;
