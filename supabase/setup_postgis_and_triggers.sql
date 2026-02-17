-- =================================================================
-- SCRIPT DE CONFIGURATION GÉOSPATIALE COMPLET
-- À exécuter une seule fois dans l'éditeur SQL de Supabase.
-- =================================================================

-- 1. ACTIVER L'EXTENSION POSTGIS (LA CORRECTION PRINCIPALE)
-- Cette commande ajoute le support pour les types et fonctions géospatiales.
CREATE EXTENSION IF NOT EXISTS postgis;


-- 2. CRÉATION DE L'INDEX SPATIAL (OPTIMISATION)
-- Crée un index sur les coordonnées géographiques des chauffeurs pour des recherches rapides.
-- La syntaxe avec les doubles parenthèses est la bonne.
CREATE INDEX IF NOT EXISTS idx_driver_profiles_location
ON public.driver_profiles
USING GIST ( (ST_MakePoint(current_lng, current_lat)::geography) );


-- 3. MISE À JOUR DE LA FONCTION TRIGGER
-- Cette fonction est appelée à chaque fois qu'une nouvelle course est créée.
CREATE OR REPLACE FUNCTION public.notify_nearby_drivers()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- S'exécute avec des droits élevés pour pouvoir insérer des notifications.
SET search_path = public
AS $$
DECLARE
    driver_record RECORD;
BEGIN
    -- Pour chaque chauffeur en ligne dans un rayon de 2km...
    FOR driver_record IN
        SELECT id FROM public.driver_profiles
        WHERE is_online = TRUE
          AND vehicle_type = NEW.vehicle_type
          AND ST_DWithin(
                (ST_MakePoint(current_lng, current_lat)::geography),
                ST_MakePoint(NEW.departure_lng, NEW.departure_lat)::geography,
                2000 -- Rayon de 2km en mètres
            )
    LOOP
        -- ...on insère une notification pour lui.
        INSERT INTO public.notifications (user_id, trip_id, title, body)
        VALUES (driver_record.id, NEW.id, 'Nouvelle course disponible !', 'Une nouvelle demande de course est disponible près de vous.');
    END LOOP;
    RETURN NEW;
END;
$$;


-- 4. S'ASSURER QUE LE TRIGGER EST BIEN EN PLACE
-- Il se déclenche APRÈS chaque insertion dans la table 'trips'.
CREATE OR REPLACE TRIGGER on_new_trip_created
AFTER INSERT ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.notify_nearby_drivers();