# 🪙 Système de Jetons - Résumé Complet

**Date**: 2025-11-30
**Règle Fondamentale**: ✅ **Drivers, Restaurants & Marchands possèdent des jetons**

---

## 🎯 Principe de Base

### ❌ Les RIDERS n'ont PAS de jetons
- Les riders peuvent créer des demandes **gratuitement**
- Les riders peuvent passer des commandes **gratuitement**
- Les riders peuvent négocier **gratuitement**
- Les riders ne paient RIEN pour utiliser la plateforme
- **Aucune table token_balances pour les riders**

### ✅ Les DRIVERS ont des jetons (1 jeton/course)
- Les drivers DOIVENT avoir au moins **1 jeton** pour voir les demandes de courses
- Les drivers dépensent **1 jeton** UNIQUEMENT quand leur offre est **acceptée**
- Tant que l'offre n'est pas acceptée, le jeton reste intact
- Type de jeton: `course`

### ✅ Les RESTAURANTS ont des jetons (5 jetons/commande)
- Les restaurants DOIVENT avoir au moins **5 jetons** pour voir les commandes
- Les restaurants dépensent **5 jetons** UNIQUEMENT quand ils **acceptent** une commande
- S'ils refusent, les jetons restent intacts
- Type de jeton: `delivery_food`

### ✅ Les MARCHANDS ont des jetons (5 jetons/commande)
- Les marchands DOIVENT avoir au moins **5 jetons** pour voir les commandes
- Les marchands dépensent **5 jetons** UNIQUEMENT quand ils **acceptent** une commande
- S'ils refusent, les jetons restent intacts
- Type de jeton: `delivery_product`

---

## 🔄 Workflow Complet avec Jetons

### Étape 1: Rider Crée une Demande (GRATUIT)
```
Rider:
1. Ouvre l'app mobile_rider
2. Sélectionne véhicule (Zem, Taxi, etc.)
3. Entre destination
4. Clique "Rechercher des chauffeurs"
5. Trip créé dans Supabase

✅ GRATUIT pour le rider
✅ Aucun jeton requis
✅ Aucun paiement
```

### Étape 2: Driver Voit la Demande (SI Jetons > 0)
```
Driver:
1. Ouvre l'app mobile_driver
2. Va dans "Demandes de trajets"

Conditions d'affichage:
IF driver.token_balance >= 1:
  ✅ Demandes affichées
  ✅ Peut faire offre
ELSE:
  ❌ Liste vide
  ❌ Message: "Rechargez vos jetons"
```

**Code Backend (RLS Policy)**:
```sql
CREATE POLICY "Drivers with tokens can read requests"
  ON trips FOR SELECT
  TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = auth.uid()
        AND token_type = 'course'
        AND balance >= 1  -- ← VÉRIFICATION
    )
  );
```

### Étape 3: Driver Fait une Offre (Jeton PAS Dépensé)
```
Driver:
1. Voit une demande: "Lomé → Aéroport"
2. Clique "Faire une offre"
3. Entre prix: 2000 FCFA
4. Entre ETA: 8 minutes
5. Clique "Envoyer"

Backend vérifie:
✅ Driver a >= 1 jeton? → OUI (ex: balance = 5)
✅ Offre créée
❌ Jeton PAS ENCORE dépensé (balance reste à 5)

Table trip_offers:
{
  id: "offer-123",
  trip_id: "trip-456",
  driver_id: "driver-789",
  offered_price: 2000,
  status: 'pending',
  token_spent: false  ← PAS ENCORE
}
```

### Étape 4: Rider Voit les Offres (GRATUIT)
```
Rider:
Écran "WaitingOffersScreen" affiche:

┌────────────────────────────┐
│ Propositions (3)           │
├────────────────────────────┤
│ 👤 Kofi • ⭐ 4.8         │
│ 💰 2000 F • ⏱️ 8 min    │
│ [Sélectionner]             │
├────────────────────────────┤
│ 👤 Ama • ⭐ 4.9          │
│ 💰 1800 F • ⏱️ 5 min    │
│ 🏆 MEILLF CFA PRIX           │
│ [Sélectionner]             │
├────────────────────────────┤
│ 👤 Yao • ⭐ 4.7          │
│ 💰 2200 F • ⏱️ 3 min    │
│ ⚡ PLUS RAPIDE            │
│ [Sélectionner]             │
└────────────────────────────┘

✅ Affichage GRATUIT pour le rider
✅ Peut comparer les offres
✅ Peut négocier avec N'IMPORTE quel driver
```

