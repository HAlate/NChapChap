# 🪙 Système d'Achat de Jetons par Mobile Money

## 📋 Vue d'ensemble

Le système d'achat de jetons permet aux chauffeurs d'acheter des jetons via Mobile Money pour accéder aux fonctionnalités premium de l'application (faire des offres, négocier, être prioritaire dans les listes, etc.).

### Caractéristiques principales

- ✅ Paiement par **Mobile Money** (adapté au contexte africain)
- 🌍 Configuration **multi-pays** sans modification de code
- 📦 Packages de jetons avec **bonus progressifs**
- ✅ Validation manuelle par **administrateur**
- 📊 Historique complet des transactions
- 🔄 Mise à jour en temps réel du solde

---

## 🏗️ Architecture

### Base de données

Le système utilise 5 tables principales dans Supabase :

#### 1. `token_packages`
Définit les packs de jetons disponibles à l'achat.

```sql
- id (UUID)
- name (VARCHAR) - Ex: "Pack Starter"
- description (TEXT)
- token_amount (INTEGER) - Nombre de jetons de base
- price_fcfa (INTEGER) - Prix en F CFA
- bonus_tokens (INTEGER) - Jetons bonus offerts
- is_active (BOOLEAN)
- display_order (INTEGER)
```

**Exemple de données :**
| Pack | Jetons | Prix | Bonus | Total |
|------|--------|------|-------|-------|
| Starter | 10 | 1000 F | 0 | 10 |
| Standard | 25 | 2000 F | 5 | 30 |
| Pro | 50 | 3500 F | 20 | 70 |
| Premium | 100 | 6000 F | 60 | 160 |

#### 2. `mobile_money_numbers`
Stocke les numéros de réception Mobile Money par pays.

```sql
- id (UUID)
- country_code (VARCHAR) - Ex: "BJ", "TG", "CI"
- country_name (VARCHAR) - Ex: "Bénin"
- provider (VARCHAR) - Ex: "MTN Mobile Money", "Moov Money"
- phone_number (VARCHAR) - Ex: "+229 XX XX XX XX"
- account_name (VARCHAR) - Ex: "ZEDGO SERVICES"
- is_active (BOOLEAN)
- instructions (TEXT) - Instructions spécifiques
- display_order (INTEGER)
```

**Exemple de configuration :**
```sql
-- Bénin
INSERT INTO mobile_money_numbers VALUES
  ('BJ', 'Bénin', 'MTN Mobile Money', '+229 XX XX XX XX', 'ZEDGO SERVICES'),
  ('BJ', 'Bénin', 'Moov Money', '+229 YY YY YY YY', 'ZEDGO SERVICES');

-- Togo
INSERT INTO mobile_money_numbers VALUES
  ('TG', 'Togo', 'Flooz (Moov)', '+228 XX XX XX XX', 'ZEDGO SERVICES'),
  ('TG', 'Togo', 'TMoney', '+228 YY YY YY YY', 'ZEDGO SERVICES');
```

#### 3. `token_purchases`
Enregistre tous les achats de jetons.

```sql
- id (UUID)
- driver_id (UUID) - Référence au chauffeur
- package_id (UUID) - Pack acheté
- mobile_money_number_id (UUID) - Numéro utilisé
- token_amount (INTEGER)
- bonus_tokens (INTEGER)
- total_tokens (INTEGER)
- price_paid (INTEGER)
- sender_phone (VARCHAR) - Numéro du chauffeur
- transaction_reference (VARCHAR) - Réf. Mobile Money
- status (VARCHAR) - 'pending', 'validated', 'rejected', 'expired'
- validated_by (UUID) - Admin qui a validé
- validated_at (TIMESTAMP)
- rejection_reason (TEXT)
- created_at (TIMESTAMP)
```

#### 4. `driver_token_balance`
Solde de jetons de chaque chauffeur.

```sql
- driver_id (UUID)
- total_tokens (INTEGER) - Total accumulé
- tokens_used (INTEGER) - Jetons utilisés
- tokens_available (INTEGER) - Jetons disponibles
- last_purchase_at (TIMESTAMP)
```

#### 5. `token_usage_history`
Historique d'utilisation des jetons.

