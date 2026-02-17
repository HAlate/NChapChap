# 🗄️ Structure Base de Données Supabase - Urban Mobility

**Date:** 2025-11-29
**Version:** 1.0 Production Ready
**Statut:** ✅ Toutes les tables créées avec RLS activé

---

## 📊 Vue d'Ensemble

Base de données PostgreSQL complète pour la plateforme Urban Mobility avec:
- ✅ 14 tables principales
- ✅ Row Level Security (RLS) activé sur toutes les tables
- ✅ Index optimisés pour performance
- ✅ Types ENUM pour validation
- ✅ Contraintes d'intégrité
- ✅ Système de négociation complet

---

## 🎯 Tables Créées

### 1. **users** - Utilisateurs Principaux
```sql
Table: users
RLS: ✅ Activé
Rôle: Table centrale pour tous les utilisateurs

Colonnes:
- id (uuid, PK)
- email (text, unique)
- phone (text, unique)
- full_name (text)
- user_type (enum: rider, driver, restaurant, merchant)
- status (enum: active, suspended, inactive)
- profile_photo_url (text, nullable)
- created_at, updated_at (timestamptz)

Index:
- Primary key sur id
- Unique sur email
- Unique sur phone

RLS Policies:
- Utilisateurs voient leur propre profil
- Autres utilisateurs voient profils publics
```

---

### 2. **driver_profiles** - Profils Chauffeurs
```sql
Table: driver_profiles
RLS: ✅ Activé
Rôle: Informations spécifiques aux drivers

Colonnes:
- id (uuid, PK, FK → users.id)
- vehicle_type (enum)
- vehicle_plate (text)
- vehicle_brand, vehicle_model (text, nullable)
- vehicle_year (int)
- license_number (text)
- license_expiry_date (date, nullable)
- is_available (boolean, default false)
- current_lat, current_lng (numeric, nullable)
- last_location_update (timestamptz, nullable)
- rating_average (numeric, 0-5)
- total_trips (int)
- total_deliveries (int)
- created_at, updated_at (timestamptz)

Index:
- idx_driver_profiles_available (is_available, vehicle_type)
- idx_driver_profiles_location (lat, lng) pour recherche géo

RLS Policies:
- Drivers voient leur propre profil (complet)
- Autres utilisateurs voient profils disponibles seulement
```

---

### 3. **restaurant_profiles** - Profils Restaurants
```sql
Table: restaurant_profiles
RLS: ✅ Activé
Rôle: Informations spécifiques aux restaurants

Colonnes:
- id (uuid, PK, FK → users.id)
- name (text)
- description (text, nullable)
- logo_url, cover_image_url (text, nullable)
- address (text)
- lat, lng (numeric)
- phone (text)
- cuisine_type (text)
- opening_hours (jsonb)
- is_open (boolean, default true)
- min_order_amount (int, default 0)
- estimated_prep_time_minutes (int, default 30)
- rating_average (numeric, 0-5)
- total_orders (int)
- created_at, updated_at (timestamptz)

Index:
- idx_restaurant_profiles_open (is_open, cuisine_type)
- idx_restaurant_profiles_location (lat, lng)
- idx_restaurant_profiles_rating (rating_average DESC)

RLS Policies:
- Restaurants voient leur propre profil (complet)
- Autres utilisateurs voient restaurants ouverts seulement
```

---

### 4. **merchant_profiles** - Profils Marchands
```sql
Table: merchant_profiles
RLS: ✅ Activé
Rôle: Informations spécifiques aux marchands

Colonnes:
- id (uuid, PK, FK → users.id)
- business_name (text)
- description (text, nullable)
- logo_url, cover_image_url (text, nullable)
- address (text)
- lat, lng (numeric)
- phone (text)
- business_type (text)
- opening_hours (jsonb)
- is_open (boolean, default true)
- min_order_amount (int, default 0)
- rating_average (numeric, 0-5)
- total_orders (int)
- created_at, updated_at (timestamptz)

Index:
- idx_merchant_profiles_open (is_open, business_type)
- idx_merchant_profiles_location (lat, lng)
- idx_merchant_profiles_rating (rating_average DESC)

RLS Policies:
- Marchands voient leur propre profil (complet)
- Autres utilisateurs voient marchands ouverts seulement
```

