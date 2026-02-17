-- =========================================
-- FIX: Corriger le trigger de déduction de tokens au démarrage
-- =========================================
-- Erreur: column "reason" does not exist in token_transactions
-- Solution: Utiliser 'notes' au lieu de 'reason' et 'reference_id' au lieu de 'related_id'

-- =========================================
-- 1. Supprimer l'ancien trigger défectueux
-- =========================================
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_start ON trips;
DROP FUNCTION IF EXISTS spend_token_on_trip_start();

-- =========================================
-- 2. Créer la fonction corrigée
-- =========================================
CREATE OR REPLACE FUNCTION spend_token_on_trip_start()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  token_balance_record RECORD;
BEGIN
  -- Seulement si le statut passe à 'started' (Aller vers la destination)
  IF NEW.status = 'started' AND (OLD.status IS NULL OR OLD.status != 'started') THEN
    
    -- Vérifie le solde de jetons du DRIVER (pas le rider!)
    SELECT * INTO token_balance_record
    FROM token_balances
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- NE PAS BLOQUER si le solde est insuffisant - la course a déjà été acceptée
    -- On déduit seulement si le solde est suffisant
    IF FOUND AND token_balance_record.balance >= 1 THEN
      
      -- Déduit 1 jeton du DRIVER
      UPDATE token_balances
      SET balance = balance - 1,
          updated_at = NOW()
      WHERE user_id = NEW.driver_id
        AND token_type = 'course';

      -- Enregistre la transaction (utilise 'notes' au lieu de 'reason')
      INSERT INTO token_transactions (
        user_id,
        transaction_type,
        token_type,
        amount,
        balance_before,
        balance_after,
        reference_id,
        notes
      ) VALUES (
        NEW.driver_id,
        'spend',
        'course',
        -1,
        token_balance_record.balance,
        token_balance_record.balance - 1,
        NEW.id,
        'Course démarrée - Trip ID: ' || NEW.id
      );

      RAISE NOTICE 'Token déduit pour le driver % au démarrage de la course %', NEW.driver_id, NEW.id;
    
    ELSE
      -- Solde insuffisant mais on continue quand même
      RAISE NOTICE 'Solde de jetons insuffisant pour le driver % mais la course continue (Trip: %)', NEW.driver_id, NEW.id;
    END IF;

  END IF;

  RETURN NEW;
END;
$$;

-- =========================================
-- 2.5. Créer les policies RLS pour token_transactions
-- =========================================

-- Supprimer les anciennes policies conflictuelles
DROP POLICY IF EXISTS "Allow trigger to insert token_transactions" ON token_transactions;
DROP POLICY IF EXISTS "System can insert token_transactions" ON token_transactions;

-- Créer une policy permissive pour les insertions par le trigger
CREATE POLICY "Allow trigger to insert token_transactions"
  ON token_transactions
  FOR INSERT
  WITH CHECK (true);

-- Policy pour que les users puissent voir leurs propres transactions
DROP POLICY IF EXISTS "Users can view own transactions" ON token_transactions;
CREATE POLICY "Users can view own transactions"
  ON token_transactions
  FOR SELECT
  USING (user_id = auth.uid());

-- S'assurer que RLS est activé
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;

-- =========================================
-- 3. Créer le trigger
-- =========================================
CREATE TRIGGER trigger_spend_token_on_trip_start
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_start();

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que le trigger existe
SELECT 
  '✅ Trigger créé' as check_category,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled
FROM pg_trigger
WHERE tgname = 'trigger_spend_token_on_trip_start';

-- Test 2: Vérifier que la fonction existe
SELECT 
  '✅ Fonction créée' as check_category,
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'spend_token_on_trip_start';

-- Test 3: Vérifier les colonnes de token_transactions
SELECT 
  '✅ Colonnes token_transactions' as check_category,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'token_transactions'
  AND column_name IN ('notes', 'reference_id', 'user_id', 'amount')
ORDER BY column_name;

-- =========================================
-- RÉSUMÉ
-- =========================================
SELECT 
  '=========================================' as separator,
  'TRIGGER DE DÉDUCTION CORRIGÉ' as titre,
  '=========================================' as separator2
UNION ALL
SELECT 
  '✅ Trigger trigger_spend_token_on_trip_start créé' as info,
  '' as col2,
  '' as col3
UNION ALL
SELECT 
  '✅ Utilise "notes" au lieu de "reason"' as info,
  '' as col2,
  '' as col3
UNION ALL
SELECT 
  '✅ Utilise "reference_id" pour stocker trip_id' as info,
  '' as col2,
  '' as col3
UNION ALL
SELECT 
  '⚡ Déduction au moment de "Aller vers la destination"' as info,
  '' as col2,
  '' as col3;

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1️⃣  Hot restart des apps mobile' as etape_1,
  '2️⃣  Testez "Aller à la destination"' as etape_2,
  '3️⃣  1 jeton sera déduit automatiquement' as etape_3,
  '4️⃣  Vérifiez avec: SELECT * FROM token_transactions ORDER BY created_at DESC LIMIT 5;' as etape_4;

-- =========================================
-- NOTES
-- =========================================
-- Le jeton est déduit du DRIVER (driver_id) quand il clique
-- "Aller vers la destination" (status passe à 'started').
-- 
-- Colonnes utilisées dans token_transactions:
-- - notes (au lieu de reason) : Description de la transaction
-- - reference_id : ID du trip associé
-- - transaction_type : 'spend' pour les dépenses
-- - amount : -1 pour déduire un jeton
-- 
-- MODÈLE ÉCONOMIQUE CHAPCHAP:
-- 1. Le DRIVER achète des jetons via Mobile Money (in-app) auprès de CHAPCHAP
--    - Pack Standard: 200 F CFA = 10 jetons (20 F/jeton)
--    - Pack Premium: 1000 F CFA = 60 jetons (50 + 10 bonus) (16,67 F/jeton)
-- 2. Le DRIVER dépense 1 jeton par course acceptée (déduction au démarrage)
-- 3. Le RIDER paie le DRIVER DIRECTEMENT (cash/mobile money hors app)
-- 4. CHAPCHAP gagne uniquement sur la vente des jetons (pas de commission sur les courses)
-- 5. 100% du prix de la course revient au driver
--
-- OBJECTIF 3 MOIS: 5000 chauffeurs × 10 courses/jour = 50 000 courses/jour
-- Revenus: 50 000 × 20 F = 1 000 000 F CFA/jour = 30 000 000 F CFA/mois
-- Marché potentiel: 1 million de courses/jour dans la ville du premier déploiement
--
-- Mobile Money dans l'app = uniquement pour l'achat de jetons par le driver
-- Le rider ne gère pas de jetons, il paie le driver directement en personne.
-- Déploiement: Afrique de l'Ouest (numéro téléphone pour encaissements Mobile Money)
     