```sql
- id (UUID)
- driver_id (UUID)
- tokens_used (INTEGER)
- usage_type (VARCHAR) - 'trip_offer', 'negotiation', etc.
- reference_id (UUID) - ID de la course, négociation, etc.
- description (TEXT)
- created_at (TIMESTAMP)
```

### Fonctions PostgreSQL

#### `use_driver_tokens()`
Utilise des jetons et enregistre l'historique.

```sql
SELECT use_driver_tokens(
  p_driver_id := '<driver_uuid>',
  p_tokens_to_use := 2,
  p_usage_type := 'trip_offer',
  p_reference_id := '<trip_uuid>',
  p_description := 'Offre pour course Cotonou-Porto-Novo'
);
-- Retourne TRUE si succès, FALSE si solde insuffisant
```

#### `get_driver_token_balance()`
Récupère le solde d'un chauffeur.

```sql
SELECT * FROM get_driver_token_balance('<driver_uuid>');
-- Retourne: total_tokens, tokens_used, tokens_available, last_purchase_at
```

### Trigger automatique

Un trigger met automatiquement à jour le solde quand un achat est validé :

```sql
-- Quand token_purchases.status passe à 'validated'
-- → Ajoute automatiquement les jetons à driver_token_balance
```

---

## 📱 Interface utilisateur

### Widget d'achat : `BuyTokensWidget`

À intégrer dans l'onglet "Compte" de `mobile_driver`.

**Fonctionnalités :**
1. Affichage du solde actuel
2. Sélection d'un package
3. Choix du pays
4. Choix du moyen de paiement (Mobile Money)
5. Instructions de paiement claires
6. Formulaire de confirmation

**Intégration dans l'écran de compte :**

```dart
import '../../../widgets/buy_tokens_widget.dart';

// Dans l'onglet "Compte"
class AccountScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // ... autres widgets ...
        
        const BuyTokensWidget(), // Widget d'achat de jetons
        
        // ... autres widgets ...
      ],
    );
  }
}
```

### Écran d'historique : `TokenPurchaseHistoryScreen`

Affiche tous les achats avec leur statut.

**Accès depuis le widget d'achat :**
```dart
// Ajouter un bouton "Voir l'historique" dans BuyTokensWidget
TextButton.icon(
  icon: const Icon(Icons.history),
  label: const Text('Historique des achats'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TokenPurchaseHistoryScreen(),
      ),
    );
  },
)
```

---

## 🔄 Flux de paiement

### Côté chauffeur (Mobile Driver)

```mermaid
graph TD
    A[Chauffeur ouvre l'app] --> B[Onglet Compte]
    B --> C[Widget "Acheter des jetons"]
    C --> D[Sélectionne un pack]
    D --> E[Choisit le pays]
    E --> F[Choisit le moyen de paiement]
    F --> G[Voit les instructions]
    G --> H[Effectue le paiement Mobile Money]
    H --> I[Remplit le formulaire]
    I --> J[Soumet la demande]
    J --> K[Status: PENDING]
    K --> L{Admin valide?}
    L -->|OUI| M[Status: VALIDATED]
    L -->|NON| N[Status: REJECTED]
    M --> O[Jetons crédités automatiquement]
    N --> P[Notification avec motif]
```

### Étapes détaillées

1. **Sélection du pack**
   - Le chauffeur voit tous les packs avec prix et bonus
   - Indication claire du nombre total de jetons

2. **Choix du pays**
   - Liste des pays où le service est disponible
   - Détection automatique possible (à implémenter)

3. **Choix du moyen de paiement**
   - Affichage des numéros Mobile Money actifs pour le pays
   - Provider (MTN, Moov, etc.) et numéro clairement affichés

4. **Instructions de paiement**
   - Numéro à contacter
   - Montant exact à envoyer
   - Instructions spécifiques au provider
   - Nom du compte bénéficiaire

5. **Formulaire de confirmation**
   - Numéro du chauffeur (expéditeur) : **REQUIS**
   - Référence de transaction : optionnel
   - Bouton "Confirmer l'achat"

6. **Statut "Pending"**
   - Demande enregistrée en base
   - Chauffeur peut voir le statut dans l'historique
   - Message : "En attente de validation (sous 24h)"

