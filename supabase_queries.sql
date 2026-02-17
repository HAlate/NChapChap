-- ============================================================================
-- Requêtes SQL Utiles - Urban Mobility Platform
-- ============================================================================
-- Database: Supabase PostgreSQL
-- Date: 2025-11-29
-- Version: 1.0
-- ============================================================================

-- ============================================================================
-- SECTION 1: UTILISATEURS ET PROFILS
-- ============================================================================

-- Voir tous les utilisateurs par type
SELECT
  user_type,
  COUNT(*) as total,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as actifs
FROM users
GROUP BY user_type
ORDER BY total DESC;

-- Voir tous les drivers disponibles avec détails
SELECT
  u.id,
  u.full_name,
  u.phone,
  u.email,
  dp.vehicle_type,
  dp.vehicle_plate,
  dp.is_available,
  dp.rating_average,
  dp.total_trips,
  dp.total_deliveries,
  dp.current_lat,
  dp.current_lng
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
WHERE u.status = 'active'
  AND dp.is_available = true
ORDER BY dp.rating_average DESC;

-- Voir tous les restaurants ouverts
SELECT
  u.id,
  rp.name,
  rp.cuisine_type,
  rp.address,
  rp.phone,
  rp.rating_average,
  rp.total_orders,
  rp.min_order_amount,
  rp.estimated_prep_time_minutes
FROM users u
JOIN restaurant_profiles rp ON u.id = rp.id
WHERE u.status = 'active'
  AND rp.is_open = true
ORDER BY rp.rating_average DESC;

-- Voir tous les marchands ouverts
SELECT
  u.id,
  mp.business_name,
  mp.business_type,
  mp.address,
  mp.phone,
  mp.rating_average,
  mp.total_orders,
  mp.min_order_amount
FROM users u
JOIN merchant_profiles mp ON u.id = mp.id
WHERE u.status = 'active'
  AND mp.is_open = true
ORDER BY mp.rating_average DESC;

-- ============================================================================
-- SECTION 2: JETONS (TOKENS)
-- ============================================================================

-- Voir solde jetons d'un utilisateur
SELECT
  u.full_name,
  u.user_type,
  tb.token_type,
  tb.balance,
  tb.total_purchased,
  tb.total_spent
FROM token_balances tb
JOIN users u ON tb.user_id = u.id
WHERE u.id = 'USER_ID_HERE'
ORDER BY tb.token_type;

-- Voir historique transactions jetons d'un utilisateur
SELECT
  tt.transaction_type,
  tt.token_type,
  tt.amount,
  tt.balance_before,
  tt.balance_after,
  tt.payment_method,
  tt.notes,
  tt.created_at
FROM token_transactions tt
WHERE tt.user_id = 'USER_ID_HERE'
ORDER BY tt.created_at DESC
LIMIT 50;

-- Voir packages jetons actifs
SELECT
  name,
  token_type,
  token_amount,
  bonus_tokens,
  price_fcfa,
  (token_amount + bonus_tokens) as total_tokens,
  ROUND(price_fcfa::numeric / (token_amount + bonus_tokens), 2) as price_per_token
FROM token_packages
WHERE is_active = true
ORDER BY token_type, price_fcfa;

-- Voir drivers avec jetons disponibles
SELECT
  u.full_name,
  dp.vehicle_type,
  tb.balance as jetons_disponibles
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
JOIN token_balances tb ON u.id = tb.user_id
WHERE u.user_type = 'driver'
  AND tb.token_type = 'course'
  AND tb.balance > 0
ORDER BY tb.balance DESC;

-- ============================================================================
-- SECTION 3: TRAJETS ET OFFRES
-- ============================================================================

-- Voir trajets en attente
SELECT
  t.id,
  u.full_name as rider_name,
  u.phone as rider_phone,
  t.vehicle_type,
  t.departure,
  t.destination,
  t.status,
  t.created_at,
  COUNT(to2.id) as nombre_offres
FROM trips t
JOIN users u ON t.rider_id = u.id
LEFT JOIN trip_offers to2 ON t.id = to2.trip_id
WHERE t.status = 'pending'
GROUP BY t.id, u.full_name, u.phone, t.vehicle_type, t.departure, t.destination, t.status, t.created_at
ORDER BY t.created_at DESC;

