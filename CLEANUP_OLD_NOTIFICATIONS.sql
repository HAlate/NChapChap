-- Nettoyer les anciennes notifications de test
DELETE FROM notifications 
WHERE type = 'incoming_call' 
AND read = true;

-- Vérifier qu'il ne reste que des notifications non lues
SELECT id, user_id, type, read, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;