7. **Validation admin**
   - L'admin vérifie le paiement Mobile Money
   - Valide ou rejette avec motif
   - Trigger automatique crédite les jetons si validé

8. **Notification chauffeur**
   - Push notification du changement de statut
   - Solde mis à jour en temps réel

---

## 🔐 Sécurité

### Row Level Security (RLS)

Toutes les tables ont des politiques RLS activées :

```sql
-- Les chauffeurs ne voient que leurs propres achats
CREATE POLICY "Chauffeur voit ses achats" ON token_purchases
  FOR SELECT USING (driver_id = auth.uid());

-- Les chauffeurs peuvent créer des achats
CREATE POLICY "Chauffeur crée ses achats" ON token_purchases
  FOR INSERT WITH CHECK (driver_id = auth.uid());

-- Les chauffeurs peuvent mettre à jour uniquement les achats en pending
CREATE POLICY "Chauffeur met à jour ses achats en pending" ON token_purchases
  FOR UPDATE USING (
    driver_id = auth.uid() AND status = 'pending'
  );
```

### Vérifications côté application

```dart
// Avant d'utiliser des jetons
final hasEnough = await tokenService.hasEnoughTokens(2);
if (!hasEnough) {
  // Rediriger vers l'achat de jetons
  showDialog(...);
  return;
}

// Utiliser les jetons
final success = await tokenService.useTokens(
  tokensToUse: 2,
  usageType: 'trip_offer',
  referenceId: tripId,
);
```

---

## 🌍 Configuration multi-pays

### Ajouter un nouveau pays

**Exemple : Ajouter la Côte d'Ivoire**

```sql
-- 1. Ajouter les numéros Mobile Money
INSERT INTO mobile_money_numbers (
  country_code,
  country_name,
  provider,
  phone_number,
  account_name,
  instructions,
  is_active
) VALUES
  ('CI', 'Côte d''Ivoire', 'Orange Money', '+225 XX XX XX XX', 'ZEDGO SERVICES', 
   'Envoyez le montant exact avec votre ID chauffeur en commentaire', true),
  ('CI', 'Côte d''Ivoire', 'MTN Mobile Money', '+225 YY YY YY YY', 'ZEDGO SERVICES',
   'Envoyez le montant exact avec votre ID chauffeur en commentaire', true),
  ('CI', 'Côte d''Ivoire', 'Moov Money', '+225 ZZ ZZ ZZ ZZ', 'ZEDGO SERVICES',
   'Envoyez le montant exact avec votre ID chauffeur en commentaire', true);

-- 2. C'est tout ! L'app affichera automatiquement le nouveau pays
```

### Activer/Désactiver un pays

```sql
-- Désactiver tous les numéros d'un pays
UPDATE mobile_money_numbers
SET is_active = false
WHERE country_code = 'BJ';

-- Réactiver
UPDATE mobile_money_numbers
SET is_active = true
WHERE country_code = 'BJ';
```

### Activer/Désactiver un numéro spécifique

```sql
-- Désactiver MTN au Bénin
UPDATE mobile_money_numbers
SET is_active = false
WHERE country_code = 'BJ' AND provider = 'MTN Mobile Money';
```

---

## 💰 Gestion des packages

### Créer un nouveau package

```sql
INSERT INTO token_packages (
  name,
  description,
  token_amount,
  price_fcfa,
  bonus_tokens,
  is_active,
  display_order
) VALUES (
  'Pack VIP',
  'Pour les chauffeurs professionnels',
  200,
  10000,
  100, -- 50% bonus
  true,
  5
);
```

### Modifier un package existant

```sql
-- Augmenter le bonus
UPDATE token_packages
SET bonus_tokens = 10
WHERE name = 'Pack Standard';

-- Changer le prix
UPDATE token_packages
SET price_fcfa = 1500
WHERE name = 'Pack Starter';
```

### Désactiver un package

```sql
UPDATE token_packages
SET is_active = false
WHERE name = 'Pack Starter';
```

---

## 📊 Statistiques et monitoring

### Requêtes utiles pour l'admin

