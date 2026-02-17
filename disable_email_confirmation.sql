-- =========================================
-- DÉSACTIVER LA CONFIRMATION EMAIL (SQL)
-- =========================================
-- Alternative à la configuration dans le Dashboard

-- 1. Mettre à jour la configuration auth pour désactiver email confirmation
UPDATE auth.config
SET value = 'false'
WHERE parameter = 'enable_email_confirm';

-- Si la table config n'existe pas, cette approche ne fonctionnera pas
-- Dans ce cas, tu DOIS aller dans le Dashboard Supabase :
-- Authentication > Settings > Email Auth > Enable email confirmations = OFF

-- 2. Alternative : Créer une politique qui bypass la vérification
-- (Moins recommandé mais fonctionne)

-- 3. Forcer TOUS les utilisateurs @uumo.app à être confirmés
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email LIKE '%@uumo.app';

-- =========================================
-- APRÈS AVOIR EXÉCUTÉ CE SCRIPT
-- =========================================
-- IMPORTANT : Tu DOIS aller dans le Dashboard Supabase
-- 
-- 1. Ouvre Supabase Dashboard : https://supabase.com/dashboard
-- 2. Sélectionne ton projet UUMO
-- 3. Va dans Authentication (icône clé à gauche)
-- 4. Clique sur "Settings" (en bas à gauche)
-- 5. Cherche la section "Email Auth"
-- 6. Désactive "Enable email confirmations" (toggle OFF)
-- 7. Sauvegarde
-- 
-- PUIS dans l'app Flutter :
-- 8. Arrête l'app complètement (Stop dans VS Code)
-- 9. Relance : flutter run
-- 10. Connecte-toi à nouveau
-- 
-- L'erreur devrait disparaître définitivement.
