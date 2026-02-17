-- =========================================
-- FIX: Fonction create_notification avec signature incorrecte
-- =========================================
-- Erreur: "Could not find the function public.create_notification(p_data, p_message, p_read, p_title, p_type, p_user_id)"
-- Les paramètres sont envoyés dans un ordre différent avec p_read en plus

-- =========================================
-- SOLUTION: Créer la fonction avec tous les paramètres
-- =========================================

-- Supprimer l'ancienne fonction si elle existe
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB);

-- Créer la nouvelle fonction avec le paramètre p_read
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_data JSONB DEFAULT NULL,
    p_read TEXT DEFAULT 'false'  -- Accepte 'true' ou 'false' comme string
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypasse RLS pour permettre la création de notifications pour d'autres users
SET search_path = public
AS $$
DECLARE
    v_notification_id UUID;
    v_read_bool BOOLEAN;
BEGIN
    -- Logger ce que nous recevons
    RAISE NOTICE '[create_notification] p_read_input: %', p_read;
    
    -- Convertir TEXT en BOOLEAN (même logique que l'ancienne fonction)
    v_read_bool := (p_read = 'true');
    
    -- Logger après conversion
    RAISE NOTICE '[create_notification] v_read_bool_after_conversion: %', v_read_bool;
    
    -- Insérer la notification
    INSERT INTO notifications (user_id, type, title, message, data, read, created_at)
    VALUES (p_user_id, p_type, p_title, p_message, p_data, v_read_bool, NOW())
    RETURNING id INTO v_notification_id;
    
    -- Logger après insertion
    RAISE NOTICE '[create_notification] Notification créée: % pour user: %, read: %', 
                 v_notification_id, p_user_id, v_read_bool;
    
    RETURN v_notification_id;
END;
$$;

-- Donner les permissions
GRANT EXECUTE ON FUNCTION create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO anon;

-- Commentaire
COMMENT ON FUNCTION create_notification IS
'Crée une notification pour un utilisateur. Bypasse RLS avec SECURITY DEFINER pour permettre les notifications cross-user (ex: appels entrants).';

-- =========================================
-- POLICY RLS pour INSERT
-- =========================================

-- Supprimer les anciennes politiques d'insertion
DROP POLICY IF EXISTS "Anyone can create notifications" ON notifications;
DROP POLICY IF EXISTS "System can create notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON notifications;
DROP POLICY IF EXISTS "Allow all authenticated to insert notifications" ON notifications;

-- Créer une politique permissive pour INSERT
CREATE POLICY "Allow all authenticated to insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

-- =========================================
-- VÉRIFICATIONS
-- =========================================

-- Test 1: Vérifier que la fonction existe
SELECT 
  'Fonction create_notification' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Fonction existe'
    ELSE '❌ Fonction manquante'
  END as status,
  COUNT(*) as count
FROM pg_proc 
WHERE proname = 'create_notification';

-- Test 2: Vérifier les paramètres de la fonction
SELECT 
  'Paramètres de la fonction' as check_name,
  proargnames as parameter_names,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'create_notification';

-- Test 3: Vérifier les permissions
SELECT 
  'Permissions sur la fonction' as check_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'create_notification';

-- Test 4: Vérifier les politiques RLS pour notifications
SELECT 
  'Politiques RLS notifications' as check_name,
  policyname,
  cmd as command,
  permissive,
  CASE 
    WHEN with_check = 'true' THEN '✅ INSERT permissif'
    ELSE with_check::text
  END as with_check
FROM pg_policies 
WHERE tablename = 'notifications'
  AND cmd = 'INSERT';

-- =========================================
-- INSTRUCTIONS
-- =========================================
SELECT 
  '1. Exécuter ce script dans Supabase SQL Editor' as etape_1,
  '2. Vérifier que tous les checks sont verts ✅' as etape_2,
  '3. Redémarrer l''app mobile (hot restart)' as etape_3,
  '4. Réessayer d''appeler le driver/rider' as etape_4;

-- =========================================
-- NOTES
-- =========================================
-- 
-- Cette fonction est appelée depuis:
-- - mobile_rider/lib/services/call_service.dart (ligne 129)
-- - mobile_driver/lib/services/call_service.dart (ligne 134)
-- 
-- Elle permet de créer des notifications d'appels entrants qui sont
-- envoyées au driver quand le rider appelle, et vice versa.
-- 
-- SÉCURITÉ:
-- - SECURITY DEFINER permet de bypasser RLS
-- - Nécessaire pour permettre aux riders d'envoyer des notifications aux drivers
-- - La politique RLS INSERT permet à tous les authenticated de créer des notifications
-- 
-- PARAMÈTRES:
-- - p_user_id: UUID du destinataire de la notification
-- - p_type: Type de notification (ex: 'incoming_call')
-- - p_title: Titre de la notification
-- - p_message: Message de la notification
-- - p_data: Données JSON (ex: call_id, caller_type, caller_name)
-- - p_read: String 'true' ou 'false' (converti en boolean)
--
