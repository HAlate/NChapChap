-- ========================================
-- FIX RLS POLICIES - APPZEDGO
-- ========================================
-- Exécutez ce script dans Supabase SQL Editor

-- 1. Ajouter la politique INSERT pour la table users
-- Supprime d'abord si elle existe
DROP POLICY IF EXISTS "Users can create own profile" ON users;

CREATE POLICY "Users can create own profile"
  ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- 2. Modifier la politique de création de trips pour être moins restrictive
-- Supprime l'ancienne politique
DROP POLICY IF EXISTS "Riders can create trips" ON trips;

-- Crée une nouvelle politique qui vérifie simplement l'authentification
CREATE POLICY "Riders can create trips"
  ON trips
  FOR INSERT
  TO authenticated
  WITH CHECK (rider_id = auth.uid());

-- 3. Vérifier si l'utilisateur existe (OPTIONNEL - pour debug)
-- SELECT * FROM users WHERE id = 'c7ad9a51-57bd-40a1-b82f-4e4118a56954';

-- 4. Si l'utilisateur n'existe pas, l'insérer manuellement (OPTIONNEL)
-- Décommentez et modifiez les valeurs selon vos besoins:
/*
INSERT INTO users (id, email, phone, full_name, user_type, status)
VALUES (
  'c7ad9a51-57bd-40a1-b82f-4e4118a56954',
  '+22898959595@rider.app',
  '+22898959595',
  'toto',
  'rider',
  'active'
)
ON CONFLICT (id) DO NOTHING;
*/
