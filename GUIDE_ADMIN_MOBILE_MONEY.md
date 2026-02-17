# 👨‍💼 Guide Administrateur - Gestion Mobile Money

**Date**: 2025-11-30

---

## 🎯 Responsabilités Admin

1. **Gérer les numéros Mobile Money** par pays/opérateur
2. **Vérifier les paiements** reçus
3. **Confirmer les transactions** pour créditer jetons
4. **Suivre les statistiques** de ventes

---

## 🔧 Configuration Initiale

### 1. Ajouter Vos Numéros Mobile Money

```sql
-- EXEMPLE: Togo - MTN Mobile Money
INSERT INTO mobile_money_accounts (
  country_id,
  country_code,
  provider_id,
  account_name,
  account_holder,
  phone_number,
  is_active,
  is_primary,
  notes
) VALUES (
  (SELECT id FROM countries WHERE code = 'TG'),
  'TG',
  (SELECT id FROM mobile_money_providers WHERE short_name = 'MTN MoMo'),
  'Compte Principal MTN Togo',
  'URBAN MOBILITY SARL',
  '+22890123456',
  true,
  true,
  'Compte principal pour recevoir paiements jetons'
);

-- EXEMPLE: Togo - Moov Money
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
  (SELECT id FROM mobile_money_providers WHERE short_name = 'Moov'),
  'Compte Moov Togo',
  'URBAN MOBILITY SARL',
  '+22896123456',
  true,
  false
);

-- EXEMPLE: Bénin - MTN Mobile Money
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
  (SELECT id FROM countries WHERE code = 'BJ'),
  'BJ',
  (SELECT id FROM mobile_money_providers WHERE short_name = 'MTN MoMo'),
  'Compte MTN Bénin',
  'URBAN MOBILITY SARL',
  '+22997123456',
  true,
  true
);
```

### 2. Voir Tous Vos Comptes

```sql
SELECT 
  c.name_fr as pays,
  mmp.name as operateur,
  mma.phone_number,
  mma.account_holder,
  mma.is_active,
  mma.is_primary
FROM mobile_money_accounts mma
JOIN countries c ON c.id = mma.country_id
JOIN mobile_money_providers mmp ON mmp.id = mma.provider_id
ORDER BY c.name_fr, mmp.name;
```

---

## 💰 Gestion Quotidienne

### 1. Voir Paiements en Attente

```sql
-- Liste complète
SELECT 
  pt.transaction_ref,
  pt.created_at::date as date,
  u.full_name as client,
  u.phone as contact,
  pt.sender_phone,
  pt.amount,
  pt.currency_code,
  pt.external_transaction_id as id_transaction_momo,
  mma.phone_number as numero_reception,
  mmp.name as operateur,
  tp.package_id,
  tp.token_amount as jetons
FROM payment_transactions pt
JOIN users u ON u.id = pt.user_id
JOIN token_purchases tp ON tp.id = pt.purchase_id
LEFT JOIN mobile_money_accounts mma ON mma.id = pt.momo_account_id
LEFT JOIN mobile_money_providers mmp ON mmp.id = mma.provider_id
WHERE pt.status = 'pending'
ORDER BY pt.created_at DESC;
```

### 2. Vérifier Paiement dans App Mobile Money

```
1. Ouvrez votre app Mobile Money (MTN, Moov, etc.)
2. Allez dans "Historique" ou "Transactions"
3. Cherchez transaction par:
   - Numéro expéditeur
   - Montant
   - Date/heure
4. Notez l'ID transaction (ex: MP251130.1234.A12345)
```

### 3. Confirmer Paiement et Créditer Jetons

```sql
-- MÉTHODE SIMPLE (Recommandée)
SELECT confirm_payment_and_credit_tokens(
  'TXN-20251130123456-ABC123',  -- transaction_ref du système
  'MP251130.1234.A12345'         -- ID transaction Mobile Money
);

-- Résultat:
{
  "success": true,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "token_type": "course",
  "tokens_credited": 25,
  "new_balance": 35,
  "transaction_ref": "TXN-20251130123456-ABC123"
}
```

### 4. En Cas de Problème

#### Paiement Non Reçu
```sql
-- Marquer comme échec
UPDATE payment_transactions
SET 
  status = 'failed',
  notes = 'Paiement non reçu après 24h',
  updated_at = now()
WHERE transaction_ref = 'TXN-20251130123456-ABC123';

UPDATE token_purchases
SET payment_status = 'failed'
WHERE id = (
  SELECT purchase_id FROM payment_transactions 
  WHERE transaction_ref = 'TXN-20251130123456-ABC123'
);
```

#### Montant Incorrect
```sql
-- Marquer comme échec et contacter utilisateur
UPDATE payment_transactions
SET 
  status = 'failed',
  notes = 'Montant incorrect: reçu 1500 au lieu de 2000',
  updated_at = now()
WHERE transaction_ref = 'TXN-20251130123456-ABC123';
```

#### Remboursement
```sql
-- Si besoin de rembourser
UPDATE payment_transactions
SET 
  status = 'refunded',
  notes = 'Remboursé le 2025-11-30 via MTN - ID: MP251130.5678.B98765',
  updated_at = now()
WHERE transaction_ref = 'TXN-20251130123456-ABC123';
```

---

