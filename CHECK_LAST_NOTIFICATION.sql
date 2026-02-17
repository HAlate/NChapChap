-- Vérifier la dernière notification créée
SELECT 
  id,
  user_id,
  type,
  title,
  message,
  read,
  created_at,
  data
FROM notifications
ORDER BY created_at DESC
LIMIT 5;

-- Vérifier spécifiquement la notification créée par le rider
SELECT 
  id,
  user_id,
  type,
  read,
  created_at,
  data->>'call_id' as call_id,
  data->>'caller_type' as caller_type
FROM notifications
WHERE id = '8ee7b740-8a90-4ec6-94d3-dafaaf25eaef';

-- Compter les notifications par utilisateur
SELECT 
  user_id,
  type,
  read,
  COUNT(*) as count
FROM notifications
GROUP BY user_id, type, read
ORDER BY user_id, type, read;
