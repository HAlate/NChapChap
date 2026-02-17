-- ========================================
-- CORRECTION: Déduire le jeton au DÉMARRAGE de la course
-- ========================================
-- Le jeton doit être déduit quand trips.status passe à 'started'
-- et non à l'acceptation de l'offre (pour gérer les No Show)

-- 1. Supprimer l'ancien trigger sur trip_offers (s'il existe)
DROP TRIGGER IF EXISTS trigger_spend_token_on_offer_acceptance ON trip_offers;
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- 2. Créer le nouveau trigger sur la table TRIPS
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_start ON trips;

-- 3. Créer la fonction de déduction de jeton au démarrage
CREATE OR REPLACE FUNCTION spend_token_on_trip_start()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_balance INT;
  v_offer_id UUID;
BEGIN
  -- Vérifie si status passe à 'started' (driver démarre la course)
  IF NEW.status = 'started' AND (OLD.status IS NULL OR OLD.status != 'started') THEN

    -- Vérifier que le driver est assigné
    IF NEW.driver_id IS NULL THEN
      RAISE EXCEPTION 'Aucun driver assigné pour ce trip';
    END IF;

    -- Récupère le solde actuel du driver
    SELECT balance INTO current_balance
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Vérifie que le driver a au moins 1 jeton
    IF current_balance IS NULL OR current_balance < 1 THEN
      RAISE EXCEPTION 'Le driver n''a pas assez de jetons (besoin: 1, disponible: %)', COALESCE(current_balance, 0);
    END IF;

    -- Déduit 1 jeton
    UPDATE token_balances
    SET balance = balance - 1,
        updated_at = NOW()
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Récupérer l'ID de l'offre acceptée pour la marquer
    SELECT id INTO v_offer_id
    FROM trip_offers
    WHERE trip_id = NEW.id
      AND status = 'accepted'
    LIMIT 1;

    -- Marquer l'offre comme ayant dépensé un jeton
    IF v_offer_id IS NOT NULL THEN
      UPDATE trip_offers
      SET token_spent = true
      WHERE id = v_offer_id;
    END IF;

    -- Enregistre la transaction
    INSERT INTO token_transactions (
      user_id,
      transaction_type,
      token_type,
      amount,
      balance_before,
      balance_after,
      reference_id,
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
      'Jeton dépensé au démarrage de la course',
      NOW()
    );

    RAISE NOTICE 'Jeton déduit pour le driver % au démarrage du trip %', NEW.driver_id, NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Créer le trigger sur trips
CREATE TRIGGER trigger_spend_token_on_trip_start
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_start();

-- 5. Commentaires
COMMENT ON FUNCTION spend_token_on_trip_start IS
'Déduit 1 jeton du driver quand il démarre la course (trips.status = started). Permet de gérer les No Show sans pénaliser le driver.';

COMMENT ON TRIGGER trigger_spend_token_on_trip_start ON trips IS
'Déclenché avant UPDATE sur trips pour déduire le jeton au démarrage de la course, pas à l''acceptation.';

-- 6. Vérifier la configuration
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    proname AS function_name
FROM pg_trigger
JOIN pg_proc ON pg_trigger.tgfoid = pg_proc.oid
WHERE tgname LIKE '%token%'
ORDER BY table_name, trigger_name;