-- Voir offres pour un trajet spécifique
SELECT
  u.full_name as driver_name,
  u.phone as driver_phone,
  dp.vehicle_type,
  dp.rating_average,
  dp.total_trips,
  to2.offered_price,
  to2.counter_price,
  to2.final_price,
  to2.eta_minutes,
  to2.status,
  to2.token_spent,
  to2.created_at
FROM trip_offers to2
JOIN users u ON to2.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
WHERE to2.trip_id = 'TRIP_ID_HERE'
ORDER BY to2.offered_price ASC;

-- Voir trajets complétés avec stats
SELECT
  DATE(t.completed_at) as date,
  COUNT(*) as total_trajets,
  AVG(t.final_price) as prix_moyen,
  MIN(t.final_price) as prix_min,
  MAX(t.final_price) as prix_max,
  AVG(t.driver_rating) as note_driver_moyenne,
  AVG(t.rider_rating) as note_rider_moyenne
FROM trips t
WHERE t.status = 'completed'
  AND t.completed_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(t.completed_at)
ORDER BY date DESC;

-- Top 10 drivers par nombre de trajets
SELECT
  u.full_name,
  dp.vehicle_type,
  dp.total_trips,
  dp.rating_average,
  ROUND(AVG(t.final_price), 0) as prix_moyen_trajet
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
LEFT JOIN trips t ON u.id = t.driver_id AND t.status = 'completed'
WHERE u.user_type = 'driver'
GROUP BY u.id, u.full_name, dp.vehicle_type, dp.total_trips, dp.rating_average
ORDER BY dp.total_trips DESC
LIMIT 10;

-- ============================================================================
-- SECTION 4: COMMANDES ET LIVRAISONS
-- ============================================================================

-- Voir commandes en attente par restaurant
SELECT
  rp.name as restaurant,
  COUNT(*) as commandes_en_attente,
  SUM(o.total_amount) as montant_total
FROM orders o
JOIN restaurant_profiles rp ON o.provider_id = rp.id
WHERE o.status IN ('pending', 'confirmed', 'preparing')
  AND o.provider_type = 'restaurant'
GROUP BY rp.name
ORDER BY commandes_en_attente DESC;

-- Voir commandes prêtes pour livraison
SELECT
  o.id,
  CASE
    WHEN o.provider_type = 'restaurant' THEN rp.name
    WHEN o.provider_type = 'merchant' THEN mp.business_name
  END as provider_name,
  o.provider_type,
  u.full_name as rider_name,
  u.phone as rider_phone,
  o.delivery_address,
  o.total_amount,
  o.status,
  o.ready_at
FROM orders o
JOIN users u ON o.rider_id = u.id
LEFT JOIN restaurant_profiles rp ON o.provider_id = rp.id AND o.provider_type = 'restaurant'
LEFT JOIN merchant_profiles mp ON o.provider_id = mp.id AND o.provider_type = 'merchant'
WHERE o.status = 'ready'
ORDER BY o.ready_at ASC;

-- Voir demandes de livraison en attente
SELECT
  dr.id,
  CASE
    WHEN dr.requester_type = 'restaurant' THEN rp.name
    WHEN dr.requester_type = 'merchant' THEN mp.business_name
  END as requester_name,
  dr.requester_type,
  dr.pickup_address,
  dr.delivery_address,
  dr.status,
  dr.created_at,
  dr.expires_at,
  COUNT(do2.id) as nombre_offres
FROM delivery_requests dr
LEFT JOIN restaurant_profiles rp ON dr.requester_id = rp.id AND dr.requester_type = 'restaurant'
LEFT JOIN merchant_profiles mp ON dr.requester_id = mp.id AND dr.requester_type = 'merchant'
LEFT JOIN delivery_offers do2 ON dr.id = do2.delivery_request_id
WHERE dr.status = 'pending'
GROUP BY dr.id, rp.name, mp.business_name, dr.requester_type, dr.pickup_address, dr.delivery_address, dr.status, dr.created_at, dr.expires_at
ORDER BY dr.created_at DESC;

