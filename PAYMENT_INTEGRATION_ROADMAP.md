# Roadmap - Intégration des Paiements UUMO

## 🌍 Contexte

UUMO est une plateforme de mobilité urbaine destinée aux **marchés internationaux** (hors Afrique), ciblant des régions avec une infrastructure de paiement numérique mature.

## 💳 Solutions de Paiement Prévues

### Phase 1: Paiements par Carte (Prioritaire)

#### Stripe

- ✅ **Recommandé** - Leader mondial
- 🌐 Couverture: 46+ pays
- 💰 Frais: ~2.9% + 0.30F par transaction
- 🔧 Intégration: Stripe Payment Intents API
- 📱 Mobile: Stripe SDK (Flutter)

#### PayPal

- 🌐 Alternative populaire
- 💰 Frais: ~3.4% + 0.35F
- 👥 Grand public familiarisé

### Phase 2: Portefeuilles Numériques

#### Apple Pay

- 🍎 iOS natif
- ✅ Expérience fluide
- 🔐 Très sécurisé (Touch ID/Face ID)

#### Google Pay

- 🤖 Android natif
- ✅ Intégré à l'écosystème Google
- 🌐 Large adoption

### Phase 3: Méthodes Alternatives

#### SEPA (F CFApe)

- 🏦 Virements bancaires
- 💰 Frais réduits
- ⏱️ Traitement différé

#### PayPal Pay Later

- 📅 Paiement différé
- 🎯 Marché cible: Millennials/Gen Z

## 📋 Tables Supabase Requises

```sql
-- Table pour stocker les méthodes de paiement des utilisateurs
CREATE TABLE payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) NOT NULL,

  provider text NOT NULL, -- 'stripe', 'paypal', 'apple_pay', 'google_pay'
  provider_payment_method_id text NOT NULL, -- ID chez le provider

  type text NOT NULL, -- 'card', 'wallet', 'bank_account'
  card_brand text, -- 'visa', 'mastercard', 'amex'
  last4 text, -- Derniers 4 chiffres

  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,

  expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table pour les transactions
CREATE TABLE payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id uuid REFERENCES users(id) NOT NULL,
  trip_id uuid REFERENCES trips(id),
  order_id uuid REFERENCES orders(id),

  payment_method_id uuid REFERENCES payment_methods(id),

  provider text NOT NULL,
  provider_transaction_id text UNIQUE NOT NULL,
  provider_payment_intent_id text,

  amount_cents int NOT NULL CHECK (amount_cents > 0),
  currency text DEFAULT 'F CFA' NOT NULL,

  status text NOT NULL, -- 'pending', 'processing', 'succeeded', 'failed', 'refunded'

  metadata jsonb,

  succeeded_at timestamptz,
  failed_at timestamptz,
  refunded_at timestamptz,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX idx_payment_methods_user ON payment_methods(user_id);
CREATE INDEX idx_payment_transactions_user ON payment_transactions(user_id);
CREATE INDEX idx_payment_transactions_trip ON payment_transactions(trip_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
```

## 🔧 Architecture d'Intégration

### Backend (Node.js/TypeScript)

```typescript
// services/payment/stripe.service.ts
export class StripePaymentService {
  async createPaymentIntent(amount: number, currency: string, userId: string) {
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      metadata: { userId },
    });
    return paymentIntent;
  }

  async confirmPayment(paymentIntentId: string) {
    return await stripe.paymentIntents.confirm(paymentIntentId);
  }
}
```

### Mobile (Flutter)

```dart
// lib/services/payment_service.dart
class PaymentService {
  final Stripe _stripe = Stripe.instance;

  Future<PaymentIntent> createPaymentIntent(int amount) async {
    // Appel API backend pour créer PaymentIntent
    final response = await supabase.functions.invoke('create-payment-intent',
      body: {'amount': amount, 'currency': 'F CFA'}
    );
    return PaymentIntent.fromJson(response.data);
  }

  Future<void> presentPaymentSheet() async {
    await _stripe.presentPaymentSheet();
  }
}
```

## 🔐 Sécurité

### PCI DSS Compliance

- ✅ Ne jamais stocker les données de carte en clair
- ✅ Utiliser les SDK officiels (Stripe, PayPal)
- ✅ Tokens/Payment Intents uniquement
- ✅ HTTPS obligatoire

### Gestion des Webhooks

```typescript
// Backend webhook endpoint
app.post("/webhooks/stripe", async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);

  switch (event.type) {
    case "payment_intent.succeeded":
      await handlePaymentSuccess(event.data.object);
      break;
    case "payment_intent.payment_failed":
      await handlePaymentFailure(event.data.object);
      break;
  }

  res.json({ received: true });
});
```

## 📊 Tableau de Comparaison

| Provider   | Frais Moyens | Couverture | Délai Intégration | Recommandation |
| ---------- | ------------ | ---------- | ----------------- | -------------- |
| Stripe     | 2.9% + 0.30F | 46+ pays   | 1-2 semaines      | ⭐⭐⭐⭐⭐     |
| PayPal     | 3.4% + 0.35F | 200+ pays  | 1 semaine         | ⭐⭐⭐⭐       |
| Apple Pay  | Via Stripe   | iOS only   | + 2 jours         | ⭐⭐⭐⭐⭐     |
| Google Pay | Via Stripe   | Android    | + 2 jours         | ⭐⭐⭐⭐⭐     |

## 🎯 Implémentation Recommandée

### Étape 1: Stripe Core (Semaines 1-2)

- Setup compte Stripe
- Intégration backend (Payment Intents API)
- SDK Flutter mobile
- Tests en mode sandbox

### Étape 2: Apple Pay & Google Pay (Semaine 3)

- Configuration via Stripe
- Tests sur devices réels

### Étape 3: PayPal (Semaine 4)

- Intégration alternative
- UI pour choix méthode

### Étape 4: Production (Semaine 5)

- KYC/Vérification compte Stripe
- Tests de charge
- Monitoring
- Déploiement graduel

## 📝 Checklist Avant Intégration

- [ ] Compte Stripe créé et vérifié
- [ ] Clés API (test + prod) sécurisées
- [ ] Backend endpoint créé pour Payment Intents
- [ ] Webhooks configurés
- [ ] Tables payment_methods & payment_transactions créées
- [ ] SDK Stripe ajouté aux apps mobile
- [ ] Politiques RLS configurées
- [ ] Tests unitaires écrits
- [ ] Documentation utilisateur

## 💡 Bonnes Pratiques

1. **Toujours tester en mode Sandbox** avant production
2. **Implémenter la gestion des échecs** (retry, fallback)
3. **Monitorer les transactions** (Sentry, Datadog)
4. **Respecter RGPD** pour données utilisateurs fcfapéens
5. **Avoir un plan de support** pour litiges/remboursements

## 📚 Ressources

- [Stripe Docs](https://stripe.com/docs)
- [Flutter Stripe Plugin](https://pub.dev/packages/flutter_stripe)
- [PayPal Developer](https://developer.paypal.com)
- [Apple Pay Guidelines](https://developer.apple.com/apple-pay/)
- [Google Pay Integration](https://developers.google.com/pay)

---

**Status:** 🚧 En planification  
**Priorité:** 🔥 Haute  
**Timeline:** Q1 2026  
**Owner:** Équipe Backend + Mobile
