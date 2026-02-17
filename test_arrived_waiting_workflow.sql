-- ========================================
-- Test complet workflow arrived_waiting
-- ========================================

-- 1. Vérifier que l'enum contient bien arrived_waiting
SELECT enumlabel as "Valeurs enum trip_status"
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'trip_status'
ORDER BY e.enumsortorder;

-- 2. Vérifier le trip spécifique qui pose problème
SELECT 
    id,
    status,
    driver_arrived_notification,
    created_at,
    departure,
    destination
FROM trips
WHERE id = 'a3bb9ed5-21c1-45bb-a3ed-327689a78b06';

-- 3. Tester le changement de statut (REMPLACER trip_id par un vrai)
-- UPDATE trips 
-- SET status = 'arrived_waiting'
-- WHERE id = 'a515f059-8574-4ba7-ae59-0bdfe907f24e';

-- 4. Vérifier le changement
-- SELECT id, status, driver_arrived_notification
-- FROM trips
-- WHERE id = 'a515f059-8574-4ba7-ae59-0bdfe907f24e';