## 📊 Statistiques et Rapports

### Ventes du Jour

```sql
SELECT 
  COUNT(*) as nb_ventes,
  SUM(amount) as total_fcfa,
  SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) as confirme_fcfa,
  SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) as en_attente_fcfa
FROM payment_transactions
WHERE created_at::date = CURRENT_DATE;
```

### Ventes par Opérateur

```sql
SELECT 
  mmp.name as operateur,
  COUNT(*) as nb_transactions,
  SUM(pt.amount) as total_fcfa,
  COUNT(CASE WHEN pt.status = 'completed' THEN 1 END) as completees
FROM payment_transactions pt
LEFT JOIN mobile_money_accounts mma ON mma.id = pt.momo_account_id
LEFT JOIN mobile_money_providers mmp ON mmp.id = mma.provider_id
WHERE pt.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY mmp.name
ORDER BY total_fcfa DESC;
```

### Top Clients

```sql
SELECT 
  u.full_name,
  u.phone,
  COUNT(*) as nb_achats,
  SUM(tp.token_amount) as jetons_achetes,
  SUM(pt.amount) as total_depense_fcfa
FROM payment_transactions pt
JOIN users u ON u.id = pt.user_id
JOIN token_purchases tp ON tp.id = pt.purchase_id
WHERE pt.status = 'completed'
GROUP BY u.id, u.full_name, u.phone
ORDER BY total_depense_fcfa DESC
LIMIT 20;
```

### Packs les Plus Vendus

```sql
SELECT 
  tkp.name as pack,
  tkp.token_type,
  COUNT(*) as nb_ventes,
  SUM(tp.price_paid) as revenu_fcfa
FROM token_purchases tp
JOIN token_packages tkp ON tkp.id = tp.package_id
WHERE tp.payment_status = 'completed'
AND tp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY tkp.id, tkp.name, tkp.token_type
ORDER BY nb_ventes DESC;
```

---

## 🔔 Notifications à Mettre en Place

### Email Admin Nouveau Paiement

```
Objet: Nouveau paiement en attente - 2000 FCFA

Bonjour,

Un utilisateur a initié un achat de jetons:

Client: Jean KOUAME
Téléphone: +22890123456
Montant: 2000 FCFA
Pack: Pack Pro (25 jetons course)
Opérateur: MTN Mobile Money
Vers: +22890999999
ID Transaction: MP251130.1234.A12345
Référence: TXN-20251130123456-ABC123

Vérifiez dans votre app MTN Mobile Money et confirmez le paiement.

[Lien vers admin panel]
```

### SMS/Push User Confirmation

```
✅ Paiement confirmé!

Vos 25 jetons ont été crédités.
Nouveau solde: 35 jetons

Référence: TXN-20251130123456-ABC123

Merci pour votre confiance!
```

---

## ⚙️ Maintenance

### Désactiver Temporairement un Compte

```sql
-- Pendant maintenance ou si compte plein
UPDATE mobile_money_accounts
SET 
  is_active = false,
  notes = 'Désactivé temporairement - compte plein'
WHERE phone_number = '+22890123456';
```

### Changer Numéro Principal

```sql
-- Ancien compte
UPDATE mobile_money_accounts
SET is_primary = false
WHERE phone_number = '+22890123456';

-- Nouveau compte
UPDATE mobile_money_accounts
SET is_primary = true
WHERE phone_number = '+22890999999';
```

### Supprimer Compte (Déconseillé)

```sql
-- Mieux vaut désactiver que supprimer
-- Si vraiment nécessaire:
DELETE FROM mobile_money_accounts
WHERE phone_number = '+22890123456'
AND NOT EXISTS (
  SELECT 1 FROM payment_transactions 
  WHERE momo_account_id = mobile_money_accounts.id
);
```

---

## 📱 Interface Admin Recommandée

### Dashboard

```
┌─────────────────────────────────────────┐
│  💰 Paiements Mobile Money              │
├─────────────────────────────────────────┤
│                                         │
│  📊 Aujourd'hui                         │
│  • 12 ventes                            │
│  • 28,500 FCFA confirmés                │
│  • 3 en attente (6,000 FCFA)            │
│                                         │
│  ⏰ En Attente Confirmation (3)         │
│  ┌───────────────────────────────────┐  │
│  │ TXN-2025...ABC123                 │  │
│  │ Jean K. • 2000 F • MTN            │  │
│  │ 5 min ago                         │  │
│  │ [Vérifier] [Confirmer] [Refuser]  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ TXN-2025...DEF456                 │  │
│  │ Marie D. • 4000 F • Moov          │  │
│  │ 12 min ago                        │  │
│  │ [Vérifier] [Confirmer] [Refuser]  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  📈 Statistiques 30 Jours               │
│  • 345 ventes                           │
│  • 1,245,000 FCFA                       │
│  • Taux confirmation: 98%               │
│                                         │
└─────────────────────────────────────────┘
```

---

## ✅ Checklist Quotidienne

- [ ] Vérifier paiements en attente
- [ ] Confirmer paiements reçus (2x/jour minimum)
- [ ] Vérifier soldes comptes Mobile Money
- [ ] Répondre aux questions utilisateurs
- [ ] Consulter statistiques

---

**Guide créé**: 2025-11-30
**Système**: Production Ready ✅
