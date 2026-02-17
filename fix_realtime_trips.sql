-- ========================================
-- FIX: Activer Realtime pour la table trips
-- ========================================

-- 1. Ajouter la table trips à la publication Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE trips;

-- 2. Définir REPLICA IDENTITY FULL pour recevoir toutes les colonnes lors des updates
ALTER TABLE trips REPLICA IDENTITY FULL;

-- ========================================
-- VÉRIFICATION après exécution:
-- ========================================

-- Vérifier que trips est maintenant dans la publication
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'trips';
-- Résultat attendu: 1 ligne avec trips ✅

-- Vérifier REPLICA IDENTITY
SELECT 
    n.nspname as schemaname,
    c.relname as tablename,
    CASE 
        WHEN c.relreplident = 'd' THEN 'DEFAULT (clé primaire uniquement)'
        WHEN c.relreplident = 'f' THEN 'FULL (toutes les colonnes) ✅'
        WHEN c.relreplident = 'i' THEN 'INDEX'
        WHEN c.relreplident = 'n' THEN 'NOTHING'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'trips' AND n.nspname = 'public';
-- Résultat attendu: FULL (toutes les colonnes) ✅
