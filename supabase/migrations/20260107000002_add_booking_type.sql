/*
  # Ajout du système de courses immédiates vs réservées
  
  Permet aux passagers de choisir entre:
  - Course immédiate: Départ maintenant
  - Course réservée: Départ planifié à une date/heure future
  
  Modifications:
  1. Ajouter ENUM booking_type ('immediate', 'scheduled')
  2. Ajouter colonne booking_type à trips (par défaut 'immediate')
  3. Ajouter colonne scheduled_time à trips (nullable)
  4. Ajouter index pour recherche de courses réservées
*/

-- Étape 1: Créer le type ENUM pour le type de réservation
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_type') THEN
    CREATE TYPE booking_type AS ENUM ('immediate', 'scheduled');
  END IF;
END $$;

-- Étape 2: Ajouter les colonnes à la table trips
ALTER TABLE trips 
  ADD COLUMN IF NOT EXISTS booking_type booking_type DEFAULT 'immediate' NOT NULL;

ALTER TABLE trips 
  ADD COLUMN IF NOT EXISTS scheduled_time timestamptz;

-- Étape 3: Ajouter une contrainte CHECK
-- Si booking_type = 'scheduled', alors scheduled_time doit être renseigné et dans le futur
ALTER TABLE trips 
  DROP CONSTRAINT IF EXISTS check_scheduled_time;

ALTER TABLE trips 
  ADD CONSTRAINT check_scheduled_time 
  CHECK (
    (booking_type = 'immediate') OR 
    (booking_type = 'scheduled' AND scheduled_time IS NOT NULL AND scheduled_time > now())
  );

-- Étape 4: Créer des index pour les requêtes
CREATE INDEX IF NOT EXISTS idx_trips_booking_type 
  ON trips(booking_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_scheduled 
  ON trips(scheduled_time, status) 
  WHERE booking_type = 'scheduled';

-- Étape 5: Ajouter un commentaire explicatif
COMMENT ON COLUMN trips.booking_type IS 
'Type de réservation: immediate (maintenant) ou scheduled (planifié)';

COMMENT ON COLUMN trips.scheduled_time IS 
'Heure de départ prévue pour les courses réservées (NULL pour courses immédiates)';

-- Étape 6: Mettre à jour les trips existants (tous en mode immediate par défaut)
UPDATE trips 
SET booking_type = 'immediate', 
    scheduled_time = NULL 
WHERE booking_type IS NULL;
