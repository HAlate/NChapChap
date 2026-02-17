-- Migration: Système KYC (Know Your Customer) pour les chauffeurs
-- Permet de vérifier l'identité des chauffeurs via scan de documents avec Microblink

-- Étape 1: Créer ENUM pour les types de documents
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_document_type') THEN
    CREATE TYPE kyc_document_type AS ENUM (
      'national_id',        -- Carte d'identité nationale
      'passport',           -- Passeport
      'drivers_license',    -- Permis de conduire
      'vehicle_registration', -- Carte grise du véhicule
      'insurance',          -- Assurance véhicule
      'selfie'              -- Photo du chauffeur
    );
  END IF;
END $$;

-- Étape 2: Créer ENUM pour le statut KYC
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_status') THEN
    CREATE TYPE kyc_status AS ENUM (
      'not_started',   -- Pas encore commencé
      'pending',       -- Documents soumis, en attente de vérification
      'in_review',     -- En cours de révision par admin
      'approved',      -- Approuvé, peut conduire
      'rejected',      -- Rejeté, doit resoumettre
      'expired'        -- Documents expirés, doit renouveler
    );
  END IF;
END $$;

-- Étape 3: Créer la table driver_kyc_documents
CREATE TABLE IF NOT EXISTS driver_kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  
  -- Type et informations du document
  document_type kyc_document_type NOT NULL,
  document_number text,
  expiry_date date,
  
  -- Stockage des fichiers
  front_image_url text,
  back_image_url text,
  selfie_url text,
  
  -- Données extraites par Microblink
  microblink_data jsonb DEFAULT '{}'::jsonb,
  extracted_name text,
  extracted_birth_date date,
  extracted_address text,
  
  -- Statut de vérification
  verification_status kyc_status DEFAULT 'pending' NOT NULL,
  verified_by uuid REFERENCES users(id),
  verified_at timestamptz,
  
  -- Notes admin
  admin_notes text,
  rejection_reason text,
  
  -- Métadonnées
  submitted_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  
  -- Un chauffeur peut avoir plusieurs documents du même type (resoumission)
  -- mais on garde l'historique
  CONSTRAINT unique_active_document UNIQUE NULLS NOT DISTINCT (driver_id, document_type, verification_status)
);

-- Étape 4: Ajouter colonne kyc_status dans driver_profiles
ALTER TABLE driver_profiles 
  ADD COLUMN IF NOT EXISTS kyc_status kyc_status DEFAULT 'not_started' NOT NULL;

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS kyc_completed_at timestamptz;

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS kyc_expiry_date date;

