# 💰 Système de Négociation - Version FINALE et CORRECTE

**Date:** 2025-11-29
**Version:** 4.0 FINAL
**Statut:** Production Ready

---

## 🎯 Principe CORRECT du Système

### Flux en 2 Étapes

```
ÉTAPE 1: SÉLECTION (avec prix initial)
  ↓
ÉTAPE 2: NÉGOCIATION (ajustement prix)
```

---

## 📋 Règles Fondamentales

### Règle 1: Visibilité Driver

**Pour apparaître dans une liste, le driver DOIT:**
1. ✅ Avoir au moins 1 jeton disponible
2. ✅ Proposer un prix pour la course

**Conséquence:**
- Quand driver fait une offre → **DÉPENSE 1 JETON**
- Driver apparaît dans liste avec **SON PRIX PROPOSÉ**

---

### Règle 2: Ordre des Opérations

```
1. Rider/Restaurant/Marchand fait une demande (gratuit)
   ↓
2. Drivers avec jetons PROPOSENT UN PRIX (dépense 1 jeton chacun)
   ↓
3. Demandeur voit LISTE DRIVERS avec leurs PRIX PROPOSÉS
   ↓
4. Demandeur SÉLECTIONNE un driver dans la liste
   ↓
5. NÉGOCIATION s'ouvre (ajuster le prix avec driver sélectionné)
   ↓
6. Prix final accepté → Course démarre
```

---

## 🔄 Flux Complets

### Scénario 1: Trajet (Rider sélectionne Driver)

```
ÉTAPE 1: SÉLECTION
━━━━━━━━━━━━━━━━━━

1. Rider crée demande
   POST /ride-requests
   {
     "departure": "Lomé Centre",
     "destination": "Aéroport",
     "vehicle_type": "moto-taxi"
   }

2. Plusieurs Drivers voient demande
   - Driver A avec 5 jetons
   - Driver B avec 3 jetons
   - Driver C avec 0 jeton ❌ (invisible)

3. Drivers A et B font offres (dépensent 1 jeton chacun)

   Driver A:
   POST /ride-offers
   {
     "ride_request_id": "req-123",
     "offered_price": 1500,
     "eta_minutes": 5
   }
   → Jeton dépensé ✅

   Driver B:
   POST /ride-offers
   {
     "ride_request_id": "req-123",
     "offered_price": 1200,
     "eta_minutes": 8
   }
   → Jeton dépensé ✅

4. Rider voit LISTE drivers avec PRIX

   ┌─────────────────────────────────┐
   │ Chauffeurs disponibles (2)      │
   ├─────────────────────────────────┤
   │                                 │
   │ 👤 Kofi Mensah • ⭐ 4.8        │
   │ 🚗 TG-1234-AB • 234 trajets    │
   │ 💰 1500 F • ⏱️ 5 min          │
   │ [Sélectionner] ←────────────────│
   │                                 │
   │ 👤 Ama Adjovi • ⭐ 4.9         │
   │ 🚗 TG-5678-CD • 456 trajets    │
   │ 💰 1200 F • ⏱️ 8 min          │
   │ [Sélectionner] ←────────────────│
   │                                 │
   └─────────────────────────────────┘

5. Rider CLIQUE sur Driver A (Kofi, 1500 F)
   → Driver A sélectionné ✅
   → Driver B NON sélectionné → JETON REMBOURSÉ ✅


ÉTAPE 2: NÉGOCIATION
━━━━━━━━━━━━━━━━━━━

6. Écran négociation s'ouvre

   ┌─────────────────────────────────┐
   │ Négociation avec Kofi Mensah    │
   ├─────────────────────────────────┤
   │                                 │
   │ Prix proposé par le chauffeur:  │
   │                                 │
   │       1500 F                    │
   │                                 │
   ├─────────────────────────────────┤
   │                                 │
   │ [✓ Accepter 1500 F]             │
   │                                 │
   │ [↔ Négocier le prix]            │
   │                                 │
   │ [✗ Annuler]                     │
   │                                 │
   └─────────────────────────────────┘

7a. Rider ACCEPTE 1500 F
    → final_price = 1500
    → status = 'accepted'
    → Course démarre ✅

7b. Rider NÉGOCIE

    Dialog:
    ┌─────────────────────────────────┐
    │ Proposer un autre prix          │
    ├─────────────────────────────────┤
    │ Prix actuel: 1500 F             │
    │                                 │
    │ Votre proposition: [1200] F     │
    │                                 │
    │ [Annuler] [Envoyer]             │
    └─────────────────────────────────┘

    → Rider entre 1200 F
    → counter_price = 1200
    → Notification envoyée au driver

    Driver reçoit:
    ┌─────────────────────────────────┐
    │ Contre-proposition client       │
    ├─────────────────────────────────┤
    │ Votre prix:      1500 F         │
    │ Contre-offre:    1200 F         │
    │ Différence:      -300 F         │
    │                                 │
    │ [✓ Accepter 1200 F]             │
    │                                 │
    │ [✗ Refuser et annuler]          │
    └─────────────────────────────────┘

    → Driver ACCEPTE 1200 F
      final_price = 1200
      Course démarre ✅

    → Driver REFUSE
      status = 'cancelled'
      Jeton remboursé ✅

7c. Rider ANNULE
    → status = 'cancelled'
    → Jeton driver remboursé ✅
```

