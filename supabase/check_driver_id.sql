-- Vérifier l'ID de l'utilisateur connecté (97123456@driver.app)
SELECT 
  id,
  email,
  user_type,
  full_name
FROM users
WHERE email = '97123456@driver.app';
