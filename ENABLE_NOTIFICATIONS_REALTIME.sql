-- Vérifier si la réplication est activée sur la table notifications
SELECT schemaname, tablename, replica_identity 
FROM pg_tables 
JOIN pg_class ON pg_tables.tablename = pg_class.relname
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
LEFT JOIN pg_publication_tables ON pg_publication_tables.tablename = pg_tables.tablename
WHERE pg_tables.tablename = 'notifications';

-- Activer la réplication pour Realtime sur la table notifications
-- Cette commande doit être exécutée dans Supabase Dashboard → Database → Replication
-- Ou via SQL :

-- Option 1 : Via la publication supabase_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Option 2 : Configurer replica identity (nécessaire pour les streams)
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Vérifier que c'est activé
SELECT * FROM pg_publication_tables WHERE tablename = 'notifications';
