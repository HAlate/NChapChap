-- ============================================
-- FIX : Corriger les politiques RLS pour notifications
-- Permet aux utilisateurs de créer des notifications pour d'autres utilisateurs
-- Date: 2026-01-11
-- ============================================

-- SOLUTION : Désactiver temporairement RLS pour INSERT sur notifications
-- Cela permet à tous les utilisateurs authentifiés de créer des notifications
-- pour d'autres utilisateurs (nécessaire pour les appels entrants)

-- Supprimer toutes les anciennes politiques d'insertion
DROP POLICY IF EXISTS "Anyone can create notifications" ON notifications;
DROP POLICY IF EXISTS "System can create notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON notifications;

-- Désactiver RLS uniquement pour INSERT (garde SELECT, UPDATE, DELETE protégés)
-- En créant une politique permissive sans condition
CREATE POLICY "Allow all authenticated to insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

-- Alternative : Créer une fonction qui bypasse RLS
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_data JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER  -- Cette fonction s'exécute avec les privilèges du créateur (bypasse RLS)
SET search_path = public
AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, type, title, message, data, read, created_at)
    VALUES (p_user_id, p_type, p_title, p_message, p_data, false, NOW())
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

-- Donner les permissions nécessaires
GRANT EXECUTE ON FUNCTION create_notification TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification TO anon;

-- Vérifier que la politique est active
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'notifications'
ORDER BY cmd;
