-- ========================================
-- Ajout du statut 'arrived_waiting' à l'enum trip_status
-- ========================================
-- Ce statut permet de gérer la période d'attente du chauffeur au point de départ
-- avant le démarrage effectif de la course

-- Vérifier si le type existe et ajouter la valeur si elle n'existe pas
DO $$
BEGIN
    -- Tenter d'ajouter la valeur 'arrived_waiting' à l'enum trip_status
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'trip_status' 
        AND e.enumlabel = 'arrived_waiting'
    ) THEN
        ALTER TYPE trip_status ADD VALUE 'arrived_waiting' AFTER 'accepted';
        RAISE NOTICE 'Statut arrived_waiting ajouté avec succès';
    ELSE
        RAISE NOTICE 'Statut arrived_waiting existe déjà';
    END IF;
END$$;

-- Vérification
SELECT enumlabel as "Statuts disponibles"
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'trip_status'
ORDER BY e.enumsortorder;

-- Documentation du nouveau statut
COMMENT ON TYPE trip_status IS 
'Statuts possibles pour un trip:
- pending: En attente d''un chauffeur
- accepted: Chauffeur accepté, en route vers le point de départ
- arrived_waiting: Chauffeur arrivé au point de départ, en attente du passager (nouveau statut pour gérer No Show)
- started: Course en cours
- completed: Course terminée
- cancelled: Course annulée';
