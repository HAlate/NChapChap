-- Fix: Recréer le trigger handle_new_user() pour synchroniser auth.users -> public.users

-- 1. Supprimer l'ancien trigger s'il existe
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2. Créer la fonction handle_new_user() avec SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insérer dans public.users immédiatement après création dans auth.users
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
END;
$$;

-- 3. Créer le trigger APRÈS insertion dans auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. Créer aussi une identity automatiquement
CREATE OR REPLACE FUNCTION public.handle_new_user_identity()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Créer l'identity pour le provider email
  INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    provider,
    identity_data,
    created_at,
    updated_at
  )
  VALUES (
    gen_random_uuid(),
    NEW.id,
    NEW.id::text,
    'email',
    jsonb_build_object(
      'sub', NEW.id::text,
      'email', NEW.email,
      'email_verified', NEW.email_confirmed_at IS NOT NULL
    ),
    NOW(),
    NOW()
  )
  ON CONFLICT DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- 5. Créer le trigger pour les identities
CREATE TRIGGER on_auth_user_created_identity
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user_identity();

-- 6. Vérifier que les triggers sont créés
SELECT 
  'Triggers créés' as status,
  tgname as trigger_name,
  tgenabled as enabled
FROM pg_trigger
WHERE tgname IN ('on_auth_user_created', 'on_auth_user_created_identity')
ORDER BY tgname;

-- 7. Message
SELECT 
  '✅ Triggers recréés avec SECURITY DEFINER' as status,
  'Les nouveaux users seront automatiquement ajoutés à public.users' as note_1,
  'Les identities seront créées automatiquement' as note_2,
  'Réessayez l''inscription maintenant' as instruction;
