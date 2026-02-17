/*
  # Migration Tables Profils Spécifiques

  1. Tables
    - driver_profiles: Profils chauffeurs avec véhicule et stats
    - restaurant_profiles: Profils restaurants avec localisation
    - merchant_profiles: Profils marchands avec localisation

  2. Sécurité
    - Enable RLS sur toutes les tables
    - Propriétaires voient leur profil complet
    - Autres utilisateurs voient profils disponibles/ouverts

  3. Important
    - Relation 1-to-1 avec users (id = user_id)
    - Stats calculées depuis trips/orders
    - Position géographique pour recherche proximité
*/

-- Table driver_profiles
CREATE TABLE IF NOT EXISTS driver_profiles (
  id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  
  vehicle_type vehicle_type NOT NULL,
  vehicle_plate text NOT NULL,
  vehicle_brand text,
  vehicle_model text,
  vehicle_year int CHECK (vehicle_year >= 1980 AND vehicle_year <= EXTRACT(YEAR FROM CURRENT_DATE) + 1),
  
  license_number text NOT NULL,
  license_expiry_date date,
  
  is_available boolean DEFAULT false,
  current_lat numeric,
  current_lng numeric,
  last_location_update timestamptz,
  
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_trips int DEFAULT 0 CHECK (total_trips >= 0),
  total_deliveries int DEFAULT 0 CHECK (total_deliveries >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_driver_profiles_available ON driver_profiles(is_available, vehicle_type)
  WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_driver_profiles_location ON driver_profiles(current_lat, current_lng)
  WHERE is_available = true AND current_lat IS NOT NULL;

-- Enable RLS
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Drivers voient leur profil
DROP POLICY IF EXISTS "Drivers can view own profile" ON driver_profiles;
CREATE POLICY "Drivers can view own profile"
  ON driver_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Tout le monde voit profils disponibles
DROP POLICY IF EXISTS "Anyone can view available driver profiles" ON driver_profiles;
CREATE POLICY "Anyone can view available driver profiles"
  ON driver_profiles
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Drivers créent leur profil
DROP POLICY IF EXISTS "Drivers can create own profile" ON driver_profiles;
CREATE POLICY "Drivers can create own profile"
  ON driver_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'driver'
    )
  );

-- Politique: Drivers mettent à jour leur profil
DROP POLICY IF EXISTS "Drivers can update own profile" ON driver_profiles;
CREATE POLICY "Drivers can update own profile"
  ON driver_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Table restaurant_profiles
CREATE TABLE IF NOT EXISTS restaurant_profiles (
  id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  
  name text NOT NULL,
  description text,
  logo_url text,
  cover_image_url text,
  
  address text NOT NULL,
  lat numeric NOT NULL,
  lng numeric NOT NULL,
  phone text NOT NULL,
  
  cuisine_type text NOT NULL,
  opening_hours jsonb DEFAULT '{}'::jsonb,
  is_open boolean DEFAULT true,
  
  min_order_amount int DEFAULT 0 CHECK (min_order_amount >= 0),
  estimated_prep_time_minutes int DEFAULT 30 CHECK (estimated_prep_time_minutes > 0),
  
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_orders int DEFAULT 0 CHECK (total_orders >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_open ON restaurant_profiles(is_open, cuisine_type)
  WHERE is_open = true;
CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_location ON restaurant_profiles(lat, lng)
  WHERE is_open = true;
CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_rating ON restaurant_profiles(rating_average DESC)
  WHERE is_open = true;

-- Enable RLS
ALTER TABLE restaurant_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Restaurants voient leur profil
DROP POLICY IF EXISTS "Restaurants can view own profile" ON restaurant_profiles;
CREATE POLICY "Restaurants can view own profile"
  ON restaurant_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Tout le monde voit restaurants ouverts
DROP POLICY IF EXISTS "Anyone can view open restaurant profiles" ON restaurant_profiles;
CREATE POLICY "Anyone can view open restaurant profiles"
  ON restaurant_profiles
  FOR SELECT
  TO authenticated
  USING (is_open = true);

-- Politique: Restaurants créent leur profil
DROP POLICY IF EXISTS "Restaurants can create own profile" ON restaurant_profiles;
CREATE POLICY "Restaurants can create own profile"
  ON restaurant_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'restaurant'
    )
  );

-- Politique: Restaurants mettent à jour leur profil
DROP POLICY IF EXISTS "Restaurants can update own profile" ON restaurant_profiles;
CREATE POLICY "Restaurants can update own profile"
  ON restaurant_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Table merchant_profiles
CREATE TABLE IF NOT EXISTS merchant_profiles (
  id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  
  business_name text NOT NULL,
  description text,
  logo_url text,
  cover_image_url text,
  
  address text NOT NULL,
  lat numeric NOT NULL,
  lng numeric NOT NULL,
  phone text NOT NULL,
  
  business_type text NOT NULL,
  opening_hours jsonb DEFAULT '{}'::jsonb,
  is_open boolean DEFAULT true,
  
  min_order_amount int DEFAULT 0 CHECK (min_order_amount >= 0),
  
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_orders int DEFAULT 0 CHECK (total_orders >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_open ON merchant_profiles(is_open, business_type)
  WHERE is_open = true;
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_location ON merchant_profiles(lat, lng)
  WHERE is_open = true;
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_rating ON merchant_profiles(rating_average DESC)
  WHERE is_open = true;

-- Enable RLS
ALTER TABLE merchant_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Marchands voient leur profil
DROP POLICY IF EXISTS "Merchants can view own profile" ON merchant_profiles;
CREATE POLICY "Merchants can view own profile"
  ON merchant_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Tout le monde voit marchands ouverts
DROP POLICY IF EXISTS "Anyone can view open merchant profiles" ON merchant_profiles;
CREATE POLICY "Anyone can view open merchant profiles"
  ON merchant_profiles
  FOR SELECT
  TO authenticated
  USING (is_open = true);

-- Politique: Marchands créent leur profil
DROP POLICY IF EXISTS "Merchants can create own profile" ON merchant_profiles;
CREATE POLICY "Merchants can create own profile"
  ON merchant_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'merchant'
    )
  );

-- Politique: Marchands mettent à jour leur profil
DROP POLICY IF EXISTS "Merchants can update own profile" ON merchant_profiles;
CREATE POLICY "Merchants can update own profile"
  ON merchant_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());