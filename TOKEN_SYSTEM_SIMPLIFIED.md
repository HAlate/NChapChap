# 🪙 Système de Jetons - Version Simplifiée (OPTIMALE)

**Date:** 2025-11-29
**Version:** 5.0 OPTIMALE
**Statut:** Production Ready

---

## 🎯 Principe Simplifié - SANS Remboursements

### ✅ NOUVELLE RÈGLE: Prélèvement APRÈS Acceptation

**Le jeton est prélevé UNIQUEMENT quand la course est ACCEPTÉE (prix final validé)**

**Avantages:**
- ✅ Plus de remboursements à gérer
- ✅ Logique plus simple
- ✅ Moins de transactions DB
- ✅ Pas de bugs potentiels remboursement
- ✅ UX plus claire pour drivers

---

## 🔄 Flux Complet Simplifié

### Scénario: Trajet (Rider ↔ Driver)

```
1. Rider crée demande trajet
   POST /ride-requests
   {
     "departure": "Lomé Centre",
     "destination": "Aéroport",
     "vehicle_type": "moto-taxi"
   }
   → Statut: 'pending'

2. Drivers AVEC jetons disponibles voient demande

   Règle d'affichage:
   SELECT * FROM ride_requests
   WHERE status = 'pending'
   AND EXISTS (
     SELECT 1 FROM token_balances
     WHERE user_id = :driver_id
     AND token_type = 'course'
     AND balance >= 1  -- ← VÉRIFICATION seulement
   )

3. Driver fait offre AVEC prix (jeton PAS ENCORE dépensé)

   POST /ride-offers
   {
     "ride_request_id": "req-123",
     "offered_price": 1500,
     "eta_minutes": 5
   }

   Vérification:
   ✅ Driver a >= 1 jeton course
   ✅ Offre créée
   ❌ Jeton PAS dépensé

   → Driver A: offre 1500 F (jeton intact: 5 → 5)
   → Driver B: offre 1200 F (jeton intact: 3 → 3)
   → Driver C: 0 jeton → invisible

4. Rider voit LISTE drivers avec prix

   ┌─────────────────────────────────┐
   │ Chauffeurs disponibles (2)      │
   ├─────────────────────────────────┤
   │                                 │
   │ 👤 Kofi • ⭐ 4.8               │
   │ 💰 1500 F • ⏱️ 5 min          │
   │ [Sélectionner]                  │
   │                                 │
   │ 👤 Ama • ⭐ 4.9                │
   │ 💰 1200 F • ⏱️ 8 min          │
   │ [Sélectionner]                  │
   │                                 │
   └─────────────────────────────────┘

5. Rider SÉLECTIONNE Kofi (1500 F)

   PUT /ride-offers/:kofi-offer-id/select

   → offer.status = 'selected'
   → ride_request.status = 'negotiating'
   → Ama: offre.status = 'not_selected' (jeton intact)

6. Écran négociation avec Kofi

   ┌─────────────────────────────────┐
   │ Négociation avec Kofi           │
   │                                 │
   │ Prix proposé: 1500 F            │
   │                                 │
   │ [✓ Accepter 1500 F]             │
   │ [↔ Contre-proposer]             │
   │ [✗ Annuler]                     │
   └─────────────────────────────────┘

7a. Rider ACCEPTE 1500 F

    PUT /ride-offers/:kofi-offer-id/accept
    {
      "final_price": 1500
    }

    BACKEND:
    ┌─────────────────────────────────┐
    │ Transaction atomique:           │
    │ 1. offer.status = 'accepted'    │
    │ 2. offer.final_price = 1500     │
    │ 3. ride_request.status = 'accepted' │
    │ 4. DÉPENSER 1 JETON KOFI ✅    │
    │    balance: 5 → 4               │
    └─────────────────────────────────┘

    → Course démarre ✅
    → Kofi: -1 jeton (maintenant)
    → Ama: jeton intact (jamais dépensé)

7b. Rider CONTRE-PROPOSE 1200 F

    PUT /ride-offers/:kofi-offer-id/counter
    {
      "counter_price": 1200
    }

    → offer.counter_price = 1200
    → Notification à Kofi
    → Jeton PAS ENCORE dépensé

    Kofi voit:
    ┌─────────────────────────────────┐
    │ Votre prix:      1500 F         │
    │ Contre-offre:    1200 F         │
    │                                 │
    │ [✓ Accepter 1200 F]             │
    │ [✗ Refuser]                     │
    └─────────────────────────────────┘

    7b.1. Kofi ACCEPTE 1200 F

          PUT /ride-offers/:kofi-offer-id/accept-counter

          BACKEND:
          ┌─────────────────────────────────┐
          │ Transaction atomique:           │
          │ 1. offer.status = 'accepted'    │
          │ 2. offer.final_price = 1200     │
          │ 3. DÉPENSER 1 JETON KOFI ✅    │
          │    balance: 5 → 4               │
          └─────────────────────────────────┘

          → Course démarre à 1200 F ✅

    7b.2. Kofi REFUSE

          PUT /ride-offers/:kofi-offer-id/reject-counter

          → offer.status = 'rejected'
          → ride_request.status = 'cancelled'
          → Jeton Kofi intact (jamais dépensé) ✅

7c. Rider ANNULE

    PUT /ride-requests/:req-123/cancel

    → ride_request.status = 'cancelled'
    → offer.status = 'cancelled'
    → Jeton Kofi intact (jamais dépensé) ✅
```

