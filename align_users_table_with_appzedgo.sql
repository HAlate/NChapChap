-- =========================================
-- VÉRIFIER ET ALIGNER LA TABLE USERS
-- =========================================
-- Compare avec le schéma APPZEDGO qui fonctionne

-- 1. Vérifier la structure actuelle de la table users
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. Vérifier les contraintes
SELECT 
  conname as constraint_name,
  contype as type,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.users'::regclass;

-- 3. Vérifier les index
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'users'
  AND schemaname = 'public';

-- 4. Ajouter les colonnes manquantes si nécessaire
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_visible boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_visible_to_riders boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS no_show_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_restricted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS restriction_until timestamp with time zone,
  ADD COLUMN IF NOT EXISTS last_no_show_at timestamp with time zone;

-- 5. Créer les index manquants
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users USING btree (status);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users USING btree (email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users USING btree (phone);
CREATE INDEX IF NOT EXISTS idx_users_type ON public.users USING btree (user_type);
CREATE INDEX IF NOT EXISTS idx_users_visible_providers ON public.users USING btree (user_type, is_visible)
  WHERE user_type = ANY (ARRAY['restaurant'::user_type, 'merchant'::user_type]);
CREATE INDEX IF NOT EXISTS idx_users_restricted ON public.users USING btree (is_restricted)
  WHERE is_restricted = true;

-- 6. S'assurer que les contraintes UNIQUE existent
DO $$ 
BEGIN
  -- Email unique
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'public.users'::regclass 
    AND conname = 'users_email_key'
  ) THEN
    ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);
  END IF;

  -- Phone unique
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'public.users'::regclass 
    AND conname = 'users_phone_key'
  ) THEN
    ALTER TABLE public.users ADD CONSTRAINT users_phone_key UNIQUE (phone);
  END IF;
END $$;

-- =========================================
-- VÉRIFICATION FINALE
-- =========================================
SELECT 
  'Structure alignée avec APPZEDGO ✅' as message;

-- Vérifier que tout est en place
SELECT 
  COUNT(*) as nombre_colonnes,
  COUNT(*) FILTER (WHERE column_name IN ('is_visible', 'is_visible_to_riders', 'no_show_count', 'is_restricted')) as colonnes_no_show
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users';
