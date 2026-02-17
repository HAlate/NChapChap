-- ========================================
-- VÉRIFICATION ET ACTIVATION DU REALTIME
-- ========================================
-- Ce script vérifie et active le Realtime sur la table trip_offers

-- 1. Vérifier si REPLICA IDENTITY est configuré
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN relreplident = 'f' THEN 'FULL'
        WHEN relreplident = 'd' THEN 'DEFAULT'
        WHEN relreplident = 'i' THEN 'INDEX'
        WHEN relreplident = 'n' THEN 'NOTHING'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_stat_user_tables psut ON c.oid = psut.relid
WHERE tablename = 'trip_offers'
    AND schemaname = 'public';

-- 2. Activer REPLICA IDENTITY FULL (nécessaire pour Realtime)
-- Cela permet à Supabase Realtime de capturer toutes les colonnes lors des UPDATE/DELETE
ALTER TABLE public.trip_offers REPLICA IDENTITY FULL;

-- 3. Vérifier à nouveau la configuration
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN relreplident = 'f' THEN 'FULL'
        WHEN relreplident = 'd' THEN 'DEFAULT'
        WHEN relreplident = 'i' THEN 'INDEX'
        WHEN relreplident = 'n' THEN 'NOTHING'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_stat_user_tables psut ON c.oid = psut.relid
WHERE tablename = 'trip_offers'
    AND schemaname = 'public';

-- ========================================
-- INSTRUCTIONS SUPPLÉMENTAIRES
-- ========================================
-- 
-- APRÈS avoir exécuté ce script, vous DEVEZ également:
-- 
-- 1. Aller dans Supabase Dashboard
-- 2. Naviguer vers: Database → Replication
-- 3. Trouver la table "trip_offers"
-- 4. Activer la réplication (cocher la case)
-- 5. Cliquer sur "Save" pour appliquer les changements
--
-- Sans cette étape dans le Dashboard, le Realtime ne fonctionnera PAS
-- même si REPLICA IDENTITY est configuré correctement.
--
-- ========================================

-- 4. Vérifier les publications (pub/sub Postgres)
SELECT 
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- 5. Vérifier si trip_offers est dans la publication
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
    AND tablename = 'trip_offers';

-- Si la table n'apparaît pas dans les résultats ci-dessus,
-- c'est que le Realtime n'est PAS activé pour cette table.
-- Vous devez l'activer via le Dashboard Supabase.