---

## 📊 Tables Supabase Optimisées

### Table: `ride_offers`

```sql
CREATE TABLE ride_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid REFERENCES ride_requests(id),
  driver_id uuid REFERENCES users(id),

  -- PRIX
  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int,
  final_price int,

  -- STATUTS
  status offer_status DEFAULT 'pending',
  -- 'pending' → Offre faite, en attente sélection rider
  -- 'selected' → Sélectionné par rider, en négociation
  -- 'accepted' → Prix accepté, JETON DÉPENSÉ ✅
  -- 'not_selected' → Pas sélectionné par rider (jeton intact)
  -- 'rejected' → Négociation échouée (jeton intact)
  -- 'cancelled' → Annulé par rider (jeton intact)

  -- JETON (dépensé SEULEMENT si accepted)
  token_spent boolean DEFAULT false,
  -- false → Jeton PAS dépensé (offre pending/selected)
  -- true → Jeton dépensé (offre accepted)

  eta_minutes int NOT NULL,
  vehicle_number text,
  driver_lat numeric,
  driver_lng numeric,

  created_at timestamptz DEFAULT now(),

  UNIQUE(ride_request_id, driver_id)
);
```

---

### Table: `delivery_offers`

```sql
CREATE TABLE delivery_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_request_id uuid REFERENCES delivery_requests(id),
  driver_id uuid REFERENCES users(id),

  offered_price int NOT NULL CHECK (offered_price > 0),
  counter_price int,
  final_price int,

  status offer_status DEFAULT 'pending',
  token_spent boolean DEFAULT false,  -- Dépensé SEULEMENT si accepted

  eta_minutes int NOT NULL,
  vehicle_type vehicle_type,

  created_at timestamptz DEFAULT now(),

  UNIQUE(delivery_request_id, driver_id)
);
```

---

### Table: `orders` (Restaurant/Marchand)

```sql
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id uuid REFERENCES users(id),
  provider_id uuid REFERENCES users(id),
  provider_type provider_type,  -- 'restaurant' ou 'merchant'

  items jsonb DEFAULT '[]',

  -- NÉGOCIATION PRIX REPAS (Rider ↔ Restaurant)
  items_proposed_price int,
  items_counter_price int,
  items_final_price int,
  items_negotiation_status negotiation_status,

  status order_status DEFAULT 'pending',

  -- JETON RESTAURANT (dépensé SEULEMENT si order accepted)
  provider_token_spent boolean DEFAULT false,

  delivery_address text,
  created_at timestamptz DEFAULT now(),
  confirmed_at timestamptz
);
```

