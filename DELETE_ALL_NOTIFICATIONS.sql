-- Supprimer toutes les notifications pour repartir sur un état propre
DELETE FROM notifications;

-- Vérifier que la table est vide
SELECT COUNT(*) as total_notifications FROM notifications;
