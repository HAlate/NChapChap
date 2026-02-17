/*
  # Cr\u00e9ation tables delivery_requests et delivery_offers - Syst\u00e8me de Livraison avec N\u00e9gociation

  1. Nouvelles Tables
    - `delivery_requests` - Demandes de livraison des restaurants/marchands
      - `id` (uuid, primary key)
      - `order_id` (uuid, r\u00e9f\u00e9rence orders) UNIQUE
      - `requester_id` (uuid, restaurant/marchand)
      - `requester_type` (provider_type)
      - `pickup_address`, `delivery_address`
      - `pickup_lat/lng`, `delivery_lat/lng`
      - `status` (delivery_request_status)
      - `created_at`, `expires_at`

    - `delivery_offers` - Offres des drivers pour livraisons
      - `id` (uuid, primary key)
      - `delivery_request_id` (uuid)
      - `driver_id` (uuid)
      - `offered_price` (int) - Prix livraison propos\u00e9
      - `counter_price` (int, nullable) - Contre-offre restaurant
      - `final_price` (int, nullable) - Prix final
      - `status` (offer_status)
      - `token_spent` (boolean)
      - `eta_minutes` (int)
      - `created_at`

  2. Type ENUM
    - `delivery_request_status` - Statuts demandes livraison

  3. S\u00e9curit\u00e9
    - Enable RLS sur les 2 tables
    - Restaurants/Marchands voient leurs demandes
    - Drivers voient demandes pending
    - Drivers cr\u00e9ent offres si >= 1 jeton
    - Restaurants/Marchands g\u00e8rent offres
    - Drivers acceptent/refusent contre-offres

  4. Index
    - Index sur status pour demandes pending
    - Index sur delivery_request_id pour offres

  5. Important
    - Restaurant/Marchand n\u00e9gocie PRIX livraison avec driver
    - Jeton dépensé SEULEMENT quand status = 'accepted'
    - Un driver ne peut faire qu'une offre par demande (UNIQUE)
*/

-- Cr\u00e9er type ENUM pour statut demande livraison
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_request_status') THEN
    CREATE TYPE delivery_request_status AS ENUM (
      'pending',     -- En attente offres drivers
      'negotiating', -- Driver s\u00e9lectionn\u00e9, en n\u00e9gociation
      'assigned',    -- Driver accept\u00e9, livraison en cours
      'completed',   -- Livraison termin\u00e9e
      'cancelled'    -- Annul\u00e9e
    );
  END IF;
END $$;

-- Cr\u00e9er table delivery_requests
CREATE TABLE IF NOT EXISTS delivery_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  order_id uuid REFERENCES orders(id) NOT NULL UNIQUE,
  requester_id uuid REFERENCES users(id) NOT NULL,
  requester_type provider_type NOT NULL,
  
  -- Adresses
  pickup_address text NOT NULL,
  delivery_address text NOT NULL,
  pickup_lat numeric,
  pickup_lng numeric,
  delivery_lat numeric,
  delivery_lng numeric,
  
  -- Statut
  status delivery_request_status DEFAULT 'pending',
  
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '30 minutes')
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_delivery_requests_pending
  ON delivery_requests(status, created_at DESC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_delivery_requests_requester
  ON delivery_requests(requester_id, status);

CREATE INDEX IF NOT EXISTS idx_delivery_requests_order
  ON delivery_requests(order_id);

-- Enable RLS
ALTER TABLE delivery_requests ENABLE ROW LEVEL SECURITY;

-- Politique: Restaurants/Marchands voient leurs demandes
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
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'driver'
    )
  );

-- Politique: Restaurants/Marchands créent demandes
DROP POLICY IF EXISTS "Providers can create delivery requests" ON delivery_requests;

CREATE POLICY "Providers can create delivery requests"
  ON delivery_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    requester_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type IN ('restaurant', 'merchant')
    )
  );

-- Politique: Restaurants/Marchands mettent à jour leurs demandes
DROP POLICY IF EXISTS "Providers can update own delivery requests" ON delivery_requests;

CREATE POLICY "Providers can update own delivery requests"
  ON delivery_requests
  FOR UPDATE
  TO authenticated
  USING (requester_id = auth.uid())
  WITH CHECK (requester_id = auth.uid());

-- Cr\u00e9er table delivery_offers
CREATE TABLE IF NOT EXISTS delivery_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  delivery_request_id uuid REFERENCES delivery_requests(id) NOT NULL,
  driver_id uuid REFERENCES users(id) NOT NULL,
  
  -- PRIX LIVRAISON (avec n\u00e9gociation)
  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int CHECK (counter_price > 0),
  final_price int CHECK (final_price > 0),
  
  -- Statut
  status offer_status DEFAULT 'pending',
  
  -- JETON DRIVER (1 jeton)
  token_spent boolean DEFAULT false,
  -- false → Jeton pas dépensé (pending, selected, not_selected, rejected)
  -- true → 1 jeton dépensé (accepted)
  
  eta_minutes int NOT NULL CHECK (eta_minutes > 0),
  vehicle_type vehicle_type,
  
  created_at timestamptz DEFAULT now(),
  
  -- Un driver ne peut faire qu'une offre par demande
  UNIQUE(delivery_request_id, driver_id)
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_delivery_offers_request_pending
  ON delivery_offers(delivery_request_id, status)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_delivery_offers_driver
  ON delivery_offers(driver_id, created_at DESC);

-- Enable RLS
ALTER TABLE delivery_offers ENABLE ROW LEVEL SECURITY;

-- Politique: Drivers voient leurs propres offres
DROP POLICY IF EXISTS "Drivers can view own delivery offers" ON delivery_offers;
CREATE POLICY "Drivers can view own delivery offers"
  ON delivery_offers
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Restaurants/Marchands voient offres pour leurs demandes
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
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND user_type = 'driver'
    )
    AND EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = auth.uid()
      AND token_type = 'course'
      AND balance >= 1
    )
  );

-- Politique: Restaurants/Marchands mettent à jour offres pour leurs demandes
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