---

### 5. **token_balances** - Soldes de Jetons
```sql
Table: token_balances
RLS: ✅ Activé
Rôle: Gestion des soldes de jetons par utilisateur

Colonnes:
- id (uuid, PK)
- user_id (uuid, FK → users.id)
- token_type (enum: course, delivery_food, delivery_product)
- balance (int, default 0, >= 0)
- total_purchased (int, default 0)
- total_spent (int, default 0)
- updated_at (timestamptz)

Index:
- FK sur user_id

RLS Policies:
- Utilisateurs voient uniquement leur propre solde
- Système peut créer/mettre à jour via service_role
```

---

### 6. **token_transactions** - Historique Jetons
```sql
Table: token_transactions
RLS: ✅ Activé
Rôle: Historique des transactions de jetons

Colonnes:
- id (uuid, PK)
- user_id (uuid, FK → users.id)
- transaction_type (enum: purchase, spend, refund, bonus)
- token_type (enum: course, delivery_food, delivery_product)
- amount (int)
- balance_before (int)
- balance_after (int)
- reference_id (uuid, nullable)
- payment_method (text, nullable)
- notes (text, nullable)
- created_at (timestamptz)

Index:
- FK sur user_id
- Index sur created_at DESC

RLS Policies:
- Utilisateurs voient uniquement leurs propres transactions
```

---

### 7. **token_packages** - Packages de Jetons
```sql
Table: token_packages
RLS: ✅ Activé
Rôle: Packages disponibles à l'achat

Colonnes:
- id (uuid, PK)
- name (text)
- token_type (enum)
- token_amount (int, > 0)
- price_fcfa (int, > 0)
- bonus_tokens (int, default 0, >= 0)
- is_active (boolean, default true)
- created_at (timestamptz)

Index:
- Primary key sur id

RLS Policies:
- Tout le monde peut voir packages actifs
- Admins peuvent créer/modifier packages
```

---

### 8. **trips** - Trajets
```sql
Table: trips
RLS: ✅ Activé
Rôle: Demandes et trajets complétés

Colonnes:
- id (uuid, PK)
- rider_id (uuid, FK → users.id)
- driver_id (uuid, FK → users.id, nullable)
- vehicle_type (enum)
- departure, destination (text)
- departure_lat, departure_lng (numeric, nullable)
- destination_lat, destination_lng (numeric, nullable)
- distance_km (numeric, nullable)
- proposed_price (int, nullable, > 0)
- final_price (int, nullable, > 0)
- payment_method (enum: cash, mobile_money)
- status (enum: pending, accepted, started, completed, cancelled)
- driver_token_spent (boolean, default false)
- driver_rating, rider_rating (int, 1-5, nullable)
- created_at, accepted_at, started_at, completed_at, cancelled_at

Index:
- FK sur rider_id et driver_id
- Index sur status

RLS Policies:
- Riders voient leurs propres trips
- Drivers voient trips où ils sont assignés
- Drivers voient trips pending pour faire offres
```

---

### 9. **trip_offers** - Offres Trajets (NÉGOCIATION)
```sql
Table: trip_offers
RLS: ✅ Activé
Rôle: Offres des drivers pour trajets avec négociation PRIX

Colonnes:
- id (uuid, PK)
- trip_id (uuid, FK → trips.id)
- driver_id (uuid, FK → users.id)
- offered_price (int, > 0) -- Prix PROPOSÉ par driver
- counter_price (int, nullable, > 0) -- Contre-offre rider
- final_price (int, nullable, > 0) -- Prix final accepté
- eta_minutes (int, > 0)
- vehicle_type (enum)
- status (enum: pending, selected, accepted, not_selected, rejected)
- token_spent (boolean, default false)
- created_at (timestamptz)

UNIQUE(trip_id, driver_id) -- 1 offre par driver par trip

Index:
- idx_trip_offers_trip_pending (trip_id, status WHERE pending)
- idx_trip_offers_driver (driver_id, created_at DESC)

RLS Policies:
- Drivers voient leurs propres offres
- Riders voient offres pour leurs trips
- Drivers créent offres SI >= 1 jeton disponible
- Riders peuvent sélectionner/contre-proposer
- Drivers peuvent accepter/refuser contre-offres

IMPORTANT:
- Jeton dépensé SEULEMENT quand status = 'accepted'
- Prix négocié entre rider et driver
```

