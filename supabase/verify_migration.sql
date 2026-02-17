-- Script de Vérification de la Migration Supabase UUMO
-- Exécutez ce script après la migration pour vérifier que tout est en place

-- ============================================
-- 1. VÉRIFICATION DES EXTENSIONS
-- ============================================
SELECT 
    'Extensions' as verification_type,
    extname as name,
    '✅ Installée' as status
FROM pg_extension
WHERE extname IN ('postgis', 'postgis_topology', 'pg_cron', 'uuid-ossp')
ORDER BY extname;

-- ============================================
-- 2. VÉRIFICATION DES TYPES ENUM
-- ============================================
SELECT 
    'Types ENUM' as verification_type,
    typname as name,
    '✅ Créé' as status
FROM pg_type
WHERE typtype = 'e'
AND typname IN (
    'user_type',
    'user_status', 
    'vehicle_type',
    'payment_method',
    'token_type',
    'transaction_type',
    'trip_status',
    'offer_status',
    'order_status',
    'delivery_request_status',
    'provider_type',
    'payment_type_enum',
    'payment_status_enum'
)
ORDER BY typname;

-- ============================================
-- 3. VÉRIFICATION DES TABLES PRINCIPALES
-- ============================================
SELECT 
    'Tables Principales' as verification_type,
    table_name as name,
    CASE 
        WHEN table_name IS NOT NULL THEN '✅ Créée'
        ELSE '❌ Manquante'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'users',
    'token_packages',
    'token_balances',
    'token_transactions',
    'trips',
    'trip_offers',
    'orders',
    'delivery_requests',
    'delivery_offers',
    'driver_profiles',
    'merchant_profiles',
    'restaurant_profiles',
    'products',
    'menu_items',
    'payments'
)
ORDER BY table_name;

-- ============================================
-- 4. VÉRIFICATION DES INDEX
-- ============================================
SELECT 
    'Index' as verification_type,
    schemaname || '.' || tablename as table_name,
    indexname as name,
    '✅ Créé' as status
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('users', 'trips', 'trip_offers', 'token_balances', 'token_transactions')
ORDER BY tablename, indexname;

-- ============================================
-- 5. VÉRIFICATION DES FONCTIONS
-- ============================================
SELECT 
    'Fonctions' as verification_type,
    routine_name as name,
    '✅ Créée' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- ============================================
-- 6. VÉRIFICATION DES TRIGGERS
-- ============================================
SELECT 
    'Triggers' as verification_type,
    event_object_table as table_name,
    trigger_name as name,
    action_timing || ' ' || event_manipulation as timing,
    '✅ Actif' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============================================
-- 7. VÉRIFICATION DES POLITIQUES RLS
-- ============================================
SELECT 
    'Politiques RLS' as verification_type,
    schemaname || '.' || tablename as table_name,
    policyname as name,
    CASE 
        WHEN cmd = 'r' THEN 'SELECT'
        WHEN cmd = 'a' THEN 'INSERT'
        WHEN cmd = 'w' THEN 'UPDATE'
        WHEN cmd = 'd' THEN 'DELETE'
        ELSE cmd
    END as command,
    '✅ Active' as status
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================
-- 8. VÉRIFICATION RLS ACTIVÉ SUR LES TABLES
-- ============================================
SELECT 
    'RLS Activé' as verification_type,
    schemaname || '.' || tablename as table_name,
    CASE 
        WHEN rowsecurity = true THEN '✅ Activé'
        ELSE '⚠️ Désactivé'
    END as status
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
    'users', 'token_packages', 'token_balances', 'token_transactions',
    'trips', 'trip_offers', 'orders', 'delivery_requests', 'delivery_offers',
    'driver_profiles', 'merchant_profiles', 'restaurant_profiles', 'products', 'menu_items', 'payments'
)
ORDER BY tablename;

-- ============================================
-- 9. VÉRIFICATION DES VUES
-- ============================================
SELECT 
    'Vues' as verification_type,
    table_name as name,
    '✅ Créée' as status
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- ============================================
-- 10. STATISTIQUES GÉNÉRALES
-- ============================================
SELECT 
    'Statistiques' as type,
    'Tables publiques' as item,
    COUNT(*)::text as count
FROM information_schema.tables
WHERE table_schema = 'public'
UNION ALL
SELECT 
    'Statistiques',
    'Types ENUM',
    COUNT(*)::text
FROM pg_type
WHERE typtype = 'e'
UNION ALL
SELECT 
    'Statistiques',
    'Fonctions',
    COUNT(*)::text
FROM information_schema.routines
WHERE routine_schema = 'public'
UNION ALL
SELECT 
    'Statistiques',
    'Triggers',
    COUNT(DISTINCT trigger_name)::text
FROM information_schema.triggers
WHERE trigger_schema = 'public'
UNION ALL
SELECT 
    'Statistiques',
    'Politiques RLS',
    COUNT(*)::text
FROM pg_policies
WHERE schemaname = 'public';

-- ============================================
-- 11. VÉRIFICATION DES CONTRAINTES
-- ============================================
SELECT 
    'Contraintes' as verification_type,
    table_name,
    constraint_name as name,
    constraint_type as type,
    '✅ Créée' as status
FROM information_schema.table_constraints
WHERE table_schema = 'public'
AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK')
ORDER BY table_name, constraint_type, constraint_name;

-- ============================================
-- 12. VÉRIFICATION DES DONNÉES DE TEST
-- ============================================

-- Token Packages
SELECT 
    'Données' as verification_type,
    'Token Packages' as table_name,
    COUNT(*)::text || ' packages' as count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Présent'
        ELSE '⚠️ Vide'
    END as status
FROM token_packages;

-- ============================================
-- 13. RÉSUMÉ FINAL
-- ============================================
SELECT 
    '==========================================',
    'RÉSUMÉ DE LA MIGRATION',
    '==========================================';

-- Compte rapide
WITH stats AS (
    SELECT 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public') as tables,
        (SELECT COUNT(*) FROM pg_type WHERE typtype = 'e') as enums,
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public') as functions,
        (SELECT COUNT(DISTINCT trigger_name) FROM information_schema.triggers WHERE trigger_schema = 'public') as triggers,
        (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public') as policies,
        (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public') as views
)
SELECT 
    '📊 STATISTIQUES' as section,
    'Tables: ' || tables::text as detail
FROM stats
UNION ALL
SELECT '📊 STATISTIQUES', 'Types ENUM: ' || enums::text FROM stats
UNION ALL
SELECT '📊 STATISTIQUES', 'Fonctions: ' || functions::text FROM stats
UNION ALL
SELECT '📊 STATISTIQUES', 'Triggers: ' || triggers::text FROM stats
UNION ALL
SELECT '📊 STATISTIQUES', 'Politiques RLS: ' || policies::text FROM stats
UNION ALL
SELECT '📊 STATISTIQUES', 'Vues: ' || views::text FROM stats;

-- Message final
SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public') >= 15
        THEN '✅ MIGRATION RÉUSSIE - Tous les composants essentiels sont en place!'
        ELSE '⚠️ MIGRATION INCOMPLÈTE - Vérifiez les erreurs ci-dessus'
    END as status;

-- ============================================
-- FIN DU SCRIPT DE VÉRIFICATION
-- ============================================