---

## ⚙️ Fonctions Backend

### Fonction: `spend_token_on_acceptance()`

**Appelée UNIQUEMENT quand offre acceptée**

```sql
CREATE OR REPLACE FUNCTION spend_token_on_acceptance(
  p_user_id uuid,
  p_token_type token_type,
  p_offer_id uuid,
  p_description text DEFAULT ''
)
RETURNS boolean AS $$
DECLARE
  v_current_balance int;
BEGIN
  -- Vérifier solde
  SELECT balance INTO v_current_balance
  FROM token_balances
  WHERE user_id = p_user_id AND token_type = p_token_type
  FOR UPDATE;

  IF v_current_balance < 1 THEN
    RAISE EXCEPTION 'Insufficient % tokens', p_token_type;
  END IF;

  -- Déduire jeton
  UPDATE token_balances
  SET balance = balance - 1,
      total_spent = total_spent + 1,
      updated_at = now()
  WHERE user_id = p_user_id AND token_type = p_token_type;

  -- Logger transaction
  INSERT INTO token_transactions (
    user_id,
    transaction_type,
    token_type,
    amount,
    reference_id,
    notes
  ) VALUES (
    p_user_id,
    'spend',
    p_token_type,
    -1,
    p_offer_id,
    p_description
  );

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### Fonction: `check_token_availability()`

**Vérifier avant afficher demande au driver**

```sql
CREATE OR REPLACE FUNCTION check_token_availability(
  p_user_id uuid,
  p_token_type token_type
)
RETURNS boolean AS $$
DECLARE
  v_balance int;
BEGIN
  SELECT balance INTO v_balance
  FROM token_balances
  WHERE user_id = p_user_id AND token_type = p_token_type;

  RETURN COALESCE(v_balance, 0) >= 1;
END;
$$ LANGUAGE plpgsql;
```

---

## 🔒 RLS Policies Optimisées

### Policy: Drivers voient demandes SI jetons disponibles

```sql
-- Drivers peuvent lire ride_requests SI balance >= 1
CREATE POLICY "Drivers with tokens can read pending requests"
  ON ride_requests FOR SELECT
  TO authenticated
  USING (
    status = 'pending'
    AND (
      SELECT balance >= 1
      FROM token_balances
      WHERE user_id = auth.uid()
      AND token_type = 'course'
    )
  );
```

---

### Policy: Création offre SI jetons disponibles

```sql
-- Drivers peuvent créer offre SI balance >= 1
CREATE POLICY "Drivers with tokens can create offers"
  ON ride_offers FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = driver_id
    AND (
      SELECT balance >= 1
      FROM token_balances
      WHERE user_id = auth.uid()
      AND token_type = 'course'
    )
  );
```

---

## 📱 Code Backend API

### Endpoint: Accepter offre (dépense jeton)

```typescript
// backend/src/routes/ride-offers.ts