### Étape 5A: Rider Accepte Directement (JETON DÉPENSÉ)
```
Rider:
1. Clique "Sélectionner" sur Kofi (2000 F)
2. Modal s'ouvre:
   ┌────────────────────────────┐
   │ Confirmer Kofi?            │
   │ 💰 2000 FCFA               │
   │ [✓ Accepter 2000 F]        │
   │ [↔ Contre-proposer]        │
   └────────────────────────────┘
3. Clique "Accepter 2000 F"

Backend (transaction atomique):
1. UPDATE trip_offers
   SET status = 'accepted',
       final_price = 2000,
       token_spent = true
   WHERE id = 'offer-123'

2. ⚠️ TRIGGER AUTOMATIQUE:
   spend_token_on_trip_offer_acceptance()

   → UPDATE token_balances
     SET balance = balance - 1  (5 → 4)
     WHERE user_id = 'driver-789'
     AND token_type = 'course'

3. INSERT INTO token_transactions
   (user_id, token_type, amount, reason)
   VALUES ('driver-789', 'course', -1, 'trip_offer_accepted')

4. UPDATE trips
   SET status = 'accepted'
   WHERE id = 'trip-456'

✅ Kofi: 1 jeton dépensé (balance 5 → 4)
✅ Ama: jeton intact (offre rejetée)
✅ Yao: jeton intact (offre rejetée)
✅ Rider: toujours GRATUIT
```

### Étape 5B: Rider Négocie (Jetons PAS Dépensés)
```
Rider:
1. Clique "Contre-proposer"
2. Navigation vers NegotiationDetailScreen
3. Entre prix: 1800 FCFA
4. Message: "Trop cher pour moi"
5. Clique "Envoyer contre-offre"

Backend:
UPDATE trip_offers
SET status = 'selected',
    counter_price = 1800
WHERE id = 'offer-123'

❌ Jeton PAS dépensé (balance reste à 5)
✅ Notification envoyée à Kofi

Kofi voit:
┌────────────────────────────┐
│ Contre-offre reçue!        │
│ Votre prix:    2000 F      │
│ Contre-offre:  1800 F      │
│ Message: "Trop cher"       │
│ [✓ Accepter 1800 F]        │
│ [✗ Refuser]                │
└────────────────────────────┘

✅ Rider: GRATUIT
✅ Kofi: jeton intact (pas encore accepté)
```

### Étape 6A: Driver Accepte Contre-offre (JETON DÉPENSÉ)
```
Kofi:
Clique "Accepter 1800 F"

Backend (transaction atomique):
1. UPDATE trip_offers
   SET status = 'accepted',
       final_price = 1800,
       token_spent = true

2. ⚠️ TRIGGER: Déduit 1 jeton
   balance: 5 → 4

3. UPDATE trips
   SET status = 'accepted'

✅ Kofi: 1 jeton dépensé (accepté 1800 F)
✅ Rider: GRATUIT (a négocié et obtenu 1800 F)
✅ Course démarre
```

### Étape 6B: Driver Refuse (Jeton INTACT)
```
Kofi:
Clique "Refuser"

Backend:
UPDATE trip_offers
SET status = 'rejected'
WHERE id = 'offer-123'

❌ Jeton PAS dépensé (balance reste à 5)
✅ Kofi peut faire offre sur autre trip
✅ Rider retourne à WaitingOffersScreen
✅ Rider peut sélectionner Ama ou Yao
```

---

## 📊 Tableau Récapitulatif

### Qui Possède des Jetons?

| Utilisateur | Jetons? | Coût/Transaction | Type de Jeton |
|-------------|---------|------------------|---------------|
| **Rider** | ❌ NON | - | - |
| **Driver** | ✅ OUI | **1 jeton** / course | `course` |
| **Restaurant** | ✅ OUI | **5 jetons** / commande | `delivery_food` |
| **Marchand** | ✅ OUI | **5 jetons** / commande | `delivery_product` |

