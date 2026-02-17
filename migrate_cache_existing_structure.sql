-- =====================================================
-- MIGRATION: Adapter aux tables de cache existantes
-- =====================================================
-- Script pour ajouter les fonctions et vues aux tables existantes

-- =====================================================
-- 1. VÉRIFIER route_cache - Ajouter les colonnes manquantes
-- =====================================================

-- Structure attendue pour route_cache (à vérifier/créer)
CREATE TABLE IF NOT EXISTS public.route_cache (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    cache_key TEXT NOT NULL,
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lng DOUBLE PRECISION NOT NULL,
    destination_lat DOUBLE PRECISION NOT NULL,
    destination_lng DOUBLE PRECISION NOT NULL,
    profile TEXT DEFAULT 'driving-traffic',
    polyline TEXT,
    distance_meters DOUBLE PRECISION,
    duration_seconds DOUBLE PRECISION,
    hit_count INTEGER DEFAULT 1,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT route_cache_pkey PRIMARY KEY (id),
    CONSTRAINT route_cache_cache_key_key UNIQUE (cache_key)
);

-- Index pour route_cache
CREATE INDEX IF NOT EXISTS idx_route_cache_key ON public.route_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_route_cache_last_accessed ON public.route_cache(last_accessed_at);
CREATE INDEX IF NOT EXISTS idx_route_cache_origin ON public.route_cache(origin_lat, origin_lng);
CREATE INDEX IF NOT EXISTS idx_route_cache_destination ON public.route_cache(destination_lat, destination_lng);

-- =====================================================
-- 2. FONCTION: Incrémenter le compteur de geocode_cache
-- =====================================================

