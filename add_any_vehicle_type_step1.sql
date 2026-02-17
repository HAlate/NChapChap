-- Migration PARTIE 1: Ajouter 'any' au type vehicle_type
-- Date: 2026-01-23
-- Description: Première étape - Ajout de la valeur 'any' à l'ENUM

-- Ajouter 'any' au type ENUM vehicle_type
ALTER TYPE vehicle_type ADD VALUE IF NOT EXISTS 'any';

-- Vérification
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_enum 
    WHERE enumlabel = 'any' 
    AND enumtypid = 'vehicle_type'::regtype
  ) THEN
    RAISE NOTICE '✅ La valeur "any" a été ajoutée avec succès au type vehicle_type';
  ELSE
    RAISE NOTICE '⚠️ La valeur "any" existe déjà dans vehicle_type';
  END IF;
END $$;

-- ⏸️ IMPORTANT: Attendez quelques secondes avant d'exécuter la Partie 2
-- ou fermez cette transaction et ouvrez-en une nouvelle
