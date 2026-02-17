-- Migration: Désactiver la confirmation d'email et confirmer automatiquement
-- Date: 2026-01-08
-- Problème: Les emails fictifs (rider_123@uumo.app) ne peuvent pas être confirmés
-- Solution: Auto-confirmer les emails lors de l'inscription

-- =========================================
-- SOLUTION: Modifier le trigger pour auto-confirmer
-- =========================================

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

-- =========================================
-- COMMENTAIRES
-- =========================================
COMMENT ON FUNCTION public.handle_new_user IS
'Crée automatiquement une entrée dans public.users et confirme les emails @uumo.app lors de l''inscription.';

-- =========================================
-- VÉRIFICATION
-- =========================================
-- Vérifier que la fonction est bien mise à jour:
-- SELECT proname, prosrc FROM pg_proc WHERE proname = 'handle_new_user';

-- Tester avec un nouvel utilisateur:
-- Les champs email_confirmed_at et confirmed_at doivent être remplis automatiquement
