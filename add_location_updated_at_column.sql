-- Ajouter la colonne location_updated_at à driver_profiles
-- Cette colonne stocke l'horodatage de la dernière mise à jour de position

ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ DEFAULT NOW();

-- Créer un index pour optimiser les requêtes de géolocalisation
CREATE INDEX IF NOT EXISTS idx_driver_profiles_location_updated_at 
ON driver_profiles(location_updated_at);

-- Commentaire explicatif
COMMENT ON COLUMN driver_profiles.location_updated_at IS 
'Horodatage de la dernière mise à jour de la position GPS du chauffeur. Utilisé pour le tracking en temps réel.';

-- Vérification
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'driver_profiles'
AND column_name = 'location_updated_at';
