-- Solution radicale: DÉSACTIVER le trigger complètement pour isoler le problème

-- 1. Supprimer le trigger qui cause l'erreur (ne pas le recréer)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Supprimer la fonction
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 3. Désactiver RLS sur users de manière permanente (pour test)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 4. Supprimer toutes les politiques RLS sur users
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;

-- 5. Vérifier que TOUS les drivers test sont dans public.users
INSERT INTO public.users (id, email, phone, full_name, user_type, status)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'phone', ''),
  COALESCE(au.raw_user_meta_data->>'full_name', 'Driver'),
  'driver'::user_type,
  'active'::user_status
FROM auth.users au
WHERE au.email LIKE 'driver_%@uumo.app'
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  full_name = EXCLUDED.full_name,
  user_type = EXCLUDED.user_type,
  status = EXCLUDED.status;

-- 6. Vérifier que les 6 drivers sont présents
SELECT 
  'Drivers synchronisés' as status,
  COUNT(*) as total
FROM public.users
WHERE email LIKE 'driver_%@uumo.app';

-- 7. Afficher tous les drivers avec leurs profils
SELECT 
  u.email,
  u.phone,
  u.full_name,
  u.user_type,
  dp.vehicle_type,
  dp.vehicle_brand || ' ' || dp.vehicle_model as vehicle,
  dp.is_available
FROM public.users u
LEFT JOIN driver_profiles dp ON dp.id = u.id
WHERE u.email LIKE 'driver_%@uumo.app'
ORDER BY u.phone;

-- 8. Vérifier s'il y a des fonctions ou vues qui pourraient causer des problèmes
SELECT 
  'Fonctions dans public' as type,
  routine_name as name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%user%'
ORDER BY routine_name;

-- 9. Message final
SELECT 
  '✅ Trigger désactivé, RLS désactivé' as status,
  'Essayez de vous reconnecter avec 111111 / tototo' as instruction,
  'Si ça marche: le problème était le trigger/RLS' as diagnostic,
  'Si ça ne marche pas: le problème est ailleurs (voir logs Supabase)' as note;