---

### 10. **orders** - Commandes
```sql
Table: orders
RLS: ✅ Activé
Rôle: Commandes restaurants/marchands

Colonnes:
- id (uuid, PK)
- rider_id (uuid, FK → users.id)
- provider_id (uuid, FK → users.id)
- provider_type (enum: restaurant, merchant)
- driver_id (uuid, FK → users.id, nullable)
- items (jsonb, default [])
- subtotal (int, >= 0)
- delivery_fee (int, default 0, >= 0)
- total_amount (int, >= 0)
- payment_method (enum)
- status (enum: pending, confirmed, preparing, ready, delivering, delivered, cancelled)
- provider_token_spent (boolean, default false)
- driver_token_spent (boolean, default false)
- delivery_address (text, nullable)
- delivery_lat, delivery_lng (numeric, nullable)
- special_instructions (text, nullable)
- provider_rating, driver_rating (int, 1-5, nullable)
- created_at, confirmed_at, ready_at, delivered_at, cancelled_at

Index:
- FK sur rider_id, provider_id, driver_id
- idx_orders_provider_pending (provider_id, status WHERE pending)
- idx_orders_ready (status WHERE ready)

RLS Policies:
- Riders voient leurs propres commandes
- Providers voient commandes pour eux
- Drivers voient commandes assignées à eux
```

---

### 11. **delivery_requests** - Demandes de Livraison
```sql
Table: delivery_requests
RLS: ✅ Activé
Rôle: Demandes de livraison par restaurants/marchands

Colonnes:
- id (uuid, PK)
- order_id (uuid, FK → orders.id, UNIQUE)
- requester_id (uuid, FK → users.id)
- requester_type (enum: restaurant, merchant)
- pickup_address (text)
- delivery_address (text)
- pickup_lat, pickup_lng (numeric, nullable)
- delivery_lat, delivery_lng (numeric, nullable)
- status (enum: pending, negotiating, assigned, completed, cancelled)
- created_at (timestamptz)
- expires_at (timestamptz, default now + 30 min)

Index:
- idx_delivery_requests_pending (status, created_at WHERE pending)
- idx_delivery_requests_requester (requester_id, status)
- idx_delivery_requests_order (order_id)

RLS Policies:
- Restaurants/Marchands voient leurs demandes
- Drivers voient demandes pending
- Restaurants/Marchands créent demandes
```

---

### 12. **delivery_offers** - Offres Livraison (NÉGOCIATION)
```sql
Table: delivery_offers
RLS: ✅ Activé
Rôle: Offres des drivers pour livraisons avec négociation PRIX LIVRAISON

Colonnes:
- id (uuid, PK)
- delivery_request_id (uuid, FK → delivery_requests.id)
- driver_id (uuid, FK → users.id)
- offered_price (int, > 0) -- Prix LIVRAISON proposé par driver
- counter_price (int, nullable, > 0) -- Contre-offre restaurant/marchand
- final_price (int, nullable, > 0) -- Prix final accepté
- status (enum: pending, selected, accepted, not_selected, rejected)
- token_spent (boolean, default false)
- eta_minutes (int, > 0)
- vehicle_type (enum, nullable)
- created_at (timestamptz)

UNIQUE(delivery_request_id, driver_id) -- 1 offre par driver par demande

Index:
- idx_delivery_offers_request_pending (delivery_request_id, status WHERE pending)
- idx_delivery_offers_driver (driver_id, created_at DESC)

RLS Policies:
- Drivers voient leurs propres offres
- Restaurants/Marchands voient offres pour leurs demandes
- Drivers créent offres SI >= 1 jeton disponible
- Restaurants/Marchands peuvent sélectionner/contre-proposer
- Drivers peuvent accepter/refuser contre-offres

IMPORTANT:
- Restaurant/Marchand négocie PRIX LIVRAISON avec driver
- Jeton dépensé SEULEMENT quand status = 'accepted'
- Prix livraison négocié (PAS d'estimation)
```

