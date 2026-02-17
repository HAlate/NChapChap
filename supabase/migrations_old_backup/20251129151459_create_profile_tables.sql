/*
  # Cr\u00e9ation tables de profils sp\u00e9cifiques - Driver, Restaurant, Merchant

  1. Nouvelles Tables
    - `driver_profiles` - Infos sp\u00e9cifiques drivers
      - `id` (uuid, primary key = user_id)
      - `vehicle_type` (vehicle_type)
      - `vehicle_plate` (text)
      - `vehicle_brand` (text, nullable)
      - `vehicle_model` (text, nullable)
      - `license_number` (text)
      - `is_available` (boolean)
      - `current_lat`, `current_lng` (numeric, nullable)
      - `rating_average` (numeric)
      - `total_trips` (int)
      - `created_at`, `updated_at`

    - `restaurant_profiles` - Infos sp\u00e9cifiques restaurants
      - `id` (uuid, primary key = user_id)
      - `name` (text)
      - `description` (text, nullable)
      - `address` (text)
      - `lat`, `lng` (numeric)
      - `phone` (text)
      - `cuisine_type` (text)
      - `opening_hours` (jsonb)
      - `is_open` (boolean)
      - `rating_average` (numeric)
      - `total_orders` (int)
      - `created_at`, `updated_at`

    - `merchant_profiles` - Infos sp\u00e9cifiques marchands
      - `id` (uuid, primary key = user_id)
      - `business_name` (text)
      - `description` (text, nullable)
      - `address` (text)
      - `lat`, `lng` (numeric)
      - `phone` (text)
      - `business_type` (text)
      - `opening_hours` (jsonb)
      - `is_open` (boolean)
      - `rating_average` (numeric)
      - `total_orders` (int)
      - `created_at`, `updated_at`

  2. S\u00e9curit\u00e9
    - Enable RLS sur les 3 tables
    - Propri\u00e9taires g\u00e8rent leurs profils
    - Tout le monde peut voir profils disponibles/ouverts

  3. Index
    - Index sur is_available/is_open pour recherches
    - Index g\u00e9ographiques pour recherche proximit\u00e9

  4. Important
    - Un profil par user (1-to-1 avec users)
    - Rating calcul\u00e9 automatiquement depuis trips/orders
*/

-- Cr\u00e9er table driver_profiles
CREATE TABLE IF NOT EXISTS driver_profiles (
  id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  
  vehicle_type vehicle_type NOT NULL,
  vehicle_plate text NOT NULL,
  vehicle_brand text,
  vehicle_model text,
  vehicle_year int CHECK (vehicle_year >= 1980 AND vehicle_year <= EXTRACT(YEAR FROM CURRENT_DATE) + 1),
  
  license_number text NOT NULL,
  license_expiry_date date,
  
  -- Disponibilit\u00e9 et position
  is_available boolean DEFAULT false,
  current_lat numeric,
  current_lng numeric,
  last_location_update timestamptz,
  
  -- Statistiques
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_trips int DEFAULT 0 CHECK (total_trips >= 0),
  total_deliveries int DEFAULT 0 CHECK (total_deliveries >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_driver_profiles_available
  ON driver_profiles(is_available, vehicle_type)
  WHERE is_available = true;

CREATE INDEX IF NOT EXISTS idx_driver_profiles_location
  ON driver_profiles(current_lat, current_lng)
  WHERE is_available = true AND current_lat IS NOT NULL AND current_lng IS NOT NULL;

-- Enable RLS
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde peut voir profils drivers disponibles
DROP POLICY IF EXISTS "Anyone can view available driver profiles" ON driver_profiles;
CREATE POLICY "Anyone can view available driver profiles"
  ON driver_profiles
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Drivers voient leur profil
DROP POLICY IF EXISTS "Drivers can view own profile" ON driver_profiles;
CREATE POLICY "Drivers can view own profile"
  ON driver_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Drivers créent leur profil
DROP POLICY IF EXISTS "Drivers can create own profile" ON driver_profiles;

CREATE POLICY "Drivers can create own profile"
  ON driver_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.user_type = 'driver'
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

-- Cr\u00e9er table restaurant_profiles
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
  
  -- Options livraison
  min_order_amount int DEFAULT 0 CHECK (min_order_amount >= 0),
  estimated_prep_time_minutes int DEFAULT 30 CHECK (estimated_prep_time_minutes > 0),
  
  -- Statistiques
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_orders int DEFAULT 0 CHECK (total_orders >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_open
  ON restaurant_profiles(is_open, cuisine_type)
  WHERE is_open = true;

CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_location
  ON restaurant_profiles(lat, lng)
  WHERE is_open = true;

CREATE INDEX IF NOT EXISTS idx_restaurant_profiles_rating
  ON restaurant_profiles(rating_average DESC)
  WHERE is_open = true;

-- Enable RLS
ALTER TABLE restaurant_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde peut voir restaurants ouverts
DROP POLICY IF EXISTS "Anyone can view open restaurant profiles" ON restaurant_profiles;
CREATE POLICY "Anyone can view open restaurant profiles"
  ON restaurant_profiles
  FOR SELECT
  TO authenticated
  USING (is_open = true);

-- Politique: Restaurants voient leur profil
DROP POLICY IF EXISTS "Restaurants can view own profile" ON restaurant_profiles;
CREATE POLICY "Restaurants can view own profile"
  ON restaurant_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Restaurants créent leur profil
DROP POLICY IF EXISTS "Restaurants can create own profile" ON restaurant_profiles;

CREATE POLICY "Restaurants can create own profile"
  ON restaurant_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.user_type = 'restaurant'
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

-- Cr\u00e9er table merchant_profiles
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
  
  -- Options livraison
  min_order_amount int DEFAULT 0 CHECK (min_order_amount >= 0),
  
  -- Statistiques
  rating_average numeric DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
  total_orders int DEFAULT 0 CHECK (total_orders >= 0),
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_open
  ON merchant_profiles(is_open, business_type)
  WHERE is_open = true;

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_location
  ON merchant_profiles(lat, lng)
  WHERE is_open = true;

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_rating
  ON merchant_profiles(rating_average DESC)
  WHERE is_open = true;

-- Enable RLS
ALTER TABLE merchant_profiles ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde peut voir marchands ouverts
DROP POLICY IF EXISTS "Anyone can view open merchant profiles" ON merchant_profiles;
CREATE POLICY "Anyone can view open merchant profiles"
  ON merchant_profiles
  FOR SELECT
  TO authenticated
  USING (is_open = true);

-- Politique: Marchands voient leur profil
DROP POLICY IF EXISTS "Merchants can view own profile" ON merchant_profiles;
CREATE POLICY "Merchants can view own profile"
  ON merchant_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Politique: Marchands créent leur profil
DROP POLICY IF EXISTS "Merchants can create own profile" ON merchant_profiles;

CREATE POLICY "Merchants can create own profile"
  ON merchant_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.user_type = 'merchant'
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