CREATE OR REPLACE FUNCTION public.increment_geocode_cache_hit(cache_key_param TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.geocode_cache
    SET 
        hit_count = COALESCE(hit_count, 0) + 1,
        last_accessed_at = NOW()
    WHERE cache_key = cache_key_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.increment_geocode_cache_hit IS 'Incrémente le compteur d''utilisation d''une entrée de cache geocoding';

-- =====================================================
-- 3. FONCTION: Incrémenter le compteur de route_cache
-- =====================================================

CREATE OR REPLACE FUNCTION public.increment_route_cache_hit(cache_key_param TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.route_cache
    SET 
        hit_count = COALESCE(hit_count, 0) + 1,
        last_accessed_at = NOW()
    WHERE cache_key = cache_key_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.increment_route_cache_hit IS 'Incrémente le compteur d''utilisation d''une entrée de cache route';

-- =====================================================
-- 4. FONCTION: Statistiques du cache geocoding
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_geocode_cache_stats()
RETURNS TABLE(
    total_entries BIGINT,
    total_hits BIGINT,
    avg_hits_per_entry NUMERIC,
    old_entries BIGINT,
    recent_entries BIGINT,
    cache_size_mb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_entries,
        COALESCE(SUM(COALESCE(hit_count, 1)), 0)::BIGINT AS total_hits,
        ROUND(AVG(COALESCE(hit_count, 1))::NUMERIC, 2) AS avg_hits_per_entry,
        COUNT(*) FILTER (WHERE last_accessed_at < NOW() - INTERVAL '7 days')::BIGINT AS old_entries,
        COUNT(*) FILTER (WHERE last_accessed_at >= NOW() - INTERVAL '7 days')::BIGINT AS recent_entries,
        ROUND((pg_total_relation_size('public.geocode_cache')::NUMERIC / 1024 / 1024), 2) AS cache_size_mb
    FROM public.geocode_cache;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_geocode_cache_stats IS 'Retourne les statistiques du cache geocoding';

-- =====================================================
-- 5. FONCTION: Statistiques du cache routes
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_route_cache_stats()
RETURNS TABLE(
    total_entries BIGINT,
    total_hits BIGINT,
    avg_hits_per_entry NUMERIC,
    old_entries BIGINT,
    recent_entries BIGINT,
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
        COUNT(*) FILTER (WHERE last_accessed_at < NOW() - INTERVAL '5 minutes')::BIGINT AS old_entries,
        COUNT(*) FILTER (WHERE last_accessed_at >= NOW() - INTERVAL '5 minutes')::BIGINT AS recent_entries,
        ROUND((pg_total_relation_size('public.route_cache')::NUMERIC / 1024 / 1024), 2) AS cache_size_mb,
        ROUND((AVG(COALESCE(distance_meters, 0)) / 1000)::NUMERIC, 2) AS avg_distance_km,
        ROUND((AVG(COALESCE(duration_seconds, 0)) / 60)::NUMERIC, 2) AS avg_duration_min
    FROM public.route_cache;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_route_cache_stats IS 'Retourne les statistiques du cache routes';

-- =====================================================
-- 6. FONCTION: Nettoyage automatique des caches anciens
-- =====================================================

CREATE OR REPLACE FUNCTION public.clean_old_caches()
RETURNS TABLE(
    geocode_deleted BIGINT,
    route_deleted BIGINT
) AS $$
DECLARE
    geocode_count BIGINT;
    route_count BIGINT;
BEGIN
    -- Nettoyer geocode_cache (> 30 jours sans accès)
    WITH deleted AS (
        DELETE FROM public.geocode_cache
        WHERE last_accessed_at < NOW() - INTERVAL '30 days'
        RETURNING *
    )
    SELECT COUNT(*) INTO geocode_count FROM deleted;

    -- Nettoyer route_cache (> 1 jour sans accès)
    WITH deleted AS (
        DELETE FROM public.route_cache
        WHERE last_accessed_at < NOW() - INTERVAL '1 day'
        RETURNING *
    )
    SELECT COUNT(*) INTO route_count FROM deleted;

    RETURN QUERY SELECT geocode_count, route_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.clean_old_caches IS 'Supprime les entrées non utilisées depuis longtemps';

-- =====================================================
-- 7. VUES: Top des requêtes cachées
-- =====================================================

-- Top 20 des recherches geocoding les plus utilisées
CREATE OR REPLACE VIEW public.top_geocode_queries AS
SELECT 
    cache_key,
    cache_type,
    name,
    formatted_address,
    latitude,
    longitude,
    COALESCE(hit_count, 1) as hit_count,
    created_at,
    last_accessed_at,
    CASE 
        WHEN last_accessed_at >= NOW() - INTERVAL '7 days' THEN 'Active'
        ELSE 'Old'
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
    last_accessed_at,
    CASE 
        WHEN last_accessed_at >= NOW() - INTERVAL '5 minutes' THEN 'Active'
        ELSE 'Old'
    END AS status
FROM public.route_cache
ORDER BY COALESCE(hit_count, 1) DESC
LIMIT 20;

COMMENT ON VIEW public.top_routes IS 'Top 20 des routes les plus utilisées';

-- =====================================================
-- 8. POLITIQUES RLS (Row Level Security)
-- =====================================================

-- Activer RLS sur les tables
ALTER TABLE public.geocode_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_cache ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "Cache geocoding accessible à tous" ON public.geocode_cache;
DROP POLICY IF EXISTS "Cache routes accessible à tous" ON public.route_cache;
DROP POLICY IF EXISTS "Lecture cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Lecture cache routes" ON public.route_cache;
DROP POLICY IF EXISTS "Écriture cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Écriture cache routes" ON public.route_cache;
DROP POLICY IF EXISTS "Modification cache geocoding" ON public.geocode_cache;
DROP POLICY IF EXISTS "Modification cache routes" ON public.route_cache;

-- Politiques simples: accès total pour authenticated
CREATE POLICY "Cache geocoding accessible à tous"
    ON public.geocode_cache
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Cache routes accessible à tous"
    ON public.route_cache
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 9. GRANTS: Permissions
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.geocode_cache TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.route_cache TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_geocode_cache_hit TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_route_cache_hit TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_geocode_cache_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_route_cache_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.clean_old_caches TO authenticated;
GRANT SELECT ON public.top_geocode_queries TO authenticated;
GRANT SELECT ON public.top_routes TO authenticated;

-- =====================================================
-- 10. VÉRIFICATION DE L'INSTALLATION
-- =====================================================

SELECT 'Migration complete!' AS status;
SELECT * FROM public.get_geocode_cache_stats();
SELECT * FROM public.get_route_cache_stats();
