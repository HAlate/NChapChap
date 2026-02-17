/*
  # Migration Tables Commandes et Livraisons avec Négociation

  1. Types ENUM
    - provider_type: restaurant, merchant
    - order_status: pending, confirmed, preparing, ready, delivering, delivered, cancelled
    - delivery_request_status: pending, negotiating, assigned, completed, cancelled

  2. Tables
    - orders: Commandes restaurants/marchands
    - delivery_requests: Demandes de livraison
    - delivery_offers: Offres drivers avec NÉGOCIATION PRIX LIVRAISON

  3. Sécurité
    - Enable RLS sur toutes les tables
    - Riders voient leurs commandes
    - Providers voient commandes pour eux
    - Drivers voient demandes et créent offres SI >= 1 jeton

  4. Important
    - Restaurant/Marchand négocie PRIX LIVRAISON avec driver
    - Driver propose SON prix livraison
    - Jeton dépensé UNIQUEMENT si status = 'accepted'
*/

-- Types ENUM
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'provider_type') THEN
    CREATE TYPE provider_type AS ENUM ('restaurant', 'merchant');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
    CREATE TYPE order_status AS ENUM (
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'delivering',
      'delivered',
      'cancelled'
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_request_status') THEN
    CREATE TYPE delivery_request_status AS ENUM (
      'pending',
      'negotiating',
      'assigned',
      'completed',
      'cancelled'
    );
  END IF;
END $$;

-- Table orders
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  rider_id uuid REFERENCES users(id) NOT NULL,
  provider_id uuid REFERENCES users(id) NOT NULL,
  provider_type provider_type NOT NULL,
  driver_id uuid REFERENCES users(id),
  
  items jsonb DEFAULT '[]'::jsonb,
  subtotal int CHECK (subtotal >= 0),
  delivery_fee int DEFAULT 0 CHECK (delivery_fee >= 0),
  total_amount int CHECK (total_amount >= 0),
  
  payment_method payment_method DEFAULT 'cash',
  status order_status DEFAULT 'pending',
  
  provider_token_spent boolean DEFAULT false,
  driver_token_spent boolean DEFAULT false,
  
  delivery_address text,
  delivery_lat numeric,
  delivery_lng numeric,
  
  special_instructions text,
  
  provider_rating int CHECK (provider_rating >= 1 AND provider_rating <= 5),
  driver_rating int CHECK (driver_rating >= 1 AND driver_rating <= 5),
  
  created_at timestamptz DEFAULT now(),
  confirmed_at timestamptz,
  ready_at timestamptz,
  delivered_at timestamptz,
  cancelled_at timestamptz
);

-- Index
CREATE INDEX IF NOT EXISTS idx_orders_rider ON orders(rider_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_provider ON orders(provider_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_driver ON orders(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_pending ON orders(provider_id, status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_orders_ready ON orders(status) WHERE status = 'ready';

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Politique: Riders voient leurs commandes
DROP POLICY IF EXISTS "Riders can view own orders" ON orders;
CREATE POLICY "Riders can view own orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (rider_id = auth.uid());

-- Politique: Providers voient leurs commandes
DROP POLICY IF EXISTS "Providers can view own orders" ON orders;
CREATE POLICY "Providers can view own orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (provider_id = auth.uid());

-- Politique: Drivers voient commandes assignées
DROP POLICY IF EXISTS "Drivers can view assigned orders" ON orders;
CREATE POLICY "Drivers can view assigned orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Riders créent commandes
DROP POLICY IF EXISTS "Riders can create orders" ON orders;
CREATE POLICY "Riders can create orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'rider'
    )
  );

-- Politique: Tous peuvent mettre à jour commandes
DROP POLICY IF EXISTS "Participants can update orders" ON orders;
CREATE POLICY "Participants can update orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (
    rider_id = auth.uid()
    OR provider_id = auth.uid()
    OR driver_id = auth.uid()
  )
  WITH CHECK (
    rider_id = auth.uid()
    OR provider_id = auth.uid()
    OR driver_id = auth.uid()
  );

-- Table delivery_requests
CREATE TABLE IF NOT EXISTS delivery_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  order_id uuid REFERENCES orders(id) NOT NULL UNIQUE,
  requester_id uuid REFERENCES users(id) NOT NULL,
  requester_type provider_type NOT NULL,
  
  pickup_address text NOT NULL,
  delivery_address text NOT NULL,
  pickup_lat numeric,
  pickup_lng numeric,
  delivery_lat numeric,
  delivery_lng numeric,
  
  status delivery_request_status DEFAULT 'pending',
  
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '30 minutes')
);