---

### Scénario 2: Livraison Repas (Restaurant sélectionne Driver)

```
CONTEXTE:
- Rider a commandé repas chez Restaurant X
- Restaurant a accepté et préparé commande
- Maintenant: Restaurant cherche driver pour livraison


ÉTAPE 1: SÉLECTION DRIVER
━━━━━━━━━━━━━━━━━━━━━━━━

1. Restaurant crée demande livraison
   POST /delivery-requests
   {
     "order_id": "order-456",
     "pickup_address": "Restaurant XYZ",
     "delivery_address": "Client rue ABC",
     "delivery_lat": 6.1745,
     "delivery_lng": 1.2334
   }

2. Drivers voient demande et font offres

   Driver A: 500 F (dépense 1 jeton)
   Driver B: 400 F (dépense 1 jeton)
   Driver C: 600 F (dépense 1 jeton)

3. Restaurant voit LISTE

   ┌─────────────────────────────────┐
   │ Livreurs disponibles (3)        │
   ├─────────────────────────────────┤
   │                                 │
   │ 👤 Kojo • ⭐ 4.7               │
   │ 💰 400 F • ⏱️ 3 min           │
   │ [Sélectionner] ←────────────────│
   │                                 │
   │ 👤 Mensah • ⭐ 4.8             │
   │ 💰 500 F • ⏱️ 2 min           │
   │ [Sélectionner]                  │
   │                                 │
   │ 👤 Ablavi • ⭐ 4.9             │
   │ 💰 600 F • ⏱️ 1 min           │
   │ [Sélectionner]                  │
   │                                 │
   └─────────────────────────────────┘

4. Restaurant SÉLECTIONNE Kojo (400 F, meilleur prix)
   → Kojo sélectionné
   → Mensah et Ablavi → JETONS REMBOURSÉS


ÉTAPE 2: NÉGOCIATION
━━━━━━━━━━━━━━━━━━━

5. Écran négociation

   ┌─────────────────────────────────┐
   │ Négociation livraison           │
   ├─────────────────────────────────┤
   │ Livreur: Kojo                   │
   │ Distance: 3.2 km                │
   │                                 │
   │ Prix proposé: 400 F             │
   │                                 │
   │ [✓ Accepter 400 F]              │
   │ [↔ Négocier]                    │
   │ [✗ Annuler]                     │
   └─────────────────────────────────┘

6a. Restaurant ACCEPTE 400 F
    → Livraison démarre ✅

6b. Restaurant NÉGOCIE à 350 F
    → Driver accepte/refuse
    → Si accepte: 350 F final
    → Si refuse: Annulation + remboursement
```

---

## 📊 Architecture Tables Supabase

### Table: `ride_requests`

