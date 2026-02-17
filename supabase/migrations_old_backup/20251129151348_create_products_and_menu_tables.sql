/*
  # Cr\u00e9ation tables products et menu_items - Catalogues Marchands/Restaurants

  1. Nouvelles Tables
    - `products` - Produits des marchands
      - `id` (uuid, primary key)
      - `merchant_id` (uuid, r\u00e9f\u00e9rence users)
      - `name` (text)
      - `description` (text, nullable)
      - `price` (int)
      - `category` (text)
      - `image_url` (text, nullable)
      - `stock_quantity` (int)
      - `is_available` (boolean)
      - `created_at`, `updated_at`

    - `menu_items` - Plats des restaurants
      - `id` (uuid, primary key)
      - `restaurant_id` (uuid, r\u00e9f\u00e9rence users)
      - `name` (text)
      - `description` (text, nullable)
      - `price` (int)
      - `category` (text)
      - `image_url` (text, nullable)
      - `preparation_time_minutes` (int)
      - `is_available` (boolean)
      - `created_at`, `updated_at`

  2. S\u00e9curit\u00e9
    - Enable RLS sur les 2 tables
    - Marchands/Restaurants g\u00e8rent leurs propres items
    - Tous les authentifi\u00e9s peuvent voir items disponibles
    - Riders peuvent voir pour commander

  3. Index
    - Index sur merchant_id/restaurant_id
    - Index sur is_available pour filtrage rapide
    - Index sur category pour recherche par cat\u00e9gorie

  4. Important
    - Prix FIXE (pas de n\u00e9gociation sur produits/plats)
    - N\u00e9gociation UNIQUEMENT sur prix livraison
*/

-- Cr\u00e9er table products (Marchands)
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  merchant_id uuid REFERENCES users(id) NOT NULL,
  
  name text NOT NULL,
  description text,
  price int NOT NULL CHECK (price > 0),
  category text NOT NULL,
  image_url text,
  
  stock_quantity int DEFAULT 0 CHECK (stock_quantity >= 0),
  is_available boolean DEFAULT true,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_products_merchant
  ON products(merchant_id, is_available);

CREATE INDEX IF NOT EXISTS idx_products_category
  ON products(category, is_available)
  WHERE is_available = true;

CREATE INDEX IF NOT EXISTS idx_products_available
  ON products(is_available, created_at DESC)
  WHERE is_available = true;

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde peut voir produits disponibles
DROP POLICY IF EXISTS "Anyone can view available products" ON products;
CREATE POLICY "Anyone can view available products"
  ON products
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Marchands voient tous leurs produits
DROP POLICY IF EXISTS "Merchants can view own products" ON products;
CREATE POLICY "Merchants can view own products"
  ON products
  FOR SELECT
  TO authenticated
  USING (merchant_id = auth.uid());

-- Politique: Marchands créent leurs produits
DROP POLICY IF EXISTS "Merchants can create own products" ON products;

CREATE POLICY "Merchants can create own products"
  ON products
  FOR INSERT
  TO authenticated
  WITH CHECK (
    merchant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'merchant'
    )
  );

-- Politique: Marchands mettent à jour leurs produits
DROP POLICY IF EXISTS "Merchants can update own products" ON products;

CREATE POLICY "Merchants can update own products"
  ON products
  FOR UPDATE
  TO authenticated
  USING (merchant_id = auth.uid())
  WITH CHECK (merchant_id = auth.uid());

-- Politique: Marchands suppriment leurs produits
DROP POLICY IF EXISTS "Merchants can delete own products" ON products;
CREATE POLICY "Merchants can delete own products"
  ON products
  FOR DELETE
  TO authenticated
  USING (merchant_id = auth.uid());

-- Cr\u00e9er table menu_items (Restaurants)
CREATE TABLE IF NOT EXISTS menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  restaurant_id uuid REFERENCES users(id) NOT NULL,
  
  name text NOT NULL,
  description text,
  price int NOT NULL CHECK (price > 0),
  category text NOT NULL,
  image_url text,
  
  preparation_time_minutes int DEFAULT 15 CHECK (preparation_time_minutes > 0),
  is_available boolean DEFAULT true,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant
  ON menu_items(restaurant_id, is_available);

CREATE INDEX IF NOT EXISTS idx_menu_items_category
  ON menu_items(category, is_available)
  WHERE is_available = true;

CREATE INDEX IF NOT EXISTS idx_menu_items_available
  ON menu_items(is_available, created_at DESC)
  WHERE is_available = true;

-- Enable RLS
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- Politique: Tout le monde peut voir plats disponibles
DROP POLICY IF EXISTS "Anyone can view available menu items" ON menu_items;
CREATE POLICY "Anyone can view available menu items"
  ON menu_items
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Restaurants voient tous leurs plats
DROP POLICY IF EXISTS "Restaurants can view own menu items" ON menu_items;
CREATE POLICY "Restaurants can view own menu items"
  ON menu_items
  FOR SELECT
  TO authenticated
  USING (restaurant_id = auth.uid());

-- Politique: Restaurants créent leurs plats
DROP POLICY IF EXISTS "Restaurants can create own menu items" ON menu_items;

CREATE POLICY "Restaurants can create own menu items"
  ON menu_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    restaurant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'restaurant'
    )
  );

-- Politique: Restaurants mettent à jour leurs plats
DROP POLICY IF EXISTS "Restaurants can update own menu items" ON menu_items;

CREATE POLICY "Restaurants can update own menu items"
  ON menu_items
  FOR UPDATE
  TO authenticated
  USING (restaurant_id = auth.uid())
  WITH CHECK (restaurant_id = auth.uid());

-- Politique: Restaurants suppriment leurs plats
DROP POLICY IF EXISTS "Restaurants can delete own menu items" ON menu_items;
CREATE POLICY "Restaurants can delete own menu items"
  ON menu_items
  FOR DELETE
  TO authenticated
  USING (restaurant_id = auth.uid());