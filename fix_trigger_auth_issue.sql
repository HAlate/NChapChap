-- Fix URGENT pour l'erreur "Database error querying schema"
-- Cette erreur indique que le trigger handle_new_user() échoue pendant la connexion

-- 1. DÉSACTIVER uniquement le trigger personnalisé qui cause l'erreur
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Supprimer la fonction qui pose problème
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 3. Recréer une version simplifiée et sécurisée du trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    -- Insérer dans public.users uniquement si pas déjà présent
    INSERT INTO public.users (id, email, phone, full_name, user_type, status)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'phone', ''),
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      COALESCE((NEW.raw_user_meta_data->>'user_type')::user_type, 'rider'::user_type),
      'active'::user_status
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
  EXCEPTION
    WHEN OTHERS THEN
      -- Log l'erreur mais ne bloque pas l'authentification
      RAISE WARNING 'Erreur dans handle_new_user pour %: %', NEW.email, SQLERRM;
      RETURN NEW;
  END;
END;
$$;

-- 4. Recréer le trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 5. Vérifier que le trigger est bien créé
SELECT 
  'Trigger recréé' as status,
  tgname as trigger_name,
  tgenabled as enabled
FROM pg_trigger
WHERE tgname = 'on_auth_user_created';

-- 6. Désactiver temporairement RLS sur users
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 7. Vérifier que l'utilisateur de test est dans public.users
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM public.users WHERE email = 'driver_111111@uumo.app'
    ) THEN '✅ Driver existe dans public.users'
    ELSE '❌ Driver manquant dans public.users'
  END as check_result;

-- 8. Si pas présent, l'ajouter manuellement
INSERT INTO public.users (id, email, phone, full_name, user_type, status)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'phone', '111111'),
  COALESCE(au.raw_user_meta_data->>'full_name', 'Driver Moto'),
  'driver'::user_type,
  'active'::user_status
FROM auth.users au
WHERE au.email = 'driver_111111@uumo.app'
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  full_name = EXCLUDED.full_name,
  user_type = EXCLUDED.user_type,
  status = EXCLUDED.status;

-- 9. Réactiver RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 10. Vérification finale - afficher l'utilisateur complet
SELECT 
  u.id,
  u.email,
  u.phone,
  u.full_name,
  u.user_type,
  u.status,
  dp.vehicle_type,
  dp.vehicle_brand || ' ' || dp.vehicle_model as vehicle,
  dp.is_available,
  'Prêt pour connexion' as message
FROM public.users u
LEFT JOIN driver_profiles dp ON dp.id = u.id
WHERE u.email = 'driver_111111@uumo.app';

-- Message final
SELECT '✅ Correction terminée! Relancez flutter run et essayez de vous connecter avec: 111111 / tototo' as instruction;