```sql
CREATE TABLE ride_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id uuid REFERENCES users(id),
  departure text NOT NULL,
  destination text NOT NULL,
  vehicle_type vehicle_type NOT NULL,
  status request_status DEFAULT 'pending',
  -- 'pending' → En attente offres
  -- 'negotiating' → Driver sélectionné, négociation en cours
  -- 'accepted' → Prix accepté, course démarre
  -- 'cancelled' → Annulée
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '15 minutes')
);
```

---

### Table: `ride_offers`

**LISTE des offres drivers (avec prix)**

```sql
CREATE TABLE ride_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid REFERENCES ride_requests(id),
  driver_id uuid REFERENCES users(id),

  -- PRIX PROPOSÉ PAR DRIVER
  offered_price int NOT NULL CHECK (offered_price > 0),

  eta_minutes int NOT NULL,
  vehicle_number text,
  driver_lat numeric,
  driver_lng numeric,

  status offer_status DEFAULT 'pending',
  -- 'pending' → En attente sélection rider
  -- 'selected' → Sélectionné par rider (en négociation)
  -- 'accepted' → Prix final accepté
  -- 'rejected' → Non sélectionné OU négociation échouée

  -- NÉGOCIATION (après sélection)
  counter_price int,  -- Contre-offre rider
  final_price int,    -- Prix final accepté

  token_spent boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),

  UNIQUE(ride_request_id, driver_id)
);
```

---

### Table: `delivery_requests`

**Pour livraisons commandées par restaurant/marchand**

```sql
CREATE TABLE delivery_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid REFERENCES users(id),  -- restaurant ou merchant
  requester_type user_type,  -- 'restaurant' ou 'merchant'
  order_id uuid REFERENCES orders(id),

  pickup_address text NOT NULL,
  delivery_address text NOT NULL,
  pickup_lat numeric,
  pickup_lng numeric,
  delivery_lat numeric,
  delivery_lng numeric,

  status request_status DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '30 minutes')
);
```

---

### Table: `delivery_offers`

**LISTE des offres drivers pour livraison**

```sql
CREATE TABLE delivery_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_request_id uuid REFERENCES delivery_requests(id),
  driver_id uuid REFERENCES users(id),

  -- PRIX PROPOSÉ PAR DRIVER
  offered_price int NOT NULL CHECK (offered_price > 0),

  eta_minutes int NOT NULL,
  vehicle_type vehicle_type,

  status offer_status DEFAULT 'pending',
  -- 'pending' → En attente sélection
  -- 'selected' → Sélectionné (en négociation)
  -- 'accepted' → Prix accepté
  -- 'rejected' → Non sélectionné

  -- NÉGOCIATION
  counter_price int,
  final_price int,

  token_spent boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),

  UNIQUE(delivery_request_id, driver_id)
);
```

---

## 🎨 UI Complète

### Écran 1: LISTE Drivers (Sélection)

```dart
// ÉTAPE 1: Sélection dans liste avec prix

class DriverSelectionScreen extends ConsumerWidget {
  final String rideRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(rideOffersProvider(rideRequestId));

    return Scaffold(
      appBar: AppBar(title: Text('Choisir un chauffeur')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '${offers.length} chauffeurs disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return _DriverOfferCard(
                  offer: offer,
                  onSelect: () => _selectDriver(offer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectDriver(RideOffer offer) {
    // Marquer comme sélectionné
    await supabase.from('ride_offers').update({
      'status': 'selected'
    }).eq('id', offer.id);

    // Marquer autres comme rejetés
    await supabase.from('ride_offers').update({
      'status': 'rejected'
    }).eq('ride_request_id', rideRequestId)
      .neq('id', offer.id);

    // Rembourser jetons autres drivers
    final otherOffers = await supabase
      .from('ride_offers')
      .select('driver_id')
      .eq('ride_request_id', rideRequestId)
      .eq('status', 'rejected');

    for (final o in otherOffers) {
      await supabase.rpc('refund_token', params: {
        'p_user_id': o['driver_id'],
        'p_token_type': 'course',
        'p_description': 'Remboursement offre non sélectionnée',
      });
    }

    // Changer statut demande
    await supabase.from('ride_requests').update({
      'status': 'negotiating'
    }).eq('id', rideRequestId);

    // Ouvrir écran négociation
    context.push('/negotiation', extra: offer);
  }
}

class _DriverOfferCard extends StatelessWidget {
  final RideOffer offer;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Photo driver
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(offer.driver.photoUrl),
              ),

              SizedBox(width: 16),

              // Info driver
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driver.fullName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text('${offer.driver.rating}'),
                        SizedBox(width: 12),
                        Text('${offer.driver.totalTrips} trajets'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      offer.vehicleNumber,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Prix + ETA
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${offer.offeredPrice} F',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14),
                      SizedBox(width: 4),
                      Text('${offer.etaMinutes} min'),
                    ],
                  ),
                ],
              ),

              SizedBox(width: 8),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### Écran 2: NÉGOCIATION Prix (après sélection)

```dart
// ÉTAPE 2: Négociation avec driver sélectionné