### Quand un Jeton est-il Dépensé?

#### Pour les Drivers (1 jeton)
| Action | Jeton Dépensé? | Détails |
|--------|---------------|---------|
| Driver voit demandes | ❌ NON | Juste vérifié (balance >= 1) |
| Driver fait offre | ❌ NON | Offre gratuite |
| Rider sélectionne driver | ❌ NON | Sélection gratuite |
| Rider envoie contre-offre | ❌ NON | Négociation gratuite |
| **Rider accepte offre** | ✅ OUI | **1 jeton déduit du DRIVER** |
| **Driver accepte contre-offre** | ✅ OUI | **1 jeton déduit du DRIVER** |
| Driver refuse contre-offre | ❌ NON | Jeton intact |
| Rider annule | ❌ NON | Jeton intact |

#### Pour les Restaurants/Marchands (5 jetons)
| Action | Jetons Dépensés? | Détails |
|--------|-----------------|---------|
| Restaurant voit commandes | ❌ NON | Juste vérifié (balance >= 5) |
| Rider passe commande | ❌ NON | Commande gratuite pour rider |
| **Restaurant accepte commande** | ✅ OUI | **5 jetons déduits du RESTAURANT** |
| Restaurant refuse commande | ❌ NON | Jetons intacts |
| Rider annule commande | ❌ NON | Jetons intacts |

---

## 🔐 Implémentation Technique

### Table: token_balances

```sql
CREATE TABLE token_balances (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),  -- UNIQUEMENT drivers/restaurants/marchands
  token_type token_type,               -- 'course', 'livraison', 'commande'
  balance int DEFAULT 0,               -- Nombre de jetons disponibles
  total_purchased int DEFAULT 0,       -- Total acheté
  total_spent int DEFAULT 0,           -- Total dépensé
  updated_at timestamptz DEFAULT now()
);

-- Exemple:
{
  user_id: 'driver-789',
  token_type: 'course',
  balance: 5,           -- 5 jetons disponibles
  total_purchased: 10,  -- A acheté 10 jetons
  total_spent: 5        -- A dépensé 5 jetons (5 courses acceptées)
}
```

**Important**: Il n'y a AUCUNE ligne dans `token_balances` pour les riders!

### Table: trip_offers

```sql
CREATE TABLE trip_offers (
  id uuid PRIMARY KEY,
  trip_id uuid REFERENCES trips(id),
  driver_id uuid REFERENCES users(id),  -- Driver qui fait l'offre

  offered_price int NOT NULL,           -- Prix proposé par driver
  counter_price int,                    -- Contre-offre du rider (optionnel)
  final_price int,                      -- Prix final accepté

  status offer_status,                  -- 'pending', 'selected', 'accepted', 'rejected'
  token_spent boolean DEFAULT false,    -- true UNIQUEMENT si status = 'accepted'

  eta_minutes int,
  created_at timestamptz DEFAULT now()
);
```

### Trigger Automatique

```sql
CREATE TRIGGER trigger_spend_token_on_trip_offer_acceptance
  BEFORE UPDATE ON trip_offers
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_offer_acceptance();

-- Fonction trigger:
CREATE FUNCTION spend_token_on_trip_offer_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- Si status passe à 'accepted'
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN

    -- Vérifier jeton disponible
    IF NOT EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = NEW.driver_id
        AND token_type = 'course'
        AND balance >= 1
    ) THEN
      RAISE EXCEPTION 'Driver has no tokens';
    END IF;

    -- Déduire 1 jeton
    UPDATE token_balances
    SET balance = balance - 1
    WHERE user_id = NEW.driver_id
      AND token_type = 'course';

    -- Marquer comme dépensé
    NEW.token_spent = true;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Avantage**: Déduction automatique, impossible d'oublier!

---

## 💰 Modèle Économique

### Riders (Gratuit)
```
✅ Création de demandes:     GRATUIT
✅ Voir les offres:          GRATUIT
✅ Négociation:              GRATUIT
✅ Annulation:               GRATUIT
✅ Utilisation illimitée:    GRATUIT