-- Étape 5: Créer des index
CREATE INDEX IF NOT EXISTS idx_kyc_documents_driver 
  ON driver_kyc_documents(driver_id, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_kyc_documents_status 
  ON driver_kyc_documents(verification_status, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_kyc_documents_expiry 
  ON driver_kyc_documents(expiry_date) 
  WHERE verification_status = 'approved';

CREATE INDEX IF NOT EXISTS idx_driver_profiles_kyc_status 
  ON driver_profiles(kyc_status);

-- Étape 6: Créer fonction pour mettre à jour le statut KYC global du chauffeur
CREATE OR REPLACE FUNCTION update_driver_kyc_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_required_docs integer := 3; -- ID, permis, selfie
  v_approved_docs integer;
  v_pending_docs integer;
  v_rejected_docs integer;
BEGIN
  -- Compter les documents approuvés
  SELECT COUNT(*) INTO v_approved_docs
  FROM driver_kyc_documents
  WHERE driver_id = NEW.driver_id
    AND verification_status = 'approved'
    AND document_type IN ('national_id', 'passport', 'drivers_license', 'selfie')
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE);
  
  -- Compter les documents en attente
  SELECT COUNT(*) INTO v_pending_docs
  FROM driver_kyc_documents
  WHERE driver_id = NEW.driver_id
    AND verification_status IN ('pending', 'in_review')
    AND document_type IN ('national_id', 'passport', 'drivers_license', 'selfie');
  
  -- Compter les documents rejetés
  SELECT COUNT(*) INTO v_rejected_docs
  FROM driver_kyc_documents
  WHERE driver_id = NEW.driver_id
    AND verification_status = 'rejected'
    AND document_type IN ('national_id', 'passport', 'drivers_license', 'selfie');
  
  -- Mettre à jour le statut global
  IF v_approved_docs >= v_required_docs THEN
    -- Tous les documents requis sont approuvés
    UPDATE driver_profiles
    SET 
      kyc_status = 'approved',
      kyc_completed_at = now(),
      kyc_expiry_date = (
        SELECT MIN(expiry_date)
        FROM driver_kyc_documents
        WHERE driver_id = NEW.driver_id
          AND verification_status = 'approved'
          AND expiry_date IS NOT NULL
      )
    WHERE id = NEW.driver_id;
    
  ELSIF v_rejected_docs > 0 THEN
    -- Au moins un document rejeté
    UPDATE driver_profiles
    SET kyc_status = 'rejected'
    WHERE id = NEW.driver_id;
    
  ELSIF v_pending_docs > 0 THEN
    -- Documents en attente de vérification
    UPDATE driver_profiles
    SET kyc_status = 'pending'
    WHERE id = NEW.driver_id;
    
  ELSE
    -- Aucun document soumis ou tous expirés
    UPDATE driver_profiles
    SET kyc_status = 'not_started'
    WHERE id = NEW.driver_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Étape 7: Créer trigger pour mettre à jour automatiquement le statut
DROP TRIGGER IF EXISTS trigger_update_driver_kyc_status ON driver_kyc_documents;

CREATE TRIGGER trigger_update_driver_kyc_status
  AFTER INSERT OR UPDATE ON driver_kyc_documents
  FOR EACH ROW
  EXECUTE FUNCTION update_driver_kyc_status();

-- Étape 8: Fonction pour vérifier si un chauffeur peut accepter des courses
CREATE OR REPLACE FUNCTION can_driver_accept_trips(p_driver_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_kyc_status kyc_status;
  v_kyc_expiry date;
BEGIN
  SELECT kyc_status, kyc_expiry_date
  INTO v_kyc_status, v_kyc_expiry
  FROM driver_profiles
  WHERE id = p_driver_id;
  
  -- Le chauffeur peut accepter des courses si:
  -- 1. KYC est approuvé
  -- 2. Les documents ne sont pas expirés
  RETURN v_kyc_status = 'approved' 
    AND (v_kyc_expiry IS NULL OR v_kyc_expiry > CURRENT_DATE);
END;
$$;

-- Étape 9: Enable RLS
ALTER TABLE driver_kyc_documents ENABLE ROW LEVEL SECURITY;

-- Politique: Les chauffeurs voient leurs propres documents
DROP POLICY IF EXISTS "Drivers can view own KYC documents" ON driver_kyc_documents;
CREATE POLICY "Drivers can view own KYC documents"
  ON driver_kyc_documents
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Les chauffeurs peuvent soumettre leurs documents
DROP POLICY IF EXISTS "Drivers can submit KYC documents" ON driver_kyc_documents;
CREATE POLICY "Drivers can submit KYC documents"
  ON driver_kyc_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'driver'
    )
  );

-- Note: Pas de politique admin ici. Les admins utiliseront le service role key
-- pour accéder et modifier les documents KYC via le backend ou dashboard admin.

-- Étape 10: Créer une vue pour les documents en attente de vérification
CREATE OR REPLACE VIEW pending_kyc_documents AS
SELECT 
  d.id,
  d.driver_id,
  d.document_type,
  d.document_number,
  d.expiry_date,
  d.front_image_url,
  d.back_image_url,
  d.selfie_url,
  d.verification_status,
  d.submitted_at,
  u.full_name AS driver_name,
  u.email AS driver_email,
  u.phone AS driver_phone,
  dp.kyc_status AS driver_kyc_status
FROM driver_kyc_documents d
JOIN users u ON d.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
WHERE d.verification_status IN ('pending', 'in_review')
ORDER BY d.submitted_at ASC;

-- Commentaires
COMMENT ON TABLE driver_kyc_documents IS 
'Documents KYC soumis par les chauffeurs pour vérification d''identité. Intégration avec Microblink pour scan automatique.';

COMMENT ON COLUMN driver_kyc_documents.microblink_data IS 
'Données brutes retournées par l''API Microblink après scan du document.';

COMMENT ON FUNCTION can_driver_accept_trips IS 
'Vérifie si un chauffeur a un KYC valide et peut accepter des courses.';

COMMENT ON VIEW pending_kyc_documents IS 
'Vue pour les admins listant tous les documents en attente de vérification.';

-- Grants
GRANT EXECUTE ON FUNCTION can_driver_accept_trips TO authenticated;
GRANT SELECT ON pending_kyc_documents TO authenticated;
