/*
  # Migration Tables Trajets avec Négociation

  1. Types ENUM
    - trip_status: pending, accepted, started, completed, cancelled
    - offer_status: pending, selected, accepted, not_selected, rejected

  2. Tables
    - trips: Demandes et trajets complétés
    - trip_offers: Offres des drivers avec NÉGOCIATION PRIX

  3. Sécurité
    - Enable RLS sur les 2 tables
    - Riders voient leurs trips
    - Drivers voient trips disponibles et leurs offres
    - Drivers créent offres SI >= 1 jeton

  4. Important
    - Driver propose SON prix (offered_price)
    - Rider peut contre-proposer (counter_price)
    - Prix final négocié (final_price)
    - Jeton dépensé UNIQUEMENT si status = 'accepted'
*/

-- Types ENUM
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
    CREATE TYPE trip_status AS ENUM ('pending', 'accepted', 'started', 'completed', 'cancelled');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'offer_status') THEN
    CREATE TYPE offer_status AS ENUM ('pending', 'selected', 'accepted', 'not_selected', 'rejected');
  END IF;
END $$;

-- Table trips
CREATE TABLE IF NOT EXISTS trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  rider_id uuid REFERENCES users(id) NOT NULL,
  driver_id uuid REFERENCES users(id),
  
  vehicle_type vehicle_type NOT NULL,
  
  departure text NOT NULL,
  departure_lat numeric,
  departure_lng numeric,
  
  destination text NOT NULL,
  destination_lat numeric,
  destination_lng numeric,
  
  distance_km numeric,
  
  proposed_price int CHECK (proposed_price > 0),
  final_price int CHECK (final_price > 0),
  
  payment_method payment_method DEFAULT 'cash',
  status trip_status DEFAULT 'pending',
  
  driver_token_spent boolean DEFAULT false,
  
  driver_rating int CHECK (driver_rating >= 1 AND driver_rating <= 5),
  rider_rating int CHECK (rider_rating >= 1 AND rider_rating <= 5),
  
  created_at timestamptz DEFAULT now(),
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz
);

-- Index
CREATE INDEX IF NOT EXISTS idx_trips_rider ON trips(rider_id, status);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trips_pending ON trips(status, vehicle_type) WHERE status = 'pending';

-- Enable RLS
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

-- Politique: Riders voient leurs trips
DROP POLICY IF EXISTS "Riders can view own trips" ON trips;
CREATE POLICY "Riders can view own trips"
  ON trips
  FOR SELECT
  TO authenticated
  USING (rider_id = auth.uid());

-- Politique: Drivers voient trips assignés
DROP POLICY IF EXISTS "Drivers can view assigned trips" ON trips;
CREATE POLICY "Drivers can view assigned trips"
  ON trips
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Drivers voient trips pending
DROP POLICY IF EXISTS "Drivers can view pending trips" ON trips;
CREATE POLICY "Drivers can view pending trips"
  ON trips
  FOR SELECT
  TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND user_type = 'driver'
    )
  );

-- Politique: Riders créent trips
DROP POLICY IF EXISTS "Riders can create trips" ON trips;
CREATE POLICY "Riders can create trips"
  ON trips
  FOR INSERT
  TO authenticated
  WITH CHECK (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND user_type = 'rider'
    )
  );

-- Politique: Riders/Drivers mettent à jour trips
DROP POLICY IF EXISTS "Riders and drivers can update trips" ON trips;
CREATE POLICY "Riders and drivers can update trips"
  ON trips
  FOR UPDATE
  TO authenticated
  USING (rider_id = auth.uid() OR driver_id = auth.uid())
  WITH CHECK (rider_id = auth.uid() OR driver_id = auth.uid());

-- Table trip_offers (NÉGOCIATION)
CREATE TABLE IF NOT EXISTS trip_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  trip_id uuid REFERENCES trips(id) NOT NULL,
  driver_id uuid REFERENCES users(id) NOT NULL,
  
  -- PRIX avec négociation
  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int CHECK (counter_price > 0),
  final_price int CHECK (final_price > 0),
  
  eta_minutes int NOT NULL CHECK (eta_minutes > 0),
  vehicle_type vehicle_type NOT NULL,
  
  status offer_status DEFAULT 'pending',
  token_spent boolean DEFAULT false,
  
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(trip_id, driver_id)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_trip_offers_trip ON trip_offers(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_trip_offers_driver ON trip_offers(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_offers_pending ON trip_offers(trip_id, status) WHERE status = 'pending';

-- Enable RLS
ALTER TABLE trip_offers ENABLE ROW LEVEL SECURITY;

-- Politique: Drivers voient leurs offres
DROP POLICY IF EXISTS "Drivers can view own trip offers" ON trip_offers;
CREATE POLICY "Drivers can view own trip offers"
  ON trip_offers
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Politique: Riders voient offres pour leurs trips
DROP POLICY IF EXISTS "Riders can view offers for their trips" ON trip_offers;
CREATE POLICY "Riders can view offers for their trips"
  ON trip_offers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id AND trips.rider_id = auth.uid()
    )
  );

-- Politique: Drivers créent offres SI >= 1 jeton
DROP POLICY IF EXISTS "Drivers can create trip offers if tokens available" ON trip_offers;
CREATE POLICY "Drivers can create trip offers if tokens available"
  ON trip_offers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND user_type = 'driver'
    )
    AND EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = auth.uid()
        AND token_type = 'course'
        AND balance >= 1
    )
  );

-- Politique: Riders mettent à jour offres (sélection, contre-offre)
DROP POLICY IF EXISTS "Riders can update offers for their trips" ON trip_offers;
CREATE POLICY "Riders can update offers for their trips"
  ON trip_offers
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id AND trips.rider_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id AND trips.rider_id = auth.uid()
    )
  );

-- Politique: Drivers mettent à jour leurs offres
DROP POLICY IF EXISTS "Drivers can update own trip offers" ON trip_offers;
CREATE POLICY "Drivers can update own trip offers"
  ON trip_offers
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());