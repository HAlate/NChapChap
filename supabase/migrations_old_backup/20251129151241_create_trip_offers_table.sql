/*
  # Cr\u00e9ation table trip_offers - Syst\u00e8me de N\u00e9gociation Trajets

  1. Nouvelle Table
    - `trip_offers` - Offres des drivers pour les demandes de trajet
      - `id` (uuid, primary key)
      - `trip_id` (uuid, r\u00e9f\u00e9rence trips)
      - `driver_id` (uuid, r\u00e9f\u00e9rence users)
      - `offered_price` (int) - Prix propos\u00e9 par le driver
      - `counter_price` (int, nullable) - Contre-offre du rider
      - `final_price` (int, nullable) - Prix final accept\u00e9
      - `eta_minutes` (int) - Temps estim\u00e9 d'arriv\u00e9e
      - `status` (offer_status) - pending/selected/accepted/not_selected/rejected
      - `token_spent` (boolean) - Jeton d\u00e9pens\u00e9 ou non
      - `created_at` (timestamptz)

  2. Type ENUM
    - `offer_status` - Statuts des offres

  3. S\u00e9curit\u00e9
    - Enable RLS sur `trip_offers`
    - Politique: Drivers voient leurs offres
    - Politique: Riders voient offres pour leurs trips
    - Politique: Drivers cr\u00e9ent des offres si >= 1 jeton
    - Politique: Riders s\u00e9lectionnent des offres
    - Politique: Drivers acceptent contre-offres

  4. Index
    - Index sur trip_id et status pour requ\u00eates rapides

  5. Important
    - Jeton dépensé SEULEMENT quand status = 'accepted'
    - Un driver ne peut faire qu'une seule offre par trip (UNIQUE constraint)
*/

-- Cr\u00e9er type ENUM pour statut offre
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'offer_status') THEN
    CREATE TYPE offer_status AS ENUM (
      'pending',      -- En attente s\u00e9lection rider
      'selected',     -- S\u00e9lectionn\u00e9, en n\u00e9gociation
      'accepted',     -- Prix accept\u00e9, JETON D\u00c9PENS\u00c9
      'not_selected', -- Pas s\u00e9lectionn\u00e9
      'rejected'      -- N\u00e9gociation \u00e9chou\u00e9e
    );
  END IF;
END $$;

-- Cr\u00e9er table trip_offers
CREATE TABLE IF NOT EXISTS trip_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  trip_id uuid REFERENCES trips(id) NOT NULL,
  driver_id uuid REFERENCES users(id) NOT NULL,
  
  -- PRIX (avec n\u00e9gociation)
  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int CHECK (counter_price > 0),
  final_price int CHECK (final_price > 0),
  
  -- Infos offre
  eta_minutes int NOT NULL CHECK (eta_minutes > 0),
  vehicle_type vehicle_type NOT NULL,
  
  -- Statut
  status offer_status DEFAULT 'pending',
  
  -- JETON DRIVER (1 jeton)
  token_spent boolean DEFAULT false,
  -- false → Jeton pas dépensé (pending, selected, not_selected, rejected)
  -- true → 1 jeton dépensé (accepted)
  
  created_at timestamptz DEFAULT now(),
  
  -- Un driver ne peut faire qu'une offre par trip
  UNIQUE(trip_id, driver_id)
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_trip_offers_trip_pending
  ON trip_offers(trip_id, status)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_trip_offers_driver
  ON trip_offers(driver_id, created_at DESC);

-- Enable RLS
ALTER TABLE trip_offers ENABLE ROW LEVEL SECURITY;

-- Politique: Drivers voient leurs propres offres
DROP POLICY IF EXISTS "Drivers can view own trip offers" ON trip_offers;
CREATE POLICY "Drivers can view own trip offers"
  ON trip_offers
  FOR SELECT
  TO authenticated
  USING (
    driver_id = auth.uid()
  );

-- Politique: Riders voient offres pour leurs trips
DROP POLICY IF EXISTS "Riders can view offers for their trips" ON trip_offers;
CREATE POLICY "Riders can view offers for their trips"
  ON trip_offers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id
      AND trips.rider_id = auth.uid()
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

-- Politique: Riders mettent à jour offres pour leurs trips (sélection, contre-offre)
DROP POLICY IF EXISTS "Riders can update offers for their trips" ON trip_offers;
CREATE POLICY "Riders can update offers for their trips"
  ON trip_offers
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id
      AND trips.rider_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_offers.trip_id
      AND trips.rider_id = auth.uid()
    )
  );

-- Politique: Drivers mettent à jour leurs offres (accepter/refuser contre-offre)
DROP POLICY IF EXISTS "Drivers can update own trip offers" ON trip_offers;
CREATE POLICY "Drivers can update own trip offers"
  ON trip_offers
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());