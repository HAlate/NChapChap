-- Vérifier les valeurs de l'enum transaction_type
SELECT 
  t.typname as enum_name,
  e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'transaction_type'
ORDER BY e.enumsortorder;
