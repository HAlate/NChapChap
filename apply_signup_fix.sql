-- =========================================
-- FIX: Erreur "database error saving new user"
-- =========================================
-- Ce script corrige le problème d'inscription en créant automatiquement
-- l'entrée dans public.users via un trigger

-- Étape 1: Créer/Mettre à jour la fonction handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Confirmer automatiquement l'email pour les domaines @uumo.app
  IF NEW.email LIKE '%@uumo.app' THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW()
    WHERE id = NEW.id;
  END IF;

  -- Créer automatiquement l'utilisateur dans public.users
  INSERT INTO public.users (id, email, phone, full_name, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Utilisateur'),
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'rider')::user_type
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Étape 2: Créer le trigger s'il n'existe pas
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Étape 3: Mettre à jour la politique INSERT pour permettre l'inscription
DROP POLICY IF EXISTS "Users can create own profile" ON users;
DROP POLICY IF EXISTS "Users can create profile during signup" ON users;

CREATE POLICY "Users can create profile during signup"
  ON users
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (
    -- L'ID doit exister dans auth.users (créé par signUp)
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = users.id
    )
    OR id = auth.uid()
  );

-- =========================================
-- VÉRIFICATION
-- =========================================
-- Vérifier que le trigger existe:
SELECT tgname, tgenabled 
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- Vérifier que la fonction existe:
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- =========================================
-- INSTRUCTIONS
-- =========================================
-- 1. Connecte-toi à Supabase SQL Editor
-- 2. Copie-colle ce script complet
-- 3. Exécute-le
-- 4. Teste l'inscription dans l'app mobile
