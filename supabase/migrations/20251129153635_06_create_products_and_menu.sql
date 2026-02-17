/*
  # Migration Tables Produits et Menus

  1. Tables
    - products: Catalogue produits des marchands
    - menu_items: Catalogue plats des restaurants

  2. Sécurité
    - Enable RLS sur les 2 tables
    - Propriétaires gèrent leurs items
    - Tout le monde voit items disponibles

  3. Important
    - Prix FIXE (pas de négociation sur produits/plats)
    - Négociation UNIQUEMENT sur prix livraison
    - Stock géré pour produits marchands
*/

-- Table products (Marchands)
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

-- Index
CREATE INDEX IF NOT EXISTS idx_products_merchant ON products(merchant_id, is_available);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category, is_available)
  WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_available ON products(is_available, created_at DESC)
  WHERE is_available = true;

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Politique: Marchands voient leurs produits
DROP POLICY IF EXISTS "Merchants can view own products" ON products;
CREATE POLICY "Merchants can view own products"
  ON products
  FOR SELECT
  TO authenticated
  USING (merchant_id = auth.uid());

-- Politique: Tout le monde voit produits disponibles
DROP POLICY IF EXISTS "Anyone can view available products" ON products;
CREATE POLICY "Anyone can view available products"
  ON products
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Marchands créent leurs produits
DROP POLICY IF EXISTS "Merchants can create own products" ON products;
CREATE POLICY "Merchants can create own products"
  ON products
  FOR INSERT
  TO authenticated
  WITH CHECK (
    merchant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'merchant'
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

-- Table menu_items (Restaurants)
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

-- Index
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant ON menu_items(restaurant_id, is_available);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category, is_available)
  WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available, created_at DESC)
  WHERE is_available = true;

-- Enable RLS
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- Politique: Restaurants voient leurs plats
DROP POLICY IF EXISTS "Restaurants can view own menu items" ON menu_items;
CREATE POLICY "Restaurants can view own menu items"
  ON menu_items
  FOR SELECT
  TO authenticated
  USING (restaurant_id = auth.uid());

-- Politique: Tout le monde voit plats disponibles
DROP POLICY IF EXISTS "Anyone can view available menu items" ON menu_items;
CREATE POLICY "Anyone can view available menu items"
  ON menu_items
  FOR SELECT
  TO authenticated
  USING (is_available = true);

-- Politique: Restaurants créent leurs plats
DROP POLICY IF EXISTS "Restaurants can create own menu items" ON menu_items;
CREATE POLICY "Restaurants can create own menu items"
  ON menu_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    restaurant_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'restaurant'
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