-- Migration: Modification du système de déduction des jetons
-- Date: 2026-01-08
-- Description: Passe de "déduction à l'acceptation" à "déduction au démarrage de la course"

-- =========================================
-- 1. DÉSACTIVER L'ANCIEN TRIGGER
-- =========================================

-- Désactiver le trigger sur trip_offers (déduction à l'acceptation)
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- Conserver la fonction au cas où (pour référence), mais elle ne sera plus utilisée
-- DROP FUNCTION IF EXISTS spend_token_on_trip_offer_acceptance();

COMMENT ON FUNCTION spend_token_on_trip_offer_acceptance IS
'OBSOLÈTE - Ancienne logique de déduction à l''acceptation. Remplacée par déduction au démarrage.';

-- =========================================
-- 2. AJOUTER COLONNES NÉCESSAIRES AUX TRIPS
-- =========================================

-- Ajouter cancellation_reason si pas existe
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'trips' 
          AND column_name = 'cancellation_reason'
    ) THEN
        ALTER TABLE trips 
        ADD COLUMN cancellation_reason TEXT;
    END IF;
END $$;

-- Créer index pour performance
CREATE INDEX IF NOT EXISTS idx_trips_status_cancellation ON trips(status, cancellation_reason) 
WHERE status = 'cancelled';

-- =========================================
-- 3. NOUVELLE FONCTION: DÉDUCTION AU DÉMARRAGE
-- =========================================

CREATE OR REPLACE FUNCTION spend_token_on_trip_start()
RETURNS TRIGGER AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- Vérifie si le statut passe à 'started' et que le jeton n'a pas déjà été déduit
  IF NEW.status = 'started' AND (OLD.status IS NULL OR OLD.status != 'started') THEN
    
    -- Récupère le solde actuel du driver
    SELECT balance INTO current_balance
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Vérifie que le driver a au moins 1 jeton
    IF current_balance IS NULL OR current_balance < 1 THEN
      RAISE EXCEPTION 'Driver n''a pas assez de jetons (besoin: 1, disponible: %)', COALESCE(current_balance, 0);
    END IF;

    -- Déduit 1 jeton
    UPDATE token_balances
    SET balance = balance - 1,
        updated_at = NOW()
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Enregistre la transaction
    INSERT INTO token_transactions (
      user_id,
      transaction_type,
      token_type,
      amount,
      balance_before,
      balance_after,
      reference_id,
      reason,
      notes,
      created_at
    ) VALUES (
      NEW.driver_id,
      'spend',
      'course',
      -1,
      current_balance,
      current_balance - 1,
      NEW.id,
      'trip_started',
      'Jeton déduit au démarrage de la course (après récupération passager)',
      NOW()
    );

    -- Log pour debug
    RAISE NOTICE 'Jeton déduit pour driver % au démarrage du trip % (balance: % -> %)',
      NEW.driver_id, NEW.id, current_balance, current_balance - 1;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================
-- 4. CRÉER LE NOUVEAU TRIGGER
-- =========================================

DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_start ON trips;

CREATE TRIGGER trigger_spend_token_on_trip_start
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_start();

-- =========================================
-- 5. COMMENTAIRES ET DOCUMENTATION
-- =========================================

COMMENT ON FUNCTION spend_token_on_trip_start IS
'Déduit automatiquement 1 jeton du driver lorsque le trip passe au statut = "started".
Cela se produit APRÈS que le driver ait récupéré le passager et cliqué sur "Démarrer".
Protège le driver contre les No Show passagers (pas de déduction si No Show).';

COMMENT ON TRIGGER trigger_spend_token_on_trip_start ON trips IS
'Déclenché AVANT UPDATE sur trips pour déduire le jeton lors du démarrage de la course.';

COMMENT ON COLUMN trips.cancellation_reason IS
'Raison de l''annulation (ex: "no_show", "driver_issue", "rider_request", etc.)';

-- =========================================
-- 6. VÉRIFICATION POST-MIGRATION
-- =========================================

-- Vérifier que le nouveau trigger est actif
DO $$
DECLARE
  trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM pg_trigger 
    WHERE tgname = 'trigger_spend_token_on_trip_start'
  ) INTO trigger_exists;

  IF trigger_exists THEN
    RAISE NOTICE '✅ Migration réussie: Nouveau trigger actif sur trips.status = "started"';
  ELSE
    RAISE EXCEPTION '❌ ERREUR: Le trigger n''a pas été créé correctement';
  END IF;
END $$;

-- Vérifier que l'ancien trigger est désactivé
DO $$
DECLARE
  old_trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM pg_trigger 
    WHERE tgname = 'trigger_spend_token_on_trip_offer_acceptance'
  ) INTO old_trigger_exists;

  IF old_trigger_exists THEN
    RAISE WARNING '⚠️  L''ancien trigger est toujours actif sur trip_offers. Désactivation recommandée.';
  ELSE
    RAISE NOTICE '✅ Ancien trigger correctement désactivé';
  END IF;
END $$;