router.put('/:offerId/accept', async (req, res) => {
  const { offerId } = req.params;
  const { final_price } = req.body;
  const riderId = req.user.id;

  try {
    // Transaction atomique
    await supabase.rpc('accept_ride_offer', {
      p_offer_id: offerId,
      p_rider_id: riderId,
      p_final_price: final_price,
    });

    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
```

---

### Fonction Postgres: `accept_ride_offer()`

```sql
CREATE OR REPLACE FUNCTION accept_ride_offer(
  p_offer_id uuid,
  p_rider_id uuid,
  p_final_price int
)
RETURNS void AS $$
DECLARE
  v_driver_id uuid;
  v_request_id uuid;
BEGIN
  -- Récupérer info offre
  SELECT driver_id, ride_request_id
  INTO v_driver_id, v_request_id
  FROM ride_offers
  WHERE id = p_offer_id;

  -- Vérifier que rider est bien le demandeur
  IF NOT EXISTS (
    SELECT 1 FROM ride_requests
    WHERE id = v_request_id
    AND rider_id = p_rider_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Vérifier que driver a toujours jeton
  IF NOT check_token_availability(v_driver_id, 'course') THEN
    RAISE EXCEPTION 'Driver has insufficient tokens';
  END IF;

  -- 1. Marquer offre acceptée
  UPDATE ride_offers
  SET status = 'accepted',
      final_price = p_final_price,
      token_spent = true
  WHERE id = p_offer_id;

  -- 2. DÉPENSER JETON DRIVER
  PERFORM spend_token_on_acceptance(
    v_driver_id,
    'course',
    p_offer_id,
    'Course acceptée #' || v_request_id
  );

  -- 3. Marquer demande acceptée
  UPDATE ride_requests
  SET status = 'accepted'
  WHERE id = v_request_id;

  -- 4. Marquer autres offres comme non sélectionnées
  UPDATE ride_offers
  SET status = 'not_selected'
  WHERE ride_request_id = v_request_id
  AND id != p_offer_id
  AND status = 'pending';

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 🎨 UI Flutter - Affichage Solde

### Widget: Balance Jetons avec Avertissement

```dart
class TokenBalanceWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(tokenBalanceProvider);

    return Card(
      color: balance.courseTokens > 0
        ? Colors.green[50]
        : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.toll,
                      color: balance.courseTokens > 0
                        ? Colors.green
                        : Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Jetons Course',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${balance.courseTokens}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: balance.courseTokens > 0
                      ? Colors.green
                      : Colors.red,
                  ),
                ),
              ],
            ),

            if (balance.courseTokens == 0) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rechargez pour voir les demandes de trajets',
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/tokens/buy'),
                icon: Icon(Icons.shopping_cart),
                label: Text('Acheter des jetons'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ],

            if (balance.courseTokens > 0 && balance.courseTokens <= 3) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solde faible. Pensez à recharger.',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

### Screen: Liste Demandes (avec check jetons)

```dart
class DriverRequestsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(tokenBalanceProvider);
    final requests = ref.watch(rideRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Demandes de trajets')),
      body: Column(
        children: [
          // Balance en haut
          TokenBalanceWidget(),

          // Liste demandes (visible SI jetons > 0)
          if (balance.courseTokens == 0)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Vous devez avoir des jetons\npour voir les demandes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/tokens/buy'),
                      icon: Icon(Icons.shopping_cart),
                      label: Text('Acheter des jetons'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: requests.when(
                data: (data) {
                  if (data.isEmpty) {
                    return Center(
                      child: Text('Aucune demande disponible'),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final request = data[index];
                      return RideRequestCard(
                        request: request,
                        onMakeOffer: () => _makeOffer(request),
                      );
                    },
                  );
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Erreur: $error')),
              ),
            ),
        ],
      ),
    );
  }

  void _makeOffer(RideRequest request) {
    // Ouvrir dialog pour entrer prix
    showDialog(
      context: context,
      builder: (context) => MakeOfferDialog(
        request: request,
        onSubmit: (price, eta) async {
          await supabase.from('ride_offers').insert({
            'ride_request_id': request.id,
            'driver_id': currentUserId,
            'offered_price': price,
            'eta_minutes': eta,
            'token_spent': false,  // ← PAS ENCORE dépensé
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offre envoyée! Jeton sera dépensé si acceptée.'),
            ),
          );
        },
      ),
    );
  }
}
```

---

## 📊 Statistiques Simplifiées

### Dashboard Driver

```dart
class DriverStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(driverStatsProvider);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes Statistiques',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),

            // Jetons
            _StatRow(
              label: 'Jetons disponibles',
              value: '${stats.currentBalance}',
              icon: Icons.toll,
              color: Colors.green,
            ),

            _StatRow(
              label: 'Jetons dépensés',
              value: '${stats.totalSpent}',
              icon: Icons.remove_circle,
              color: Colors.red,
            ),

            Divider(height: 32),

            // Offres
            _StatRow(
              label: 'Offres faites',
              value: '${stats.totalOffers}',
              icon: Icons.send,
            ),

            _StatRow(
              label: 'Offres acceptées',
              value: '${stats.acceptedOffers}',
              icon: Icons.check_circle,
              color: Colors.green,
            ),

            _StatRow(
              label: 'Taux de réussite',
              value: '${stats.successRate}%',
              icon: Icons.trending_up,
              color: Colors.blue,
            ),

            Divider(height: 32),

            // Revenus
            _StatRow(
              label: 'Revenus totaux',
              value: '${stats.totalRevenue} F',
              icon: Icons.monetization_on,
              color: Colors.orange,
            ),

            _StatRow(
              label: 'Coût jetons',
              value: '${stats.tokenCost} F',
              icon: Icons.payment,
              color: Colors.grey,
            ),

            _StatRow(
              label: 'Bénéfice net',
              value: '${stats.netProfit} F',
              icon: Icons.account_balance_wallet,
              color: Colors.green,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 Avantages Système Simplifié

### ✅ Comparaison Ancien vs Nouveau

| Aspect | ❌ Ancien (Dépense immédiate) | ✅ Nouveau (Dépense à acceptation) |
|--------|-------------------------------|-------------------------------------|
| **Complexité** | Haute (remboursements) | Simple (pas de remboursement) |
| **Transactions DB** | 2x (dépense + remboursement) | 1x (dépense seulement) |
| **Bugs potentiels** | Remboursement oublié | Aucun |
| **UX Driver** | Perte jeton si rejeté | Jeton préservé |
| **Équité** | Drivers paient pour essayer | Drivers paient si acceptés |
| **Code backend** | Complexe (cron remboursement) | Simple |

---

## 📝 Résumé Points Clés

### ✅ Règles Simplifiées

1. **Driver voit demandes SI** `balance >= 1`
2. **Driver fait offre** → Jeton PAS dépensé (vérifié seulement)
3. **Rider sélectionne driver** → Négociation ouvre
4. **Prix accepté** → **JETON DÉPENSÉ** ✅
5. **Prix rejeté/annulé** → Jeton intact ✅

### 🔑 Moments de Dépense Jeton

**JETON DÉPENSÉ UNIQUEMENT DANS CES CAS:**
- ✅ Rider accepte prix proposé
- ✅ Rider contre-propose ET driver accepte
- ✅ Restaurant/Marchand accepte offre driver livraison

**JETON JAMAIS DÉPENSÉ SI:**
- ❌ Offre non sélectionnée (autre driver choisi)
- ❌ Négociation échouée (contre-offre refusée)
- ❌ Demande annulée par rider/restaurant

---

## 🚀 Migration Données Existantes

```sql
-- Si données existantes avec ancien système, réinitialiser
UPDATE ride_offers
SET token_spent = false
WHERE status IN ('pending', 'selected', 'not_selected', 'rejected', 'cancelled');

UPDATE ride_offers
SET token_spent = true
WHERE status = 'accepted';

-- Recalculer balances
UPDATE token_balances tb
SET balance = balance + (
  SELECT COUNT(*)
  FROM ride_offers ro
  WHERE ro.driver_id = tb.user_id
  AND ro.token_spent = true
  AND ro.status != 'accepted'
);
```

---

**Document généré:** 2025-11-29
**Version:** 5.0 OPTIMALE (Simplifiée)
**Statut:** ✅ Production Ready

**Changement majeur:** Dépense jeton APRÈS acceptation uniquement = Système beaucoup plus simple et équitable! 🎉
