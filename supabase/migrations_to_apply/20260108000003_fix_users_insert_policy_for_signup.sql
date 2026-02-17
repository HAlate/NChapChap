-- Migration: Correction politique INSERT users pour l'inscription
-- Date: 2026-01-08
-- Problème: L'inscription échoue car auth.uid() est NULL pendant signUp
-- Solution: Permettre l'insertion si l'ID correspond à l'utilisateur en cours de création

-- =========================================
-- EXPLICATION DU PROBLÈME
-- =========================================
-- Lors de auth.signUp(), Supabase crée d'abord l'utilisateur dans auth.users
-- Puis l'application essaie d'insérer dans public.users
-- Mais à ce moment, la session n'est pas encore établie
-- Donc auth.uid() peut être NULL ou ne pas correspondre
-- 
-- La politique actuelle bloque l'insertion car elle vérifie id = auth.uid()
-- Ce qui échoue si auth.uid() n'est pas encore défini

-- =========================================
-- SOLUTION 1: Politique plus permissive pour l'inscription
-- =========================================

-- Supprimer l'ancienne politique
DROP POLICY IF EXISTS "Users can create own profile" ON users;

-- Nouvelle politique: Permettre l'insertion si l'ID est valide
-- Note: On vérifie que l'ID existe dans auth.users (sécurité)
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
    -- OU l'ID correspond à l'utilisateur authentifié (fallback)
    OR id = auth.uid()
  );

-- =========================================
-- SOLUTION 2: Trigger automatique (Alternative)
-- =========================================
-- Cette fonction crée automatiquement l'entrée dans public.users
-- dès qu'un utilisateur s'inscrit via auth.signUp()

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Créer automatiquement l'utilisateur dans public.users
  -- en utilisant les métadonnées de auth.signUp()
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

-- Trigger qui s'exécute après chaque inscription
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =========================================
-- COMMENTAIRES
-- =========================================
COMMENT ON POLICY "Users can create profile during signup" ON users IS
'Permet la création de profil lors de l''inscription. Vérifie que l''ID existe dans auth.users pour la sécurité.';

COMMENT ON FUNCTION public.handle_new_user IS
'Crée automatiquement une entrée dans public.users lors de l''inscription via auth.signUp(). Utilise les métadonnées pour pré-remplir les champs.';

-- =========================================
-- NOTES D'UTILISATION
-- =========================================
-- Avec cette migration, deux approches fonctionnent:
--
-- 1. Approche manuelle (code actuel):
--    await supabase.auth.signUp(...)
--    await supabase.from('users').insert(...)
--
-- 2. Approche automatique (recommandée):
--    await supabase.auth.signUp(
--      email: email,
--      password: password,
--      data: {
--        'phone': phone,
--        'full_name': fullName,
--        'user_type': 'driver',
--      }
--    )
--    // L'entrée dans users est créée automatiquement par le trigger!
