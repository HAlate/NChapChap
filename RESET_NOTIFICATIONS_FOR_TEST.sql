-- Marquer toutes les notifications comme lues pour nettoyer l'état
UPDATE notifications
SET read = true
WHERE read = false;

-- Vérifier l'état après nettoyage
SELECT 
  type,
  read,
  COUNT(*) as count
FROM notifications
GROUP BY type, read
ORDER BY type, read;

-- Optionnel: Supprimer toutes les anciennes notifications si vous voulez un état totalement propre
-- DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '1 hour';