**Achats en attente de validation :**
```sql
SELECT 
  p.id,
  p.created_at,
  d.full_name as driver_name,
  p.sender_phone,
  p.price_paid,
  p.total_tokens,
  p.transaction_reference
FROM token_purchases p
JOIN driver_profiles d ON d.id = p.driver_id
WHERE p.status = 'pending'
ORDER BY p.created_at ASC;
```

**Total des revenus par pays :**
```sql
SELECT 
  m.country_name,
  COUNT(p.id) as total_purchases,
  SUM(p.price_paid) as total_revenue
FROM token_purchases p
JOIN mobile_money_numbers m ON m.id = p.mobile_money_number_id
WHERE p.status = 'validated'
GROUP BY m.country_name
ORDER BY total_revenue DESC;
```

**Top 10 des chauffeurs acheteurs :**
```sql
SELECT 
  d.full_name,
  COUNT(p.id) as total_purchases,
  SUM(p.total_tokens) as total_tokens_bought,
  SUM(p.price_paid) as total_spent
FROM token_purchases p
JOIN driver_profiles d ON d.id = p.driver_id
WHERE p.status = 'validated'
GROUP BY d.id, d.full_name
ORDER BY total_spent DESC
LIMIT 10;
```

**Taux de validation :**
```sql
SELECT 
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM token_purchases
GROUP BY status;
```

---

## 🔧 Utilisation des jetons dans l'app

### Exemple : Faire une offre de course

```dart
// Dans driver_requests_screen.dart
Future<void> _makeOffer() async {
  final tokenService = ref.read(tokenServiceProvider);
  
  // Vérifier le solde
  final hasEnough = await tokenService.hasEnoughTokens(1);
  if (!hasEnough) {
    _showBuyTokensDialog();
    return;
  }
  
  // Créer l'offre
  try {
    await tripService.createOffer(...);
    
    // Débiter les jetons
    final success = await tokenService.useTokens(
      tokensToUse: 1,
      usageType: 'trip_offer',
      referenceId: tripId,
      description: 'Offre pour $departure → $destination',
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Offre envoyée ! (1 jeton utilisé)')),
      );
    }
  } catch (e) {
    // Gérer l'erreur
  }
}

void _showBuyTokensDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Jetons insuffisants'),
      content: Text('Vous avez besoin de jetons pour faire une offre. Voulez-vous en acheter ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Rediriger vers l'onglet compte
            context.goNamed('account');
          },
          child: Text('Acheter des jetons'),
        ),
      ],
    ),
  );
}
```

### Configuration des coûts

Dans `TokenService` :

```dart
int calculateTokenCost({
  required String actionType,
  Map<String, dynamic>? parameters,
}) {
  switch (actionType) {
    case 'trip_offer':
      return 1; // 1 jeton par offre
    case 'negotiation':
      return 2; // 2 jetons par négociation
    case 'priority_listing':
      return 5; // 5 jetons pour être prioritaire
    case 'boost_profile':
      return 10; // 10 jetons pour booster le profil
    default:
      return 0;
  }
}
```

---

## 🚀 Déploiement

### 1. Créer les tables

```bash
# Exécuter la migration
psql -h <supabase_host> -U postgres -d postgres -f supabase/migrations/20231214_token_system.sql
```

Ou via l'interface Supabase SQL Editor :
- Ouvrir le SQL Editor
- Copier le contenu de `20231214_token_system.sql`
- Exécuter

### 2. Configurer les numéros Mobile Money

```sql
-- Remplacer les XX XX XX XX par les vrais numéros
UPDATE mobile_money_numbers
SET phone_number = '+229 97 XX XX XX'
WHERE country_code = 'BJ' AND provider = 'MTN Mobile Money';

-- Ajouter des instructions spécifiques
UPDATE mobile_money_numbers
SET instructions = 'Composez *555*6# puis suivez les instructions. Envoyez au nom de ZEDGO SERVICES.'
WHERE provider = 'MTN Mobile Money';
```

### 3. Tester le système