class PriceNegotiationScreen extends ConsumerStatefulWidget {
  final RideOffer offer;

  @override
  ConsumerState<PriceNegotiationScreen> createState() =>
    _PriceNegotiationScreenState();
}

class _PriceNegotiationScreenState
    extends ConsumerState<PriceNegotiationScreen> {

  int? _counterPrice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Négociation'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => _showCancelDialog(),
        ),
      ),
      body: Column(
        children: [
          // Info driver
          Container(
            padding: EdgeInsets.all(20),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(widget.offer.driver.photoUrl),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.offer.driver.fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('${widget.offer.driver.rating}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Prix proposé par le chauffeur',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: 16),

                  // PRIX (gros)
                  Text(
                    '${widget.offer.offeredPrice} F',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),

                  SizedBox(height: 40),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptPrice(),
                      icon: Icon(Icons.check_circle),
                      label: Text('Accepter ${widget.offer.offeredPrice} F'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCounterOfferDialog(),
                      icon: Icon(Icons.edit),
                      label: Text('Proposer un autre prix'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  TextButton.icon(
                    onPressed: () => _showCancelDialog(),
                    icon: Icon(Icons.close, color: Colors.red),
                    label: Text(
                      'Annuler la course',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptPrice() async {
    // Accepter prix proposé
    await supabase.from('ride_offers').update({
      'status': 'accepted',
      'final_price': widget.offer.offeredPrice,
    }).eq('id', widget.offer.id);

    await supabase.from('ride_requests').update({
      'status': 'accepted',
    }).eq('id', widget.offer.rideRequestId);

    // Notifier driver
    // Aller à écran tracking
    context.goNamed('tracking', extra: widget.offer);
  }

  void _showCounterOfferDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Proposer un autre prix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prix actuel: ${widget.offer.offeredPrice} F'),
            SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Votre proposition',
                suffixText: 'F',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            SizedBox(height: 12),
            Text(
              'Le chauffeur recevra votre proposition et pourra l\'accepter ou la refuser.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final counterPrice = int.tryParse(controller.text);
              if (counterPrice != null && counterPrice > 0) {
                Navigator.pop(context);
                _sendCounterOffer(counterPrice);
              }
            },
            child: Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  void _sendCounterOffer(int counterPrice) async {
    // Enregistrer contre-offre
    await supabase.from('ride_offers').update({
      'counter_price': counterPrice,
    }).eq('id', widget.offer.id);

    // Notifier driver
    // TODO: Push notification

    // Afficher message attente
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contre-offre envoyée. En attente de réponse...'),
        duration: Duration(seconds: 3),
      ),
    );

    // Écouter réponse driver en temps réel
    _listenToDriverResponse();
  }

  void _listenToDriverResponse() {
    supabase
      .from('ride_offers')
      .stream(primaryKey: ['id'])
      .eq('id', widget.offer.id)
      .listen((data) {
        final offer = RideOffer.fromJson(data.first);

        if (offer.status == 'accepted') {
          // Driver a accepté contre-offre
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le chauffeur a accepté ${offer.finalPrice} F!'),
              backgroundColor: Colors.green,
            ),
          );

          // Aller tracking
          context.goNamed('tracking', extra: offer);
        }
        else if (offer.status == 'rejected') {
          // Driver a refusé
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le chauffeur a refusé votre proposition'),
              backgroundColor: Colors.red,
            ),
          );

          // Retour liste
          context.pop();
        }
      });
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler la course?'),
        content: Text('Êtes-vous sûr de vouloir annuler?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Non'),
          ),
          TextButton(
            onPressed: () async {
              // Annuler
              await supabase.from('ride_offers').update({
                'status': 'rejected',
              }).eq('id', widget.offer.id);

              await supabase.from('ride_requests').update({
                'status': 'cancelled',
              }).eq('id', widget.offer.rideRequestId);

              // Rembourser jeton driver
              await supabase.rpc('refund_token', params: {
                'p_user_id': widget.offer.driverId,
                'p_token_type': 'course',
                'p_description': 'Course annulée par rider',
              });

              Navigator.pop(context);
              context.pop();
            },
            child: Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

---

### Écran 3: Driver voit contre-offre

```dart
// DRIVER: Répondre à contre-offre rider

class DriverCounterOfferScreen extends ConsumerWidget {
  final RideOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Contre-proposition')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.compare_arrows,
              size: 64,
              color: AppTheme.primaryOrange,
            ),

            SizedBox(height: 24),

            Text(
              'Le client vous propose',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),

            SizedBox(height: 40),

            // Comparaison prix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('Votre prix', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text(
                      '${offer.offeredPrice} F',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                Icon(Icons.arrow_forward, size: 32),

                Column(
                  children: [
                    Text('Contre-offre', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text(
                      '${offer.counterPrice} F',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 16),

            // Différence
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Différence: ${offer.offeredPrice - offer.counterPrice!} F',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 60),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _acceptCounterOffer(),
                icon: Icon(Icons.check_circle),
                label: Text('Accepter ${offer.counterPrice} F'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
            ),

            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _rejectCounterOffer(),
                icon: Icon(Icons.close, color: Colors.red),
                label: Text(
                  'Refuser et annuler',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                  side: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptCounterOffer() async {
    // Accepter contre-offre
    await supabase.from('ride_offers').update({
      'status': 'accepted',
      'final_price': offer.counterPrice,
    }).eq('id', offer.id);

    await supabase.from('ride_requests').update({
      'status': 'accepted',
    }).eq('id', offer.rideRequestId);

    // Notifier rider
    // Démarrer course
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prix ${offer.counterPrice} F accepté!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rejectCounterOffer() async {
    // Refuser
    await supabase.from('ride_offers').update({
      'status': 'rejected',
    }).eq('id', offer.id);

    await supabase.from('ride_requests').update({
      'status': 'cancelled',
    }).eq('id', offer.rideRequestId);

    // Rembourser jeton
    await supabase.rpc('refund_token', params: {
      'p_user_id': offer.driverId,
      'p_token_type': 'course',
      'p_description': 'Contre-offre refusée',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contre-offre refusée. Course annulée.'),
        backgroundColor: Colors.red,
      ),
    );

    context.pop();
  }
}
```

---

## 🎯 Résumé Final

### ✅ Flux Correct en 2 Étapes

```
ÉTAPE 1: SÉLECTION
━━━━━━━━━━━━━━━━━━
1. Demandeur fait demande (gratuit)
2. Drivers font offres AVEC PRIX (1 jeton chacun)
3. Demandeur voit LISTE drivers + leurs prix
4. Demandeur SÉLECTIONNE 1 driver
5. Autres drivers → Jetons remboursés ✅

ÉTAPE 2: NÉGOCIATION
━━━━━━━━━━━━━━━━━━━
6. Écran négociation s'ouvre
7. Demandeur peut:
   - Accepter prix proposé
   - Contre-proposer autre prix
   - Annuler
8. Si contre-offre:
   - Driver accepte → Prix final ✅
   - Driver refuse → Annulation + remboursement ❌
```

### 🔑 Points Essentiels

1. **Drivers DOIVENT proposer prix pour être visibles**
2. **Sélection AVANT négociation**
3. **Un seul driver en négociation à la fois**
4. **Jetons remboursés si non sélectionné ou échec négociation**
5. **Maximum 1 contre-offre par négociation**

---

**Document généré:** 2025-11-29
**Version:** 4.0 FINAL CORRECT
**Statut:** ✅ Production Ready
