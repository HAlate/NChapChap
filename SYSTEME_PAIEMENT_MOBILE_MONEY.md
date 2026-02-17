# 💰 Système de Paiement Mobile Money Multi-Pays

**Date**: 2025-11-30
**Statut**: ✅ Implémenté

---

## 🎯 Vue d'Ensemble

Système d'achat de jetons via Mobile Money pour:
- **Drivers**: Acheter jetons pour faire des offres de courses
- **Restaurants**: Acheter jetons pour recevoir commandes
- **Marchands**: Acheter jetons pour recevoir commandes

**Support multi-pays**: Togo, Bénin, Burkina Faso, Côte d'Ivoire, Sénégal, Mali, Niger, Ghana, Nigeria, Cameroun

---

## 📊 Architecture Base de Données

### Tables Principales

```
1. mobile_money_providers
   - Opérateurs (MTN, Moov, Orange, Wave, etc.)
   
2. mobile_money_accounts
   - Numéros Mobile Money admin par pays/opérateur
   
3. token_packages
   - Packs de jetons à vendre
   
4. token_purchases
   - Historique achats utilisateurs
   
5. payment_transactions
   - Transactions de paiement détaillées
```

---

## 🔄 Workflow Complet

### Étape 1: Utilisateur Initie Achat

```dart
// User sélectionne pack de jetons
final package = await supabase
  .from('token_packages')
  .select()
  .eq('token_type', userTokenType)  // course, delivery_food, delivery_product
  .eq('is_active', true)
  .order('display_order');
```

### Étape 2: Afficher Numéros Mobile Money

```dart
// Récupérer numéros Mobile Money du pays de l'user
final momoAccounts = await supabase
  .from('mobile_money_accounts')
  .select('''
    *,
    provider:mobile_money_providers(name, logo_url, ussd_code)
  ''')
  .eq('country_code', userCountryCode)  // ex: 'TG' pour Togo
  .eq('is_active', true)
  .order('priority');

// Afficher à l'user:
// MTN Mobile Money: +228 90 12 34 56
// Moov Money: +228 96 78 90 12
// etc.
```

### Étape 3: User Effectue Paiement

```
User ouvre son app Mobile Money:
1. Choisit "Envoyer de l'argent"
2. Entre numéro affiché
3. Entre montant exact
4. Valide avec PIN
5. Reçoit SMS confirmation avec ID transaction
```

### Étape 4: User Soumet Preuve de Paiement

```dart
// Créer purchase
final purchase = await supabase.from('token_purchases').insert({
  'user_id': userId,
  'package_id': packageId,
  'token_type': tokenType,
  'token_amount': tokenAmount,
  'price_paid': price,
  'currency_code': 'XOF',
  'payment_method': 'mobile_money',
  'payment_status': 'pending',
}).select().single();

// Créer transaction avec preuve
final transactionRef = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
await supabase.from('payment_transactions').insert({
  'purchase_id': purchase['id'],
  'user_id': userId,
  'amount': price,
  'currency_code': 'XOF',
  'payment_method': 'mobile_money',
  'momo_account_id': selectedMomoAccountId,
  'sender_phone': userPhone,
  'sender_name': userName,
  'transaction_ref': transactionRef,
  'external_transaction_id': externalTxId,  // ID du SMS
  'status': 'pending',
});

// Notification user
showDialog('Paiement en attente de confirmation');
```

### Étape 5: Admin Vérifie et Confirme

```sql
-- Admin vérifie dans son app Mobile Money
-- Si paiement reçu, confirme:

SELECT confirm_payment_and_credit_tokens(
  'TXN-20251130123456-ABC123',
  'MP251130.1234.A12345'  -- ID transaction Mobile Money
);

-- Résultat:
{
  "success": true,
  "user_id": "uuid",
  "token_type": "course",
  "tokens_credited": 25,
  "new_balance": 35,
  "transaction_ref": "TXN-20251130123456-ABC123"
}
```

### Étape 6: User Reçoit Jetons

```
Automatiquement:
1. payment_transactions.status → 'completed'
2. token_purchases.payment_status → 'completed'
3. token_balances.balance += token_amount
4. token_transactions enregistrée
5. Notification push à l'user
6. User peut utiliser ses jetons
```

---

## 💳 Opérateurs Mobile Money Supportés

### Afrique de l'Ouest (Zone Franc CFA)

| Opérateur | Code | Pays | USSD |
|-----------|------|------|------|
| **MTN Mobile Money** | mtn_momo | TG, BJ, BF, CI, GH | *170# |
| **Moov Money** | moov_money | TG, BJ, BF, CI | *155# |
| **Orange Money** | orange_money | TG, BF, CI, SN, ML, NE | #144# |
| **Wave** | wave | TG, SN, CI | - |
| **Flooz** | flooz | TG, BJ | *155# |
| **T-Money** | t_money | TG | *202# |

### Autres Pays

| Opérateur | Code | Pays |
|-----------|------|------|
| **Airtel Money** | airtel_money | GH, NG |
| **Vodafone Cash** | vodafone_cash | GH |

---

## 📦 Packs de Jetons Disponibles

### Drivers (token_type = 'course')

| Pack | Jetons | Prix XOF | Remise | Courses |
|------|--------|----------|--------|---------|
| Starter | 5 | 500 F | 0% | 5 |
| Standard | 10 | 900 F | 10% | 10 |
| **Pro** ⭐ | 25 | 2000 F | 20% | 25 |
| Business | 50 | 3500 F | 30% | 50 |
| Premium | 100 | 6000 F | 40% | 100 |