```dart
// 1. Vérifier que les packages s'affichent
final packages = await tokenService.getActivePackages();
print('Packages: ${packages.length}');

// 2. Vérifier les pays disponibles
final countries = await tokenService.getAvailableCountries();
print('Pays: ${countries.map((c) => c['name']).join(', ')}');

// 3. Créer un achat test
final purchase = await tokenService.createPurchase(
  packageId: '<package_uuid>',
  mobileMoneyNumberId: '<number_uuid>',
  senderPhone: '+229 97 XX XX XX',
  transactionReference: 'TEST123',
);
print('Achat créé: ${purchase.id}');

// 4. Vérifier le solde
final balance = await tokenService.getBalance();
print('Solde: ${balance.tokensAvailable} jetons');
```

### 4. Interface admin (à créer)

Créer un dashboard admin pour :
- Voir les achats en attente
- Valider/Rejeter les achats
- Voir les statistiques
- Gérer les packages
- Gérer les numéros Mobile Money

---

## 📞 Support et FAQ

### Comment un chauffeur achète des jetons ?

1. Onglet "Compte" → Widget "Acheter des jetons"
2. Choisir un pack
3. Choisir son pays et le moyen de paiement
4. Envoyer le montant via Mobile Money au numéro affiché
5. Remplir le formulaire avec son numéro
6. Attendre la validation (notification reçue)

### Délai de validation ?

- Objectif : Moins de 2 heures pendant les heures de bureau
- Maximum : 24 heures
- Les achats non validés après 72h peuvent être marqués "expired"

### Que faire si un chauffeur n'a pas reçu ses jetons ?

1. Vérifier le statut dans "Historique des achats"
2. Si "Pending" : Attendre ou contacter le support
3. Si "Rejected" : Lire le motif du rejet
4. Si "Validated" mais jetons non crédités : Bug → vérifier `driver_token_balance`

### Comment rembourser un chauffeur ?

```sql
-- 1. Marquer l'achat comme rejeté
UPDATE token_purchases
SET 
  status = 'rejected',
  rejection_reason = 'Remboursement demandé par le chauffeur',
  admin_notes = 'Remboursement effectué le XX/XX/XXXX via Mobile Money'
WHERE id = '<purchase_uuid>';

-- 2. Effectuer le remboursement Mobile Money manuellement

-- 3. Si les jetons ont déjà été crédités, les déduire
UPDATE driver_token_balance
SET 
  total_tokens = total_tokens - <tokens_to_remove>,
  tokens_available = tokens_available - <tokens_to_remove>
WHERE driver_id = '<driver_uuid>'
  AND tokens_available >= <tokens_to_remove>;
```

### Codes pays supportés

| Code | Pays | Providers suggérés |
|------|------|--------------------|
| BJ | Bénin | MTN, Moov |
| TG | Togo | Flooz, TMoney |
| CI | Côte d'Ivoire | Orange Money, MTN, Moov |
| SN | Sénégal | Orange Money, Wave |
| BF | Burkina Faso | Orange Money, Moov |
| ML | Mali | Orange Money, Moov |
| NE | Niger | Orange Money, Moov |
| GH | Ghana | MTN Mobile Money, Vodafone Cash |
| NG | Nigeria | Opay, PalmPay |

---

## ✅ Checklist de déploiement

- [ ] Migration SQL exécutée
- [ ] Vrais numéros Mobile Money configurés
- [ ] Packages de jetons créés et prix validés
- [ ] RLS activée sur toutes les tables
- [ ] Tests de création d'achat effectués
- [ ] Tests d'utilisation de jetons effectués
- [ ] Widget intégré dans l'onglet Compte
- [ ] Navigation vers l'historique fonctionnelle
- [ ] Notifications push configurées (validation/rejet)
- [ ] Dashboard admin créé
- [ ] Documentation fournie à l'équipe de support
- [ ] Monitoring des transactions configuré

---

## 📝 Notes importantes

1. **Sécurité** : Ne jamais exposer les clés API Mobile Money côté client
2. **Validation** : Toujours vérifier manuellement les paiements avant validation
3. **Fraude** : Surveiller les achats suspects (multiples achats avec différents numéros)
4. **Prix** : Adapter les prix selon le pouvoir d'achat local
5. **Support** : Prévoir un canal de support dédié pour les problèmes de paiement

---

**Auteur** : Système ZEDGO  
**Version** : 1.0  
**Date** : Décembre 2024