-- Index
CREATE INDEX IF NOT EXISTS idx_delivery_requests_order ON delivery_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_requester ON delivery_requests(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_status ON delivery_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_pending ON delivery_requests(status, created_at DESC)
  WHERE status = 'pending';

-- Enable RLS
ALTER TABLE delivery_requests ENABLE ROW LEVEL SECURITY;

-- Politique: Providers voient leurs demandes
DROP POLICY IF EXISTS "Providers can view own delivery requests" ON delivery_requests;
CREATE POLICY "Providers can view own delivery requests"
  ON delivery_requests
  FOR SELECT
  TO authenticated
  USING (requester_id = auth.uid());

-- Politique: Drivers voient demandes pending
DROP POLICY IF EXISTS "Drivers can view pending delivery requests" ON delivery_requests;
CREATE POLICY "Drivers can view pending delivery requests"
  ON delivery_requests
  FOR SELECT
  TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'driver'
    )
  );

-- Politique: Providers créent demandes
DROP POLICY IF EXISTS "Providers can create delivery requests" ON delivery_requests;
CREATE POLICY "Providers can create delivery requests"
  ON delivery_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    requester_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND user_type IN ('restaurant', 'merchant')
    )
  );

-- Politique: Providers mettent à jour leurs demandes
DROP POLICY IF EXISTS "Providers can update own delivery requests" ON delivery_requests;
CREATE POLICY "Providers can update own delivery requests"
  ON delivery_requests
  FOR UPDATE
  TO authenticated
  USING (requester_id = auth.uid())
  WITH CHECK (requester_id = auth.uid());

-- Table delivery_offers (NÉGOCIATION PRIX LIVRAISON)
CREATE TABLE IF NOT EXISTS delivery_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  delivery_request_id uuid REFERENCES delivery_requests(id) NOT NULL,
  driver_id uuid REFERENCES users(id) NOT NULL,
  
  -- PRIX LIVRAISON avec négociation
  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int CHECK (counter_price > 0),
  final_price int CHECK (final_price > 0),
  
  status offer_status DEFAULT 'pending',
  token_spent boolean DEFAULT false,
  
  eta_minutes int NOT NULL CHECK (eta_minutes > 0),
  vehicle_type vehicle_type,
  
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(delivery_request_id, driver_id)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_delivery_offers_request ON delivery_offers(delivery_request_id, status);
CREATE INDEX IF NOT EXISTS idx_delivery_offers_driver ON delivery_offers(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delivery_offers_pending ON delivery_offers(delivery_request_id, status)
  WHERE status = 'pending';

-- Enable RLS
ALTER TABLE delivery_offers ENABLE ROW LEVEL SECURITY;

-- Politique: Drivers voient leurs offres
DROP POLICY IF EXISTS "Drivers can view own delivery offers" ON delivery_offers;
CREATE POLICY "Drivers can view own delivery offers"
  ON delivery_offers
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Providers voient offres pour leurs demandes
DROP POLICY IF EXISTS "Providers can view offers for their requests" ON delivery_offers;
CREATE POLICY "Providers can view offers for their requests"
  ON delivery_offers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM delivery_requests
      WHERE delivery_requests.id = delivery_offers.delivery_request_id
        AND delivery_requests.requester_id = auth.uid()
    )
  );

-- Politique: Drivers créent offres SI >= 1 jeton
DROP POLICY IF EXISTS "Drivers can create delivery offers if tokens available" ON delivery_offers;
CREATE POLICY "Drivers can create delivery offers if tokens available"
  ON delivery_offers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'driver'
    )
    AND EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = auth.uid()
        AND token_type = 'course'
        AND balance >= 1
    )
  );

-- Politique: Providers mettent à jour offres
DROP POLICY IF EXISTS "Providers can update offers for their requests" ON delivery_offers;
CREATE POLICY "Providers can update offers for their requests"
  ON delivery_offers
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM delivery_requests
      WHERE delivery_requests.id = delivery_offers.delivery_request_id
        AND delivery_requests.requester_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM delivery_requests
      WHERE delivery_requests.id = delivery_offers.delivery_request_id
        AND delivery_requests.requester_id = auth.uid()
    )
  );

-- Politique: Drivers mettent à jour leurs offres
DROP POLICY IF EXISTS "Drivers can update own delivery offers" ON delivery_offers;
CREATE POLICY "Drivers can update own delivery offers"
  ON delivery_offers
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());