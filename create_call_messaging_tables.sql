-- ============================================
-- Tables pour le système d'appel et messagerie WebRTC
-- Version: 1.0
-- Date: 2026-01-11
-- ============================================

-- Supprimer les tables existantes si elles existent (pour recréation propre)
DROP TABLE IF EXISTS call_signaling CASCADE;
DROP TABLE IF EXISTS call_sessions CASCADE;
DROP TABLE IF EXISTS trip_messages CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;

-- Table pour les sessions d'appel WebRTC
CREATE TABLE call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    caller_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    caller_type TEXT NOT NULL CHECK (caller_type IN ('rider', 'driver')),
    status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'active', 'ended', 'rejected', 'missed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    answered_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER DEFAULT 0,
    end_reason TEXT -- 'completed', 'rejected', 'missed', 'error'
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_call_sessions_trip_id ON call_sessions(trip_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_caller_id ON call_sessions(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_receiver_id ON call_sessions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_status ON call_sessions(status);

-- Table pour la signalisation WebRTC (offer, answer, ICE candidates)
CREATE TABLE call_signaling (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id UUID NOT NULL REFERENCES call_sessions(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('offer', 'answer', 'ice-candidate')),
    data JSONB NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour la signalisation
CREATE INDEX IF NOT EXISTS idx_call_signaling_call_id ON call_signaling(call_id);
CREATE INDEX IF NOT EXISTS idx_call_signaling_created_at ON call_signaling(created_at);

-- Table pour les messages de trajet
CREATE TABLE trip_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    sender_type TEXT NOT NULL CHECK (sender_type IN ('rider', 'driver')),
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE
);

-- Index pour les messages
CREATE INDEX IF NOT EXISTS idx_trip_messages_trip_id ON trip_messages(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_messages_sender_id ON trip_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_trip_messages_receiver_id ON trip_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_trip_messages_created_at ON trip_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_trip_messages_read ON trip_messages(read);

-- Table pour les notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('incoming_call', 'missed_call', 'new_message', 'trip_update', 'other')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Index pour les notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- Politiques RLS (Row Level Security)
-- ============================================

-- Activer RLS sur toutes les tables
ALTER TABLE call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_signaling ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Politiques pour call_sessions
-- Les utilisateurs peuvent voir les appels où ils sont caller ou receiver
CREATE POLICY "Users can view their own calls"
    ON call_sessions FOR SELECT
    USING (
        caller_id = auth.uid() OR receiver_id = auth.uid()
    );

-- Les utilisateurs peuvent créer des appels où ils sont le caller
CREATE POLICY "Users can create calls"
    ON call_sessions FOR INSERT
    WITH CHECK (caller_id = auth.uid());

-- Les utilisateurs peuvent mettre à jour les appels où ils sont impliqués
CREATE POLICY "Users can update their calls"
    ON call_sessions FOR UPDATE
    USING (
        caller_id = auth.uid() OR receiver_id = auth.uid()
    );

-- Politiques pour call_signaling
CREATE POLICY "Users can view signaling for their calls"
    ON call_signaling FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM call_sessions
            WHERE call_sessions.id = call_signaling.call_id
            AND (call_sessions.caller_id = auth.uid() OR call_sessions.receiver_id = auth.uid())
        )
    );

CREATE POLICY "Users can insert signaling for their calls"
    ON call_signaling FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM call_sessions
            WHERE call_sessions.id = call_signaling.call_id
            AND (call_sessions.caller_id = auth.uid() OR call_sessions.receiver_id = auth.uid())
        )
    );

-- Politiques pour trip_messages
-- Les utilisateurs peuvent voir les messages où ils sont sender ou receiver
CREATE POLICY "Users can view their messages"
    ON trip_messages FOR SELECT
    USING (
        sender_id = auth.uid() OR receiver_id = auth.uid()
    );

-- Les utilisateurs peuvent envoyer des messages
CREATE POLICY "Users can send messages"
    ON trip_messages FOR INSERT
    WITH CHECK (sender_id = auth.uid());

-- Les utilisateurs peuvent mettre à jour leurs messages reçus (marquer comme lu)
CREATE POLICY "Users can update received messages"
    ON trip_messages FOR UPDATE
    USING (receiver_id = auth.uid());

-- Politiques pour notifications
CREATE POLICY "Users can view their notifications"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Anyone can create notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update their notifications"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Users can delete their notifications"
    ON notifications FOR DELETE
    USING (user_id = auth.uid());

-- ============================================
-- Fonction pour nettoyer les anciennes données
-- ============================================

-- Fonction pour nettoyer les appels terminés de plus de 24h
CREATE OR REPLACE FUNCTION cleanup_old_calls()
RETURNS void AS $$
BEGIN
    DELETE FROM call_sessions
    WHERE status IN ('ended', 'rejected')
    AND ended_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nettoyer les messages de trajets terminés depuis plus de 7 jours
CREATE OR REPLACE FUNCTION cleanup_old_messages()
RETURNS void AS $$
BEGIN
    DELETE FROM trip_messages
    WHERE trip_id IN (
        SELECT id FROM trips
        WHERE status = 'completed'
        AND updated_at < NOW() - INTERVAL '7 days'
    );
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nettoyer les notifications lues de plus de 30 jours
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS void AS $$
BEGIN
    DELETE FROM notifications
    WHERE read = true
    AND read_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Commentaires sur les tables
-- ============================================

COMMENT ON TABLE call_sessions IS 'Gère les sessions d''appel WebRTC entre passager et chauffeur';
COMMENT ON TABLE call_signaling IS 'Stocke les données de signalisation WebRTC pour établir les connexions';
COMMENT ON TABLE trip_messages IS 'Messages échangés entre passager et chauffeur pour un trajet';
COMMENT ON TABLE notifications IS 'Notifications push pour les utilisateurs (appels, messages, etc.)';
