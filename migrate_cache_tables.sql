-- =====================================================
-- MIGRATION: Ajouter les colonnes et fonctionnalités manquantes
-- =====================================================
-- Script pour mettre à jour les tables de cache existantes

-- =====================================================
-- 1. VÉRIFIER ET MODIFIER geocode_cache
-- =====================================================

-- Ajouter la colonne 'query' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'geocode_cache' 
        AND column_name = 'query'
    ) THEN
        ALTER TABLE public.geocode_cache ADD COLUMN query TEXT;
        COMMENT ON COLUMN public.geocode_cache.query IS 'Requête de recherche originale';
    END IF;
END $$;

-- Ajouter la colonne 'hit_count' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'geocode_cache' 
        AND column_name = 'hit_count'
    ) THEN
        ALTER TABLE public.geocode_cache ADD COLUMN hit_count INTEGER DEFAULT 1;
        COMMENT ON COLUMN public.geocode_cache.hit_count IS 'Nombre de fois que cette entrée a été utilisée';
    END IF;
END $$;

-- Ajouter la colonne 'updated_at' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'geocode_cache' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.geocode_cache ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Créer les index seulement si les colonnes existent
CREATE INDEX IF NOT EXISTS idx_geocode_cache_key ON public.geocode_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_expires ON public.geocode_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_coords ON public.geocode_cache(latitude, longitude);

-- Index sur 'query' seulement si la colonne existe
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'geocode_cache' 
        AND column_name = 'query'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_geocode_cache_query ON public.geocode_cache(query);
    END IF;
END $$;

-- =====================================================
-- 2. VÉRIFIER ET MODIFIER route_cache
-- =====================================================

-- Ajouter la colonne 'hit_count' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'route_cache' 
        AND column_name = 'hit_count'
    ) THEN
        ALTER TABLE public.route_cache ADD COLUMN hit_count INTEGER DEFAULT 1;
        COMMENT ON COLUMN public.route_cache.hit_count IS 'Nombre de fois que cette route a été utilisée';
    END IF;
END $$;

-- Ajouter la colonne 'updated_at' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'route_cache' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.route_cache ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Ajouter la colonne 'distance_meters' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'route_cache' 
        AND column_name = 'distance_meters'
    ) THEN
        ALTER TABLE public.route_cache ADD COLUMN distance_meters DOUBLE PRECISION;
    END IF;
END $$;

-- Ajouter la colonne 'duration_seconds' si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'route_cache' 
        AND column_name = 'duration_seconds'
    ) THEN
        ALTER TABLE public.route_cache ADD COLUMN duration_seconds DOUBLE PRECISION;
    END IF;
END $$;

-- Créer les index
CREATE INDEX IF NOT EXISTS idx_route_cache_key ON public.route_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_route_cache_origin ON public.route_cache(origin_lat, origin_lng);
CREATE INDEX IF NOT EXISTS idx_route_cache_destination ON public.route_cache(destination_lat, destination_lng);
CREATE INDEX IF NOT EXISTS idx_route_cache_expires ON public.route_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_route_cache_profile ON public.route_cache(profile);

-- =====================================================
-- 3. FONCTION: Incrémenter le compteur de geocode_cache
-- =====================================================

