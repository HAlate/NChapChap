-- =========================================
-- FIX: Suppression des triggers token obsolètes
-- =========================================
-- Les triggers de déduction de tokens causent des erreurs car la colonne 'reason' n'existe pas
-- Solution: Désactiver/Supprimer tous les triggers liés aux tokens

-- =========================================
-- 1. Supprimer les triggers sur trip_offers
-- =========================================
DROP TRIGGER IF EXISTS trigger_spend_token_on_offer_acceptance ON trip_offers;
DROP TRIGGER IF EXISTS trigger_token_deduction_on_offer ON trip_offers;
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- =========================================
-- 2. Supprimer les triggers sur trips
-- =========================================
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_start ON trips;
DROP TRIGGER IF EXISTS trigger_token_deduction_on_trip_start ON trips;
DROP TRIGGER IF EXISTS handle_trip_status_change ON trips;
DROP TRIGGER IF EXISTS trigger_deduct_token_on_trip_start ON trips;

-- =========================================
-- 3. Supprimer les triggers sur orders (si présents)
-- =========================================
DROP TRIGGER IF EXISTS trigger_spend_token_on_order_acceptance ON orders;
DROP TRIGGER IF EXISTS trigger_token_deduction_on_order ON orders;

-- =========================================
-- 4. Supprimer les fonctions trigger obsolètes
-- =========================================
DROP FUNCTION IF EXISTS spend_token_on_trip_offer_acceptance();
DROP FUNCTION IF EXISTS spend_token_on_trip_start();
DROP FUNCTION IF EXISTS handle_trip_status_change();
DROP FUNCTION IF EXISTS deduct_token_on_trip_start();
DROP FUNCTION IF EXISTS spend_token_on_order_acceptance();

-- =========================================
-- 5. VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier qu'il n'y a plus de triggers token
SELECT 
  '✅ Triggers supprimés' as check_category,
  tgname as trigger_name,
  tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgname LIKE '%token%' OR tgname LIKE '%spend%'
ORDER BY tgrelid::regclass, tgname;

-- Test 2: Vérifier qu'il n'y a plus de fonctions trigger token
SELECT 
  '✅ Fonctions trigger supprimées' as check_category,
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname LIKE '%token%' OR proname LIKE '%spend%'
ORDER BY proname;

-- =========================================
-- RÉSUMÉ
-- =========================================
SELECT 
  '=========================================' as separator,
  'SYSTÈME DE TOKENS DÉSACTIVÉ' as titre,
  '=========================================' as separator2
UNION ALL
SELECT 
  '✅ Tous les triggers de déduction de tokens ont été supprimés' as info,
  '' as col2,
  '' as col3
UNION ALL
SELECT 
  '✅ Les fonctions trigger obsolètes ont été supprimées' as info,
  '' as col2,
  '' as col3
UNION ALL
SELECT 
  '✅ Les courses peuvent maintenant démarrer sans erreur' as info,
  '' as col2,
  '' as col3;

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1️⃣  Hot restart des apps mobile' as etape_1,
  '2️⃣  Testez "Allez à la destination"' as etape_2,
  '3️⃣  Plus d''erreur "reason does not exist"' as etape_3;

-- =========================================
-- NOTES
-- =========================================
-- Le système de tokens a été supprimé de l'interface utilisateur.
-- Ces triggers causaient des erreurs car ils essayaient d'utiliser
-- la colonne 'reason' qui n'existe pas dans token_transactions.
-- 
-- Les tables token_* restent en place pour l'historique,
-- mais aucune déduction automatique n'est plus effectuée.
