-- Ajouter les colonnes manquantes à la table driver_profiles

-- Ajouter vehicle_color si elle n'existe pas
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS vehicle_color VARCHAR(50);

-- Ajouter rating si elle n'existe pas
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1) DEFAULT 5.0;

-- Ajouter total_trips si elle n'existe pas
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS total_trips INTEGER DEFAULT 0;

-- Ajouter token_balance si elle n'existe pas
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS token_balance INTEGER DEFAULT 0;

-- Vérifier les colonnes ajoutées
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'driver_profiles' 
AND column_name IN ('vehicle_color', 'rating', 'total_trips', 'token_balance')
ORDER BY column_name;