CREATE OR REPLACE FUNCTION public.increment_geocode_cache_hit(cache_key_param TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.geocode_cache
    SET 
        hit_count = COALESCE(hit_count, 0) + 1,
        updated_at = NOW()
    WHERE cache_key = cache_key_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.increment_geocode_cache_hit IS 'Incrémente le compteur d''utilisation d''une entrée de cache geocoding';

-- =====================================================
-- 4. FONCTION: Incrémenter le compteur de route_cache
-- =====================================================

CREATE OR REPLACE FUNCTION public.increment_route_cache_hit(cache_key_param TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.route_cache
    SET 
        hit_count = COALESCE(hit_count, 0) + 1,
        updated_at = NOW()
    WHERE cache_key = cache_key_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.increment_route_cache_hit IS 'Incrémente le compteur d''utilisation d''une entrée de cache route';

-- =====================================================
-- 5. FONCTION: Statistiques du cache geocoding
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_geocode_cache_stats()
RETURNS TABLE(
    total_entries BIGINT,
    total_hits BIGINT,
    avg_hits_per_entry NUMERIC,
    expired_entries BIGINT,
    active_entries BIGINT,
    cache_size_mb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_entries,
        COALESCE(SUM(COALESCE(hit_count, 1)), 0)::BIGINT AS total_hits,
        ROUND(AVG(COALESCE(hit_count, 1))::NUMERIC, 2) AS avg_hits_per_entry,
        COUNT(*) FILTER (WHERE expires_at < NOW())::BIGINT AS expired_entries,
        COUNT(*) FILTER (WHERE expires_at >= NOW())::BIGINT AS active_entries,
        ROUND((pg_total_relation_size('public.geocode_cache')::NUMERIC / 1024 / 1024), 2) AS cache_size_mb
    FROM public.geocode_cache;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_geocode_cache_stats IS 'Retourne les statistiques du cache geocoding';

-- =====================================================
-- 6. FONCTION: Statistiques du cache routes
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_route_cache_stats()
RETURNS TABLE(
    total_entries BIGINT,
    total_hits BIGINT,
    avg_hits_per_entry NUMERIC,
    expired_entries BIGINT,
    active_entries BIGINT,
    cache_size_mb NUMERIC,
    avg_distance_km NUMERIC,
    avg_duration_min NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_entries,
        COALESCE(SUM(COALESCE(hit_count, 1)), 0)::BIGINT AS total_hits,
        ROUND(AVG(COALESCE(hit_count, 1))::NUMERIC, 2) AS avg_hits_per_entry,
        COUNT(*) FILTER (WHERE expires_at < NOW())::BIGINT AS expired_entries,
        COUNT(*) FILTER (WHERE expires_at >= NOW())::BIGINT AS active_entries,
        ROUND((pg_total_relation_size('public.route_cache')::NUMERIC / 1024 / 1024), 2) AS cache_size_mb,
        ROUND((AVG(COALESCE(distance_meters, 0)) / 1000)::NUMERIC, 2) AS avg_distance_km,
        ROUND((AVG(COALESCE(duration_seconds, 0)) / 60)::NUMERIC, 2) AS avg_duration_min
    FROM public.route_cache;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_route_cache_stats IS 'Retourne les statistiques du cache routes';

-- =====================================================
-- 7. FONCTION: Nettoyage automatique des caches expirés
-- =====================================================

CREATE OR REPLACE FUNCTION public.clean_expired_caches()
RETURNS TABLE(
    geocode_deleted BIGINT,
    route_deleted BIGINT
) AS $$
DECLARE
    geocode_count BIGINT;
    route_count BIGINT;
BEGIN
    -- Nettoyer geocode_cache
    WITH deleted AS (
        DELETE FROM public.geocode_cache
        WHERE expires_at < NOW()
        RETURNING *
    )
    SELECT COUNT(*) INTO geocode_count FROM deleted;

    -- Nettoyer route_cache
    WITH deleted AS (
        DELETE FROM public.route_cache
        WHERE expires_at < NOW()
        RETURNING *
    )
    SELECT COUNT(*) INTO route_count FROM deleted;

    RETURN QUERY SELECT geocode_count, route_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.clean_expired_caches IS 'Supprime toutes les entrées expirées des caches';

-- =====================================================
-- 8. TRIGGER: Auto-update de updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour geocode_cache
DROP TRIGGER IF EXISTS update_geocode_cache_updated_at ON public.geocode_cache;
CREATE TRIGGER update_geocode_cache_updated_at
    BEFORE UPDATE ON public.geocode_cache
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger pour route_cache
DROP TRIGGER IF EXISTS update_route_cache_updated_at ON public.route_cache;
CREATE TRIGGER update_route_cache_updated_at
    BEFORE UPDATE ON public.route_cache
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- 9. VUES: Top des requêtes cachées
-- =====================================================

-- Top 20 des recherches geocoding les plus utilisées
CREATE OR REPLACE VIEW public.top_geocode_queries AS
SELECT 
    cache_key,
    COALESCE(query, 'N/A') as query,
    latitude,
    longitude,
    COALESCE(hit_count, 1) as hit_count,
    created_at,
    expires_at,
    CASE 
        WHEN expires_at >= NOW() THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM public.geocode_cache
ORDER BY COALESCE(hit_count, 1) DESC
LIMIT 20;

COMMENT ON VIEW public.top_geocode_queries IS 'Top 20 des requêtes geocoding les plus utilisées';

-- Top 20 des routes les plus utilisées
CREATE OR REPLACE VIEW public.top_routes AS
SELECT 
    origin_lat,
    origin_lng,
    destination_lat,
    destination_lng,
    profile,
    ROUND((COALESCE(distance_meters, 0) / 1000)::NUMERIC, 2) AS distance_km,
    ROUND((COALESCE(duration_seconds, 0) / 60)::NUMERIC, 2) AS duration_min,
    COALESCE(hit_count, 1) as hit_count,
    created_at,
    expires_at,
    CASE 
        WHEN expires_at >= NOW() THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM public.route_cache
ORDER BY COALESCE(hit_count, 1) DESC
LIMIT 20;

COMMENT ON VIEW public.top_routes IS 'Top 20 des routes les plus utilisées';

-- =====================================================
-- 10. POLITIQUES RLS (Row Level Security)
-- =====================================================

-- Activer RLS sur les tables
ALTER TABLE public.geocode_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_cache ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "Les utilisateurs peuvent lire le cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent lire le cache routes" ON public.route_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent écrire dans le cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent écrire dans le cache routes" ON public.route_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent mettre à jour le cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent mettre à jour le cache routes" ON public.route_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent supprimer les entrées expirées du cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Les utilisateurs peuvent supprimer les entrées expirées du cache routes" ON public.route_cache;

-- Politique pour lire le cache (tous les utilisateurs authentifiés)
CREATE POLICY "Les utilisateurs peuvent lire le cache geocoding"
    ON public.geocode_cache FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Les utilisateurs peuvent lire le cache routes"
    ON public.route_cache FOR SELECT
    TO authenticated
    USING (true);

-- Politique pour écrire dans le cache (tous les utilisateurs authentifiés)
CREATE POLICY "Les utilisateurs peuvent écrire dans le cache geocoding"
    ON public.geocode_cache FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Les utilisateurs peuvent écrire dans le cache routes"
    ON public.route_cache FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Politique pour mettre à jour le cache (tous les utilisateurs authentifiés)
CREATE POLICY "Les utilisateurs peuvent mettre à jour le cache geocoding"
    ON public.geocode_cache FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Les utilisateurs peuvent mettre à jour le cache routes"
    ON public.route_cache FOR UPDATE
    TO authenticated
    USING (true);

-- Politique pour supprimer du cache (seulement les entrées expirées ou propres)
CREATE POLICY "Les utilisateurs peuvent supprimer les entrées expirées du cache geocoding"
    ON public.geocode_cache FOR DELETE
    TO authenticated
    USING (expires_at < NOW());

CREATE POLICY "Les utilisateurs peuvent supprimer les entrées expirées du cache routes"
    ON public.route_cache FOR DELETE
    TO authenticated
    USING (expires_at < NOW());

-- =====================================================
-- 11. GRANTS: Permissions
-- =====================================================

-- Accorder les permissions nécessaires
GRANT SELECT, INSERT, UPDATE, DELETE ON public.geocode_cache TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.route_cache TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_geocode_cache_hit TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_route_cache_hit TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_geocode_cache_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_route_cache_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.clean_expired_caches TO authenticated;
GRANT SELECT ON public.top_geocode_queries TO authenticated;
GRANT SELECT ON public.top_routes TO authenticated;

-- =====================================================
-- 12. VÉRIFICATION DE L'INSTALLATION
-- =====================================================

-- Afficher les statistiques
SELECT 'Migration complete!' AS status;
SELECT * FROM public.get_geocode_cache_stats();
SELECT * FROM public.get_route_cache_stats();