---

### 13. **products** - Produits Marchands
```sql
Table: products
RLS: ✅ Activé
Rôle: Catalogue produits des marchands

Colonnes:
- id (uuid, PK)
- merchant_id (uuid, FK → users.id)
- name (text)
- description (text, nullable)
- price (int, > 0)
- category (text)
- image_url (text, nullable)
- stock_quantity (int, default 0, >= 0)
- is_available (boolean, default true)
- created_at, updated_at (timestamptz)

Index:
- idx_products_merchant (merchant_id, is_available)
- idx_products_category (category, is_available WHERE available)
- idx_products_available (is_available, created_at WHERE available)

RLS Policies:
- Tout le monde voit produits disponibles
- Marchands voient tous leurs produits
- Marchands créent/modifient/suppriment leurs produits
```

---

### 14. **menu_items** - Menus Restaurants
```sql
Table: menu_items
RLS: ✅ Activé
Rôle: Catalogue plats des restaurants

Colonnes:
- id (uuid, PK)
- restaurant_id (uuid, FK → users.id)
- name (text)
- description (text, nullable)
- price (int, > 0)
- category (text)
- image_url (text, nullable)
- preparation_time_minutes (int, default 15, > 0)
- is_available (boolean, default true)
- created_at, updated_at (timestamptz)

Index:
- idx_menu_items_restaurant (restaurant_id, is_available)
- idx_menu_items_category (category, is_available WHERE available)
- idx_menu_items_available (is_available, created_at WHERE available)

RLS Policies:
- Tout le monde voit plats disponibles
- Restaurants voient tous leurs plats
- Restaurants créent/modifient/suppriment leurs plats
```

---

### 15. **payments** - Paiements
```sql
Table: payments
RLS: ✅ Activé
Rôle: Historique des paiements

Colonnes:
- id (uuid, PK)
- payer_id (uuid, FK → users.id)
- payee_id (uuid, FK → users.id, nullable)
- amount (int, > 0)
- payment_type (enum: trip, delivery, order, token_purchase)
- payment_method (enum: cash, mobile_money)
- reference_id (uuid, nullable) -- trip_id, order_id, etc.
- reference_type (text, nullable) -- 'trip', 'order', 'token_purchase'
- status (enum: pending, processing, completed, failed, refunded)
- transaction_id (text, nullable) -- ID externe (mobile money)
- metadata (jsonb, default {})
- created_at, processed_at (timestamptz)

Index:
- idx_payments_payer (payer_id, created_at DESC)
- idx_payments_payee (payee_id, created_at DESC WHERE payee_id NOT NULL)
- idx_payments_status (status, created_at DESC)
- idx_payments_reference (reference_id, reference_type WHERE reference_id NOT NULL)
- idx_payments_transaction (transaction_id WHERE transaction_id NOT NULL)

RLS Policies:
- Utilisateurs voient leurs paiements (donnés)
- Utilisateurs voient paiements reçus
```

---

## 🔐 Types ENUM Créés

### 1. **user_type**
```sql
VALUES: 'rider', 'driver', 'restaurant', 'merchant'
```

### 2. **user_status**
```sql
VALUES: 'active', 'suspended', 'inactive'
```

### 3. **vehicle_type**
```sql
VALUES: 'moto-taxi', 'tricycle', 'taxi'
```

### 4. **token_type**
```sql
VALUES: 'course', 'delivery_food', 'delivery_product'
```

### 5. **transaction_type**
```sql
VALUES: 'purchase', 'spend', 'refund', 'bonus'
```

### 6. **payment_method**
```sql
VALUES: 'cash', 'mobile_money'
```

### 7. **trip_status**
```sql
VALUES: 'pending', 'accepted', 'started', 'completed', 'cancelled'
```

### 8. **order_status**
```sql
VALUES: 'pending', 'confirmed', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled'
```

