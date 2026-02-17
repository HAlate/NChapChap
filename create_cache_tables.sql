-- =====================================================
-- Tables de Cache pour Mapbox
-- =====================================================
-- Script SQL pour créer les tables de cache geocoding et routes
-- avec fonctions pour gérer les statistiques

-- =====================================================
-- 1. TABLE: geocode_cache
-- Cache pour les recherches d'adresses et reverse geocoding
-- =====================================================

CREATE TABLE IF NOT EXISTS public.geocode_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cache_key TEXT NOT NULL UNIQUE,
    query TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    results JSONB NOT NULL,
    hit_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_geocode_cache_key ON public.geocode_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_query ON public.geocode_cache(query);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_expires ON public.geocode_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_geocode_cache_coords ON public.geocode_cache(latitude, longitude);

-- Commentaires
COMMENT ON TABLE public.geocode_cache IS 'Cache pour les requêtes de geocoding Mapbox';
COMMENT ON COLUMN public.geocode_cache.cache_key IS 'Hash unique de la requête (SHA-256)';
COMMENT ON COLUMN public.geocode_cache.query IS 'Requête de recherche originale';
COMMENT ON COLUMN public.geocode_cache.results IS 'Résultats JSON de la requête';
COMMENT ON COLUMN public.geocode_cache.hit_count IS 'Nombre de fois que cette entrée a été utilisée';
COMMENT ON COLUMN public.geocode_cache.expires_at IS 'Date d''expiration du cache (7 jours par défaut)';

-- =====================================================
-- 2. TABLE: route_cache
-- Cache pour les itinéraires calculés
-- =====================================================

CREATE TABLE IF NOT EXISTS public.route_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cache_key TEXT NOT NULL UNIQUE,
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lng DOUBLE PRECISION NOT NULL,
    destination_lat DOUBLE PRECISION NOT NULL,
    destination_lng DOUBLE PRECISION NOT NULL,
    profile TEXT DEFAULT 'driving-traffic',
    route_data JSONB NOT NULL,
    distance_meters DOUBLE PRECISION,
    duration_seconds DOUBLE PRECISION,
    hit_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_route_cache_key ON public.route_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_route_cache_origin ON public.route_cache(origin_lat, origin_lng);
CREATE INDEX IF NOT EXISTS idx_route_cache_destination ON public.route_cache(destination_lat, destination_lng);
CREATE INDEX IF NOT EXISTS idx_route_cache_expires ON public.route_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_route_cache_profile ON public.route_cache(profile);

-- Commentaires
COMMENT ON TABLE public.route_cache IS 'Cache pour les itinéraires Mapbox';
COMMENT ON COLUMN public.route_cache.cache_key IS 'Hash unique origine+destination+profile (SHA-256)';
COMMENT ON COLUMN public.route_cache.profile IS 'Type d''itinéraire: driving-traffic, driving, walking, cycling';
COMMENT ON COLUMN public.route_cache.route_data IS 'Données complètes de l''itinéraire (polyline, steps, etc.)';
COMMENT ON COLUMN public.route_cache.hit_count IS 'Nombre de fois que cette route a été utilisée';
COMMENT ON COLUMN public.route_cache.expires_at IS 'Date d''expiration du cache (5 minutes pour trafic)';

-- =====================================================
-- 3. FONCTION: Incrémenter le compteur de geocode_cache
-- =====================================================

CREATE OR REPLACE FUNCTION public.increment_geocode_cache_hit(cache_key_param TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.geocode_cache
    SET 
        hit_count = hit_count + 1,
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
        hit_count = hit_count + 1,
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
        COALESCE(SUM(hit_count), 0)::BIGINT AS total_hits,
        ROUND(AVG(hit_count)::NUMERIC, 2) AS avg_hits_per_entry,
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
        COALESCE(SUM(hit_count), 0)::BIGINT AS total_hits,
        ROUND(AVG(hit_count)::NUMERIC, 2) AS avg_hits_per_entry,
        COUNT(*) FILTER (WHERE expires_at < NOW())::BIGINT AS expired_entries,
        COUNT(*) FILTER (WHERE expires_at >= NOW())::BIGINT AS active_entries,
        ROUND((pg_total_relation_size('public.route_cache')::NUMERIC / 1024 / 1024), 2) AS cache_size_mb,
        ROUND((AVG(distance_meters) / 1000)::NUMERIC, 2) AS avg_distance_km,
        ROUND((AVG(duration_seconds) / 60)::NUMERIC, 2) AS avg_duration_min
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
    query,
    latitude,
    longitude,
    hit_count,
    created_at,
    expires_at,
    CASE 
        WHEN expires_at >= NOW() THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM public.geocode_cache
ORDER BY hit_count DESC
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
    ROUND((distance_meters / 1000)::NUMERIC, 2) AS distance_km,
    ROUND((duration_seconds / 60)::NUMERIC, 2) AS duration_min,
    hit_count,
    created_at,
    expires_at,
    CASE 
        WHEN expires_at >= NOW() THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM public.route_cache
ORDER BY hit_count DESC
LIMIT 20;

COMMENT ON VIEW public.top_routes IS 'Top 20 des routes les plus utilisées';

-- =====================================================
-- 10. POLITIQUES RLS (Row Level Security)
-- =====================================================

-- Activer RLS sur les tables
ALTER TABLE public.geocode_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_cache ENABLE ROW LEVEL SECURITY;

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
-- 11. TÂCHE CRON: Nettoyage automatique quotidien
-- =====================================================

-- Note: Ceci nécessite l'extension pg_cron
-- À exécuter via Supabase Dashboard > SQL Editor

/*
SELECT cron.schedule(
    'clean-expired-caches-daily',
    '0 2 * * *', -- Tous les jours à 2h du matin
    $$ SELECT public.clean_expired_caches(); $$
);
*/

-- =====================================================
-- 12. GRANTS: Permissions
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
-- FIN DU SCRIPT
-- =====================================================

-- Vérification de l'installation
SELECT 'Geocode Cache Table Created' AS status FROM public.geocode_cache LIMIT 1;
SELECT 'Route Cache Table Created' AS status FROM public.route_cache LIMIT 1;
SELECT * FROM public.get_geocode_cache_stats();
SELECT * FROM public.get_route_cache_stats();
