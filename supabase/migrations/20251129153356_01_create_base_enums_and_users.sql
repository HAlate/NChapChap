/*
  # Migration Initiale - Types ENUM et Table Users

  1. Types ENUM
    - user_type: rider, driver, restaurant, merchant
    - user_status: active, suspended, inactive
    - vehicle_type: moto-taxi, tricycle, taxi
    - payment_method: cash, mobile_money
    - token_type: course, delivery_food, delivery_product
    - transaction_type: purchase, spend, refund, bonus

  2. Table users
    - Table centrale pour tous les utilisateurs
    - Colonnes de base: id, email, phone, full_name, user_type, status
    - Timestamps: created_at, updated_at

  3. Sécurité
    - Enable RLS
    - Politique: Utilisateurs voient leur propre profil
*/

-- Types ENUM de base
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_type') THEN
    CREATE TYPE user_type AS ENUM ('rider', 'driver', 'restaurant', 'merchant');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
    CREATE TYPE user_status AS ENUM ('active', 'suspended', 'inactive');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_type') THEN
    CREATE TYPE vehicle_type AS ENUM ('moto-taxi', 'tricycle', 'taxi');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    CREATE TYPE payment_method AS ENUM ('cash', 'mobile_money');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'token_type') THEN
    CREATE TYPE token_type AS ENUM ('course', 'delivery_food', 'delivery_product');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
    CREATE TYPE transaction_type AS ENUM ('purchase', 'spend', 'refund', 'bonus');
  END IF;
END $$;

-- Table users
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  email text UNIQUE NOT NULL,
  phone text UNIQUE NOT NULL,
  full_name text NOT NULL,
  user_type user_type NOT NULL,
  status user_status DEFAULT 'active',
  
  profile_photo_url text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_users_type ON users(user_type);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Politique: Utilisateurs voient leur propre profil
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile"
  ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Utilisateurs mettent à jour leur profil
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());