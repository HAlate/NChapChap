-- Option alternative : Ajouter la colonne 'reason' à la table
-- Cela permettrait au code existant de fonctionner

ALTER TABLE token_transactions 
ADD COLUMN IF NOT EXISTS reason text;

-- Vérifier la structure de la table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'token_transactions'
ORDER BY ordinal_position;
