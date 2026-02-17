-- =========================================
-- FIX: Email not confirmed (400 error)
-- =========================================
-- Ce script confirme automatiquement tous les emails @uumo.app

-- Étape 1: Confirmer tous les emails @uumo.app existants
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email LIKE '%@uumo.app'
  AND email_confirmed_at IS NULL;

-- Étape 2: Vérifier que le trigger handle_new_user confirme bien les emails
-- (Si ce n'est pas déjà fait)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  -- Confirmer automatiquement l'email pour les domaines @uumo.app
  IF NEW.email LIKE '%@uumo.app' THEN
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
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
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    full_name = EXCLUDED.full_name,
    user_type = EXCLUDED.user_type,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Erreur handle_new_user pour %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

-- Étape 3: Désactiver la confirmation d'email dans les paramètres Supabase
-- (Ceci doit être fait dans le dashboard Supabase)
-- Authentication > Settings > Email Auth > Enable email confirmations = OFF

-- =========================================
-- VÉRIFICATION
-- =========================================

-- Vérifier les utilisateurs @uumo.app et leur statut de confirmation
SELECT 
  id,
  email,
  email_confirmed_at,
  confirmed_at,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmé'
    ELSE '❌ Non confirmé'
  END as status,
  created_at
FROM auth.users
WHERE email LIKE '%@uumo.app'
ORDER BY created_at DESC
LIMIT 10;

-- =========================================
-- INSTRUCTIONS
-- =========================================
-- 1. Exécute ce script dans Supabase SQL Editor
-- 2. Vérifie que tous les utilisateurs sont confirmés (✅)
-- 3. Va dans Authentication > Settings > Email Auth
-- 4. Désactive "Enable email confirmations"
-- 5. Teste la connexion dans l'app