### Restaurants (token_type = 'delivery_food')

| Pack | Jetons | Prix XOF | Remise | Commandes |
|------|--------|----------|--------|-----------|
| Découverte | 5 | 500 F | 0% | 1 |
| Standard | 25 | 2250 F | 10% | 5 |
| **Pro** ⭐ | 50 | 4000 F | 20% | 10 |
| Business | 100 | 7000 F | 30% | 20 |
| Premium | 250 | 15000 F | 40% | 50 |

### Marchands (token_type = 'delivery_product')

| Pack | Jetons | Prix XOF | Remise | Commandes |
|------|--------|----------|--------|-----------|
| Starter | 5 | 500 F | 0% | 1 |
| Standard | 25 | 2250 F | 10% | 5 |
| **Pro** ⭐ | 50 | 4000 F | 20% | 10 |
| Business | 100 | 7000 F | 30% | 20 |
| Premium | 250 | 15000 F | 40% | 50 |

---

## 🔐 Gestion Admin

### Ajouter Numéro Mobile Money

```sql
-- Exemple: Ajouter compte MTN Togo
INSERT INTO mobile_money_accounts (
  country_id, 
  country_code,
  provider_id,
  account_name,
  account_holder,
  phone_number,
  is_active,
  is_primary
) VALUES (
  (SELECT id FROM countries WHERE code = 'TG'),
  'TG',
  (SELECT id FROM mobile_money_providers WHERE short_name = 'MTN MoMo'),
  'Compte Principal MTN',
  'URBAN MOBILITY',
  '+22890123456',
  true,
  true
);
```

### Activer/Désactiver Compte

```sql
-- Désactiver temporairement
UPDATE mobile_money_accounts
SET is_active = false
WHERE phone_number = '+22890123456';

-- Réactiver
UPDATE mobile_money_accounts
SET is_active = true
WHERE phone_number = '+22890123456';
```

### Voir Transactions en Attente

```sql
SELECT 
  pt.transaction_ref,
  pt.created_at,
  u.full_name,
  pt.sender_phone,
  pt.amount,
  pt.currency_code,
  mma.phone_number as destination,
  mmp.name as provider
FROM payment_transactions pt
JOIN users u ON u.id = pt.user_id
LEFT JOIN mobile_money_accounts mma ON mma.id = pt.momo_account_id
LEFT JOIN mobile_money_providers mmp ON mmp.id = mma.provider_id
WHERE pt.status = 'pending'
ORDER BY pt.created_at DESC;
```

### Confirmer Paiement

```sql
-- Méthode 1: Via fonction
SELECT confirm_payment_and_credit_tokens(
  'TXN-20251130123456-ABC123',
  'MP251130.1234.A12345'
);

-- Méthode 2: Manuel (déconseillé)
-- Mieux vaut utiliser la fonction qui gère tout automatiquement
```

---

## 📱 Interface Utilisateur

### Écran Achat de Jetons

```dart
class BuyTokensScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Acheter des jetons')),
      body: Column(
        children: [
          // 1. Solde actuel
          TokenBalanceCard(),
          
          // 2. Packs disponibles
          PackagesGrid(),
          
          // 3. Workflow paiement
          PaymentInstructionsCard(),
        ],
      ),
    );
  }
}

class PackagesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TokenPackage>>(
      future: supabase
        .from('token_packages')
        .select()
        .eq('token_type', userTokenType)
        .eq('is_active', true)
        .order('display_order'),
      builder: (context, snapshot) {
        return GridView.builder(
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            return TokenPackageCard(
              name: package['name'],
              amount: package['token_amount'],
              price: package['price_fcfa'],
              discount: package['discount_percent'],
              isPopular: package['is_popular'],
              onTap: () => showPaymentDialog(package),
            );
          },
        );
      },
    );
  }
}
```

### Dialog Paiement

```dart
void showPaymentDialog(Map package) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Paiement Mobile Money'),
      content: Column(
        children: [
          Text('Montant: ${package['price_fcfa']} FCFA'),
          SizedBox(height: 16),
          Text('Envoyez à l\'un de ces numéros:'),
          ...momoAccounts.map((account) => ListTile(
            leading: Image.network(account.provider.logo_url),
            title: Text(account.provider.name),
            subtitle: Text(account.phone_number),
            trailing: IconButton(
              icon: Icon(Icons.copy),
              onPressed: () => copyToClipboard(account.phone_number),
            ),
          )),
          SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Votre numéro Mobile Money',
              hintText: '+228...',
            ),
          ),
          TextField(
            decoration: InputDecoration(
              labelText: 'ID Transaction (du SMS)',
              hintText: 'MP251130.1234.A12345',
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
          onPressed: () => submitPayment(),
          child: Text('Confirmer'),
        ),
      ],
    ),
  );
}
```

---

## ✅ Résumé

**Tables**: 5 principales (providers, accounts, packages, purchases, transactions)
**Fonction**: confirm_payment_and_credit_tokens() automatise tout
**Support**: 10 pays, 8 opérateurs Mobile Money
**Packs**: 15 packs (5 par type: drivers, restaurants, marchands)
**RLS**: Utilisateurs voient uniquement leurs données
**Admin**: Gère numéros par pays, confirme paiements

**Système complet et prêt pour production!** 🚀