-- Voir offres de livraison pour une demande
SELECT
  u.full_name as driver_name,
  u.phone as driver_phone,
  dp.vehicle_type,
  dp.rating_average,
  dp.total_deliveries,
  do2.offered_price,
  do2.counter_price,
  do2.final_price,
  do2.eta_minutes,
  do2.status,
  do2.token_spent,
  do2.created_at
FROM delivery_offers do2
JOIN users u ON do2.driver_id = u.id
JOIN driver_profiles dp ON u.id = dp.id
WHERE do2.delivery_request_id = 'DELIVERY_REQUEST_ID_HERE'
ORDER BY do2.offered_price ASC;

-- Stats livraisons par driver
SELECT
  u.full_name,
  dp.vehicle_type,
  dp.total_deliveries,
  dp.rating_average,
  COUNT(CASE WHEN do2.status = 'accepted' THEN 1 END) as livraisons_acceptees,
  AVG(CASE WHEN do2.status = 'accepted' THEN do2.final_price END) as prix_moyen_livraison
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
LEFT JOIN delivery_offers do2 ON u.id = do2.driver_id
WHERE u.user_type = 'driver'
GROUP BY u.id, u.full_name, dp.vehicle_type, dp.total_deliveries, dp.rating_average
HAVING COUNT(CASE WHEN do2.status = 'accepted' THEN 1 END) > 0
ORDER BY dp.total_deliveries DESC;

-- ============================================================================
-- SECTION 5: PRODUITS ET MENUS
-- ============================================================================

-- Voir menu d'un restaurant
SELECT
  mi.category,
  mi.name,
  mi.description,
  mi.price,
  mi.preparation_time_minutes,
  mi.is_available
FROM menu_items mi
WHERE mi.restaurant_id = 'RESTAURANT_ID_HERE'
  AND mi.is_available = true
ORDER BY mi.category, mi.name;

-- Voir produits d'un marchand
SELECT
  p.category,
  p.name,
  p.description,
  p.price,
  p.stock_quantity,
  p.is_available
FROM products p
WHERE p.merchant_id = 'MERCHANT_ID_HERE'
  AND p.is_available = true
ORDER BY p.category, p.name;

-- Top plats les plus commandés
SELECT
  rp.name as restaurant,
  jsonb_array_elements(o.items)->>'name' as plat,
  COUNT(*) as nombre_commandes,
  SUM((jsonb_array_elements(o.items)->>'quantity')::int) as quantite_totale
FROM orders o
JOIN restaurant_profiles rp ON o.provider_id = rp.id
WHERE o.provider_type = 'restaurant'
  AND o.status = 'delivered'
GROUP BY rp.name, jsonb_array_elements(o.items)->>'name'
ORDER BY nombre_commandes DESC
LIMIT 20;

-- ============================================================================
-- SECTION 6: PAIEMENTS
-- ============================================================================

-- Voir paiements d'un utilisateur
SELECT
  p.payment_type,
  p.amount,
  p.payment_method,
  p.status,
  p.reference_type,
  p.created_at,
  p.processed_at
FROM payments p
WHERE p.payer_id = 'USER_ID_HERE'
ORDER BY p.created_at DESC
LIMIT 50;

-- Stats paiements par méthode
SELECT
  payment_method,
  payment_type,
  COUNT(*) as total_transactions,
  SUM(amount) as montant_total,
  AVG(amount) as montant_moyen
FROM payments
WHERE status = 'completed'
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY payment_method, payment_type
ORDER BY montant_total DESC;

-- Revenus par jour (derniers 30 jours)
SELECT
  DATE(created_at) as date,
  payment_type,
  COUNT(*) as nombre_transactions,
  SUM(amount) as revenus
FROM payments
WHERE status = 'completed'
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at), payment_type
ORDER BY date DESC, payment_type;

-- ============================================================================
-- SECTION 7: STATISTIQUES GLOBALES
-- ============================================================================

-- Vue d'ensemble plateforme
SELECT
  'Users' as type,
  user_type as categorie,
  COUNT(*) as total