💡 Riders paient uniquement le prix de la course au driver
```

### Drivers (Modèle Freemium)
```
💰 Prix des jetons:
  - 1 jeton  = 100 FCFA
  - 5 jetons = 450 FCFA (10% réduction)
  - 10 jetons = 800 FCFA (20% réduction)
  - 50 jetons = 3500 FCFA (30% réduction)

🎯 Utilisation:
  - 1 jeton = 1 course acceptée
  - Offres gratuites (illimitées)
  - Négociations gratuites
  - Refus gratuits

📊 Exemple:
  Driver achète 10 jetons = 800 FCFA
  Fait 15 offres (gratuit)
  10 offres acceptées = -10 jetons
  5 offres refusées = 0 jeton dépensé

  Revenus: 10 courses × 2000 F = 20 000 FCFA
  Coût jetons: 800 FCFA
  Bénéfice: 19 200 FCFA
  ROI: 2400% 🚀
```

---

## 🎨 UI/UX pour Drivers

### Écran: Solde Jetons

```dart
┌────────────────────────────────┐
│ 🪙 Mes Jetons                  │
├────────────────────────────────┤
│                                │
│ Jetons Course                  │
│                       [5] 🟢   │
│                                │
│ ┌────────────────────────────┐ │
│ │ ✅ Vous pouvez faire des   │ │
│ │    offres sur 5 courses    │ │
│ └────────────────────────────┘ │
│                                │
│ 📊 Statistiques:               │
│ • Jetons achetés:      10      │
│ • Jetons dépensés:     5       │
│ • Offres faites:       15      │
│ • Offres acceptées:    5       │
│ • Taux succès:         33%     │
│                                │
│ [🛒 Acheter des jetons]        │
└────────────────────────────────┘
```

### Écran: Liste Demandes (balance = 0)

```dart
┌────────────────────────────────┐
│ 📍 Demandes de trajets         │
├────────────────────────────────┤
│                                │
│          🚫                    │
│                                │
│    Vous n'avez plus de jetons  │
│                                │
│    Rechargez pour voir les     │
│    demandes de trajets         │
│                                │
│ [🛒 Acheter des jetons]        │
│                                │
└────────────────────────────────┘
```

### Écran: Liste Demandes (balance > 0)

```dart
┌────────────────────────────────┐
│ 📍 Demandes (12)   🪙 5        │
├────────────────────────────────┤
│                                │
│ 📍 Lomé → Aéroport            │
│ 🚕 Taxi                       │
│ ⏱️ Il y a 2 min               │
│ [Faire une offre]              │
├────────────────────────────────┤
│ 📍 Tokoin → Zongo             │
│ 🛵 Zem                        │
│ ⏱️ Il y a 5 min               │
│ [Faire une offre]              │
├────────────────────────────────┤
│ 📍 Cacavéli → Hédzranawoé     │
│ 🚐 Taxi Ville                 │
│ ⏱️ Il y a 8 min               │
│ [Faire une offre]              │
└────────────────────────────────┘
```

---

## ✅ Points Clés à Retenir

### 🎯 Règle d'Or
**1 jeton = 1 course acceptée**

### 🆓 Pour les Riders
```
✅ Tout est GRATUIT
✅ Aucun jeton requis
✅ Négociation illimitée
✅ Annulation gratuite
```

### 💰 Pour les Drivers
```
✅ Jeton requis pour voir demandes (balance >= 1)
✅ Offres gratuites (illimitées)
✅ Négociations gratuites
✅ Jeton dépensé UNIQUEMENT si accepté
✅ Refus = jeton intact
```

### 🔐 Sécurité
```
✅ Trigger automatique (impossible d'oublier)
✅ Transaction atomique
✅ Pas de double déduction
✅ RLS policies strictes
```

---

## 🎉 Conclusion

**Le système de jetons est SIMPLE et ÉQUITABLE:**

1. **Riders**: Tout gratuit, expérience sans friction
2. **Drivers**: Paient UNIQUEMENT pour les courses qu'ils obtiennent
3. **Plateforme**: Génère des revenus sur les courses réussies
4. **Backend**: Trigger automatique, zéro bug possible

**Aucun jeton pour les riders = Simplicité maximale!** 🚀

---

**Document créé**: 2025-11-30
**Règle fondamentale**: ✅ Seuls les DRIVERS ont des jetons
**Statut**: 100% Implémenté avec trigger automatique
