-- Migration: Système de gestion des No Show pour UUMO
-- Date: 2026-01-08
-- Source: Adapté depuis APPZEDGO (20251230_create_no_show_system.sql)

-- Table pour les signalements de No Show
CREATE TABLE IF NOT EXISTS no_show_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  reported_by UUID NOT NULL REFERENCES users(id),
  reported_user UUID NOT NULL REFERENCES users(id),
  user_type TEXT NOT NULL CHECK (user_type IN ('rider', 'driver')),
  reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'rejected', 'disputed')),
  admin_notes TEXT,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table pour les pénalités utilisateurs
CREATE TABLE IF NOT EXISTS user_penalties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  penalty_type TEXT NOT NULL CHECK (penalty_type IN ('no_show', 'cancellation', 'behavior', 'fraud')),
  severity INTEGER DEFAULT 1 CHECK (severity BETWEEN 1 AND 3), -- 1=light, 2=medium, 3=severe
  reason TEXT,
  trip_id UUID REFERENCES trips(id),
  report_id UUID REFERENCES no_show_reports(id),
  tokens_deducted INTEGER DEFAULT 0,
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id)
);

-- Ajouter colonnes aux users pour tracking No Show
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS no_show_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_restricted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS restriction_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_no_show_at TIMESTAMPTZ;

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_no_show_reports_trip ON no_show_reports(trip_id);
CREATE INDEX IF NOT EXISTS idx_no_show_reports_reported_user ON no_show_reports(reported_user);
CREATE INDEX IF NOT EXISTS idx_no_show_reports_status ON no_show_reports(status);
CREATE INDEX IF NOT EXISTS idx_user_penalties_user ON user_penalties(user_id);
CREATE INDEX IF NOT EXISTS idx_user_penalties_active ON user_penalties(is_active);
CREATE INDEX IF NOT EXISTS idx_users_restricted ON users(is_restricted) WHERE is_restricted = TRUE;

-- Fonction pour auto-expirer les restrictions
CREATE OR REPLACE FUNCTION expire_user_restrictions()
RETURNS void AS $$
BEGIN
  UPDATE users
  SET is_restricted = FALSE,
      restriction_until = NULL
  WHERE is_restricted = TRUE
    AND restriction_until IS NOT NULL
    AND restriction_until < NOW();
    
  UPDATE user_penalties
  SET is_active = FALSE
  WHERE is_active = TRUE
    AND expires_at IS NOT NULL
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Fonction trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_no_show_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_no_show_reports_updated_at
BEFORE UPDATE ON no_show_reports
FOR EACH ROW
EXECUTE FUNCTION update_no_show_reports_updated_at();

-- RLS Policies pour no_show_reports
ALTER TABLE no_show_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reports"
ON no_show_reports FOR SELECT
USING (auth.uid() = reported_by OR auth.uid() = reported_user);

CREATE POLICY "Users can create reports"
ON no_show_reports FOR INSERT
WITH CHECK (auth.uid() = reported_by);

-- RLS Policies pour user_penalties
ALTER TABLE user_penalties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own penalties"
ON user_penalties FOR SELECT
USING (auth.uid() = user_id);

-- Commentaires
COMMENT ON TABLE no_show_reports IS 'Signalements de non-présentation (No Show) pour trips';
COMMENT ON TABLE user_penalties IS 'Pénalités appliquées aux utilisateurs pour diverses infractions';
COMMENT ON COLUMN users.no_show_count IS 'Nombre total de No Show pour cet utilisateur';
COMMENT ON COLUMN users.is_restricted IS 'TRUE si l''utilisateur est actuellement restreint';
COMMENT ON COLUMN users.restriction_until IS 'Date de fin de la restriction';