FROM users
WHERE status = 'active'
GROUP BY user_type

UNION ALL

SELECT
  'Trips' as type,
  status as categorie,
  COUNT(*) as total
FROM trips
GROUP BY status

UNION ALL

SELECT
  'Orders' as type,
  status as categorie,
  COUNT(*) as total
FROM orders
GROUP BY status

ORDER BY type, categorie;

-- Activité aujourd'hui
SELECT
  'Nouveaux users' as metrique,
  COUNT(*) as valeur
FROM users
WHERE DATE(created_at) = CURRENT_DATE

UNION ALL

SELECT
  'Trajets complétés',
  COUNT(*)
FROM trips
WHERE DATE(completed_at) = CURRENT_DATE

UNION ALL

SELECT
  'Commandes livrées',
  COUNT(*)
FROM orders
WHERE DATE(delivered_at) = CURRENT_DATE

UNION ALL

SELECT
  'Revenus trajets (FCFA)',
  COALESCE(SUM(amount), 0)
FROM payments
WHERE DATE(created_at) = CURRENT_DATE
  AND payment_type = 'trip'
  AND status = 'completed'

UNION ALL

SELECT
  'Revenus livraisons (FCFA)',
  COALESCE(SUM(amount), 0)
FROM payments
WHERE DATE(created_at) = CURRENT_DATE
  AND payment_type = 'delivery'
  AND status = 'completed';

-- ============================================================================
-- SECTION 8: FONCTIONS UTILITAIRES
-- ============================================================================

-- Fonction: Dépenser jeton driver (à utiliser dans API)
-- Cette fonction gère la dépense d'un jeton de manière atomique
CREATE OR REPLACE FUNCTION spend_driver_token(
  p_driver_id uuid,
  p_token_type token_type,
  p_reference_id uuid,
  p_reference_type text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance int;
  v_balance_before int;
BEGIN
  -- Vérifier le solde actuel
  SELECT balance INTO v_balance
  FROM token_balances
  WHERE user_id = p_driver_id AND token_type = p_token_type
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < 1 THEN
    RAISE EXCEPTION 'Insufficient token balance';
  END IF;

  v_balance_before := v_balance;

  -- Décrémenter le solde
  UPDATE token_balances
  SET
    balance = balance - 1,
    total_spent = total_spent + 1,
    updated_at = now()
  WHERE user_id = p_driver_id AND token_type = p_token_type;

  -- Enregistrer la transaction
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    balance_before,
    balance_after,
    reference_id,
    notes
  ) VALUES (
    p_driver_id,
    'spend',
    p_token_type,
    -1,
    v_balance_before,
    v_balance_before - 1,
    p_reference_id,
    'Token spent for ' || p_reference_type
  );

  RETURN true;
END;
$$;

-- Fonction: Ajouter jetons (à utiliser dans API)
CREATE OR REPLACE FUNCTION add_tokens(
  p_user_id uuid,
  p_token_type token_type,
  p_amount int,
  p_payment_method text,
  p_reference_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance_before int;
BEGIN
  -- Créer balance si n'existe pas
  INSERT INTO token_balances (user_id, token_type, balance)
  VALUES (p_user_id, p_token_type, 0)
  ON CONFLICT (user_id, token_type) DO NOTHING;

  -- Obtenir balance actuel
  SELECT balance INTO v_balance_before
  FROM token_balances
  WHERE user_id = p_user_id AND token_type = p_token_type
  FOR UPDATE;

  -- Ajouter jetons
  UPDATE token_balances
  SET
    balance = balance + p_amount,
    total_purchased = total_purchased + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id AND token_type = p_token_type;

  -- Enregistrer transaction
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    balance_before,
    balance_after,
    reference_id,
    payment_method,
    notes
  ) VALUES (
    p_user_id,
    'purchase',
    p_token_type,
    p_amount,
    v_balance_before,
    v_balance_before + p_amount,
    p_reference_id,
    p_payment_method,
    'Token purchase'
  );

  RETURN true;
END;
$$;

-- ============================================================================
-- FIN DU FICHIER
-- ============================================================================