### 9. **offer_status**
```sql
VALUES: 'pending', 'selected', 'accepted', 'not_selected', 'rejected'
```

### 10. **delivery_request_status**
```sql
VALUES: 'pending', 'negotiating', 'assigned', 'completed', 'cancelled'
```

### 11. **provider_type**
```sql
VALUES: 'restaurant', 'merchant'
```

### 12. **payment_type_enum**
```sql
VALUES: 'trip', 'delivery', 'order', 'token_purchase'
```

### 13. **payment_status_enum**
```sql
VALUES: 'pending', 'processing', 'completed', 'failed', 'refunded'
```

---

## 🔑 Relations Principales

```
users (1) ----< (N) token_balances
users (1) ----< (N) token_transactions
users (1) ----< (N) trips (as rider)
users (1) ----< (N) trips (as driver)
users (1) ----< (N) orders (as rider)
users (1) ----< (N) orders (as provider)
users (1) ----< (N) orders (as driver)

trips (1) ----< (N) trip_offers
users (1) ----< (N) trip_offers (as driver)

orders (1) ---- (1) delivery_requests
delivery_requests (1) ----< (N) delivery_offers
users (1) ----< (N) delivery_offers (as driver)

users (1) ---- (1) driver_profiles
users (1) ---- (1) restaurant_profiles
users (1) ---- (1) merchant_profiles

users (1) ----< (N) products (as merchant)
users (1) ----< (N) menu_items (as restaurant)

users (1) ----< (N) payments (as payer)
users (1) ----< (N) payments (as payee)
```

---

## 🎯 Points Clés Système

### 1. **Négociation PRIX Trajets**
```
Flow: Rider → trip_offers ← Driver
- Driver propose SON prix
- Rider peut accepter/contre-proposer
- Jeton dépensé SEULEMENT si accepté
- PAS d'estimation de prix système
```

### 2. **Négociation PRIX Livraisons**
```
Flow: Restaurant/Marchand → delivery_offers ← Driver
- Driver propose SON prix livraison
- Restaurant/Marchand peut accepter/contre-proposer
- Jeton dépensé SEULEMENT si accepté
- PAS d'estimation de prix livraison
```

### 3. **Système de Jetons**
```
Driver:
- 1 jeton = 1 trajet accepté
- 1 jeton = 1 livraison acceptée
- Jeton dépensé UNIQUEMENT quand accord final

Restaurant/Marchand:
- 5 jetons = 1 commande acceptée
- Dépense immédiate à l'acceptation
```

---

## 🚀 Prochaines Étapes

Vous pouvez maintenant:

1. **Connexion PostgreSQL**
```bash
# Utiliser les credentials dans .env
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

2. **Requêtes SQL Directes**
```sql
-- Exemple: Voir tous les drivers disponibles
SELECT
  u.id, u.full_name, u.phone,
  dp.vehicle_type, dp.rating_average, dp.total_trips
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
WHERE dp.is_available = true
ORDER BY dp.rating_average DESC;

-- Exemple: Voir offres pour un trajet
SELECT
  u.full_name, u.phone,
  to.offered_price, to.eta_minutes, to.status
FROM trip_offers to
JOIN users u ON to.driver_id = u.id
WHERE to.trip_id = 'xxx-xxx-xxx'
ORDER BY to.offered_price ASC;
```

3. **Utiliser l'API Supabase**
```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
)

// Exemple: Créer une offre de trajet
const { data, error } = await supabase
  .from('trip_offers')
  .insert({
    trip_id: tripId,
    driver_id: driverId,
    offered_price: 1500,
    eta_minutes: 8,
    vehicle_type: 'taxi'
  })
  .select()
  .maybeSingle()
```

---

## ✅ Résumé

Base de données complète et production-ready avec:
- ✅ 15 tables avec RLS
- ✅ 13 types ENUM
- ✅ Index optimisés
- ✅ Système de négociation complet
- ✅ Sécurité Row Level Security
- ✅ Contraintes d'intégrité
- ✅ Relations cohérentes

**Prêt pour utilisation avec PostgreSQL!** 🎉
