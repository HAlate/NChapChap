-- Ajouter la colonne vehicle_color à la table driver_profiles

ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS vehicle_color VARCHAR(50);

-- Vérifier que la colonne a été ajoutée
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'driver_profiles' 
AND column_name = 'vehicle_color';
