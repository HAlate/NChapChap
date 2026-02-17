-- Voir la structure de la table trips
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trips' 
ORDER BY ordinal_position;
