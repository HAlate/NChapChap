-- Ajouter les colonnes de visibilité à la table users
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS is_visible_to_riders BOOLEAN DEFAULT TRUE;

-- Index pour performance sur les recherches de visibilité
CREATE INDEX IF NOT EXISTS idx_users_is_visible 
ON users(is_visible) 
WHERE is_visible = TRUE;

CREATE INDEX IF NOT EXISTS idx_users_is_visible_to_riders 
ON users(is_visible_to_riders) 
WHERE is_visible_to_riders = TRUE;

-- Commentaires
COMMENT ON COLUMN users.is_visible IS 'Indique si l''utilisateur est visible dans le système';
COMMENT ON COLUMN users.is_visible_to_riders IS 'Indique si le conducteur est visible pour les passagers';
