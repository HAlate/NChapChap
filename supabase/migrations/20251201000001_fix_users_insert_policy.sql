/*
  # Fix Users Insert Policy
  
  Permet aux utilisateurs authentifiés de créer leur propre profil
  lors de l'inscription
*/

-- Politique: Utilisateurs peuvent créer leur propre profil
DROP POLICY IF EXISTS "Users can create own profile" ON users;
CREATE POLICY "Users can create own profile"
  ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());
