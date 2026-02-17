# Guide de Configuration DBeaver - Connexion Supabase PostgreSQL

**Date:** 2025-11-29
**Base de données:** Urban Mobility Platform
**Type:** Supabase PostgreSQL

---

## 📋 Table des Matières

1. [Prérequis](#prérequis)
2. [Informations de Connexion](#informations-de-connexion)
3. [Installation DBeaver](#installation-dbeaver)
4. [Configuration de la Connexion](#configuration-de-la-connexion)
5. [Vérification de la Connexion](#vérification-de-la-connexion)
6. [Exploration de la Base](#exploration-de-la-base)
7. [Requêtes Utiles](#requêtes-utiles)
8. [Dépannage](#dépannage)

---

## 🔧 Prérequis

- DBeaver Community Edition (gratuit) ou Enterprise
- Connexion Internet
- Credentials Supabase (voir section suivante)

---

## 🔑 Informations de Connexion

### **URL Supabase**
```
https://ivcofgvpjrkntpzwlfhh.supabase.co
```

### **SESSION POOLER (IPv4 - RECOMMANDÉ)**

| Paramètre | Valeur |
|-----------|--------|
| **Host** | `aws-0-eu-central-1.pooler.supabase.com` |
| **Port** | `5432` |
| **Database** | `postgres` |
| **Username** | `postgres.ivcofgvpjrkntpzwlfhh` |
| **Password** | `[VOTRE_MOT_DE_PASSE_SUPABASE]` |
| **SSL Mode** | `require` |

> **🌐 IMPORTANT:** Utilisez le **Session Pooler** (port `5432`) pour les réseaux IPv4 (99% des cas). La connexion directe nécessite IPv6.

### **Alternative: Transaction Pooler**

| Paramètre | Valeur |
|-----------|--------|
| **Host** | `aws-0-eu-central-1.pooler.supabase.com` |
| **Port** | `6543` |
| **Database** | `postgres` |
| **Username** | `postgres.ivcofgvpjrkntpzwlfhh` |
| **Password** | `[VOTRE_MOT_DE_PASSE_SUPABASE]` |
| **SSL Mode** | `require` |

### **Récupérer le Mot de Passe**

1. Allez sur [Supabase Dashboard](https://supabase.com/dashboard)
2. Sélectionnez votre projet: `ivcofgvpjrkntpzwlfhh`
3. Allez dans **Settings** > **Database**
4. Copiez la **Database Password** (celle que vous avez définie lors de la création)

---

## 📥 Installation DBeaver

### **Windows**
1. Téléchargez depuis: https://dbeaver.io/download/
2. Choisissez **DBeaver Community** (gratuit)
3. Exécutez l'installateur `.exe`
4. Suivez l'assistant d'installation

### **macOS**
```bash
brew install --cask dbeaver-community
```

### **Linux (Ubuntu/Debian)**
```bash
sudo snap install dbeaver-ce
```

---

## ⚙️ Configuration de la Connexion

### **Étape 1: Créer une Nouvelle Connexion**

1. Ouvrez **DBeaver**
2. Cliquez sur **Database** > **New Database Connection** (ou `Ctrl+N` / `Cmd+N`)
3. Dans la liste, sélectionnez **PostgreSQL**
4. Cliquez sur **Next**

![DBeaver New Connection](https://dbeaver.io/wp-content/uploads/wikidocs/wiki/images/connection-dialog.png)

---

### **Étape 2: Configurer les Paramètres Principaux**

Dans l'onglet **Main**, remplissez:

```
┌─────────────────────────────────────────────────┐
│ Connection Settings                              │
├─────────────────────────────────────────────────┤
│                                                  │
│ Host:     aws-0-eu-central-1.pooler.supabase.com │
│ Port:     6543                                   │
│ Database: postgres                               │
│ Username: postgres.ivcofgvpjrkntpzwlfhh          │
│ Password: [VOTRE_MOT_DE_PASSE]                   │
│                                                  │
│ ☑ Show all databases                            │
│ ☑ Save password                                 │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Important:**
- ✅ Cochez **"Save password"** pour ne pas le retaper à chaque fois
- ✅ Cochez **"Show all databases"** (optionnel)

---

### **Étape 3: Configurer SSL**

1. Cliquez sur l'onglet **SSL**
2. Configurez comme suit:

```
┌─────────────────────────────────────────────────┐
│ SSL Settings                                     │
├─────────────────────────────────────────────────┤
│                                                  │
│ SSL Mode:     ● require                          │
│                                                  │
│ Root Certificate:  [Laisser vide]               │
│ Client Certificate: [Laisser vide]              │
│ Client Key:         [Laisser vide]              │
│                                                  │
│ ☐ Verify Server Certificate                     │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Modes SSL disponibles:**
- `disable` - Pas de SSL (NON RECOMMANDÉ)
- `allow` - SSL si disponible
- `prefer` - Préfère SSL
- **`require`** - Force SSL (RECOMMANDÉ) ✅
- `verify-ca` - Vérifie le certificat CA
- `verify-full` - Vérifie complètement

---

### **Étape 4: Paramètres Avancés (Optionnel)**

Cliquez sur l'onglet **Driver properties** et ajoutez:

```
┌─────────────────────────────────────────────────┐
│ Driver Properties                                │
├─────────────────────────────────────────────────┤
│                                                  │
│ applicationName: DBeaver-UrbanMobility          │
│ connectTimeout:  30                              │
│ socketTimeout:   60                              │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

### **Étape 5: Tester la Connexion**

1. Cliquez sur **Test Connection** en bas à gauche
2. Si c'est la première fois, DBeaver téléchargera le driver PostgreSQL (quelques secondes)
3. Vous devriez voir:

```
✅ Connection test: Connected
   Server version: PostgreSQL 15.x
   Driver name: PostgreSQL JDBC Driver
   Driver version: 42.x.x
```

4. Si succès: Cliquez sur **Finish**
5. Si erreur: Voir section [Dépannage](#dépannage)

---

### **Étape 6: Nommer la Connexion**

Dans l'onglet **General**, donnez un nom personnalisé:

```
Connection name: Urban Mobility - Supabase
Connection type: Dev / Production
```

---

## ✅ Vérification de la Connexion

### **Test 1: Voir les Tables**

1. Dans **Database Navigator** (panneau gauche)
2. Développez: `Urban Mobility - Supabase` > `Databases` > `postgres` > `Schemas` > `public` > `Tables`
3. Vous devriez voir les 15 tables:
   - delivery_offers
   - delivery_requests
   - driver_profiles
   - menu_items
   - merchant_profiles
   - orders
   - payments
   - products
   - restaurant_profiles
   - token_balances
   - token_packages
   - token_transactions
   - trip_offers
   - trips
   - users

---

### **Test 2: Exécuter une Requête**

1. Clic droit sur la connexion > **SQL Editor** > **New SQL Script**
2. Tapez cette requête:

```sql
-- Voir toutes les tables
SELECT
  table_name,
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE columns.table_name = tables.table_name) as column_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

3. Sélectionnez le texte et cliquez sur **Execute SQL Statement** (ou `Ctrl+Enter`)
4. Résultat attendu: 15 lignes (les 15 tables)

---

### **Test 3: Vérifier RLS**

```sql
-- Vérifier que toutes les tables ont RLS activé
SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

Toutes les tables doivent avoir `rowsecurity = true` ✅

---

## 🔍 Exploration de la Base

### **Voir la Structure d'une Table**

1. Dans **Database Navigator**
2. Développez: `Tables` > `users`
3. Double-cliquez sur `users`
4. Onglets disponibles:
   - **Columns** - Colonnes et types
   - **Constraints** - Contraintes (PK, FK, Check)
   - **Foreign Keys** - Relations
   - **Indexes** - Index créés
   - **Policies** - Politiques RLS

---

### **Voir les Relations (Diagramme ER)**

1. Clic droit sur `public` (schema)
2. Sélectionnez **View Diagram**
3. DBeaver génère automatiquement un **Entity-Relationship Diagram**
4. Vous verrez toutes les relations entre tables

---

### **Voir les Types ENUM**

```sql
SELECT
  t.typname as enum_name,
  array_agg(e.enumlabel ORDER BY e.enumsortorder) as values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
GROUP BY t.typname
ORDER BY t.typname;
```

Résultat: 13 types ENUM avec leurs valeurs

---

### **Voir les Fonctions Créées**

1. Dans **Database Navigator**
2. Développez: `postgres` > `Schemas` > `public` > `Functions`
3. Vous devriez voir:
   - `add_tokens(uuid, token_type, integer, text, uuid)`
   - `refund_tokens(uuid, token_type, integer, uuid, text)`
   - `spend_driver_token(uuid, token_type, uuid, text)`

---

## 📝 Requêtes Utiles

### **1. Voir Tous les Drivers Disponibles**

```sql
SELECT
  u.full_name,
  u.phone,
  dp.vehicle_type,
  dp.vehicle_plate,
  dp.rating_average,
  dp.total_trips,
  dp.current_lat,
  dp.current_lng
FROM users u
JOIN driver_profiles dp ON u.id = dp.id
WHERE u.status = 'active'
  AND dp.is_available = true
ORDER BY dp.rating_average DESC;
```

---

### **2. Voir Tous les Restaurants Ouverts**

```sql
SELECT
  rp.name,
  rp.cuisine_type,
  rp.address,
  rp.phone,
  rp.rating_average,
  rp.total_orders,
  rp.min_order_amount
FROM users u
JOIN restaurant_profiles rp ON u.id = rp.id
WHERE u.status = 'active'
  AND rp.is_open = true
ORDER BY rp.rating_average DESC;
```

---

### **3. Voir Solde Jetons d'un User**

```sql
SELECT
  u.full_name,
  u.user_type,
  tb.token_type,
  tb.balance,
  tb.total_purchased,
  tb.total_spent
FROM token_balances tb
JOIN users u ON tb.user_id = u.id
WHERE u.email = 'user@example.com'
ORDER BY tb.token_type;
```

---

### **4. Voir Packages Jetons Disponibles**

```sql
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
```

---

### **5. Voir Stats Globales**

```sql
SELECT
  'Total Users' as metric,
  COUNT(*)::text as value
FROM users

UNION ALL

SELECT
  'Active Drivers',
  COUNT(*)::text
FROM driver_profiles
WHERE is_available = true

UNION ALL

SELECT
  'Open Restaurants',
  COUNT(*)::text
FROM restaurant_profiles
WHERE is_open = true

UNION ALL

SELECT
  'Pending Trips',
  COUNT(*)::text
FROM trips
WHERE status = 'pending'

UNION ALL

SELECT
  'Completed Trips Today',
  COUNT(*)::text
FROM trips
WHERE status = 'completed'
  AND DATE(completed_at) = CURRENT_DATE;
```

---

## 🛠️ Dépannage

### **Erreur: "Connection refused"**

**Causes possibles:**
- Port incorrect (doit être `6543`)
- Host incorrect
- Firewall bloque la connexion

**Solution:**
1. Vérifiez que le port est bien `6543`
2. Vérifiez que le host est `aws-0-eu-central-1.pooler.supabase.com`
3. Désactivez temporairement votre firewall/antivirus

---

### **Erreur: "Password authentication failed"**

**Causes:**
- Mot de passe incorrect
- Username incorrect

**Solution:**
1. Allez sur Supabase Dashboard
2. Settings > Database
3. Cliquez sur **Reset Database Password**
4. Utilisez le nouveau mot de passe

---

### **Erreur: "SSL required"**

**Cause:**
- SSL non activé

**Solution:**
1. Dans l'onglet **SSL**
2. Changez SSL Mode en **require**
3. Testez à nouveau

---

### **Erreur: "Could not download driver"**

**Cause:**
- Problème de connexion Internet
- Driver déjà téléchargé mais corrompu

**Solution:**
1. Fermez DBeaver
2. Supprimez le cache: `~/.dbeaver/drivers/`
3. Relancez DBeaver
4. Retestez la connexion

---

### **Tables Vides Après Connexion**

**Cause:**
- Connecté au mauvais schema
- RLS bloque les requêtes

**Solution:**
1. Vérifiez que vous êtes dans le schema `public`
2. Les tables sont vides car c'est une nouvelle base
3. C'est normal! Vous pouvez maintenant insérer des données

---

## 🎯 Prochaines Étapes

Maintenant que DBeaver est configuré:

### **1. Insérer des Données de Test**

Créez un script SQL pour insérer des données de test:

```sql
-- Exemple: Créer un utilisateur rider
INSERT INTO users (email, phone, full_name, user_type, status)
VALUES
  ('rider@test.com', '+1234567890', 'John Rider', 'rider', 'active')
RETURNING id;
```

### **2. Tester les Fonctions**

```sql
-- Ajouter 10 jetons à un user
SELECT add_tokens(
  'USER_ID_HERE'::uuid,
  'course'::token_type,
  10,
  'mobile_money',
  NULL
);
```

### **3. Explorer les Politiques RLS**

Dans DBeaver, allez dans:
- Table > `users` > Onglet **Policies**
- Vous verrez toutes les politiques RLS actives

---

## 📚 Ressources Supplémentaires

- **DBeaver Documentation**: https://dbeaver.io/docs/
- **Supabase Documentation**: https://supabase.com/docs
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/

---

## 🔒 Sécurité

**Important:**
- ❌ Ne partagez JAMAIS votre mot de passe
- ❌ Ne commitez PAS le fichier `.env` dans Git
- ✅ Utilisez toujours SSL (`require` mode)
- ✅ Changez le mot de passe régulièrement
- ✅ Utilisez des connexions sécurisées

---

## ✅ Checklist de Configuration

- [ ] DBeaver installé
- [ ] Connexion créée avec les bons paramètres
- [ ] **Host:** `aws-0-eu-central-1.pooler.supabase.com`
- [ ] **Port:** `6543`
- [ ] **Username:** `postgres.ivcofgvpjrkntpzwlfhh` (avec le point et PROJECT_REF)
- [ ] SSL activé (mode `require`)
- [ ] Test de connexion réussi
- [ ] 15 tables visibles dans Database Navigator
- [ ] Première requête exécutée avec succès
- [ ] Diagramme ER visualisé
- [ ] Fonctions utilitaires visibles

---

## ⚠️ Erreurs Courantes et Solutions

### **Erreur: "FATAL: Tenant or user not found"**

**Cause:** Username incorrect ou format incomplet

**❌ INCORRECT:**
- `postgres` (sans le PROJECT_REF)
- Username manquant le suffixe

**✅ CORRECT:**
- `postgres.ivcofgvpjrkntpzwlfhh` (avec le point et PROJECT_REF)

**Solution:** Le username DOIT être au format `postgres.PROJECT_REF` pour le Transaction Pooler.

---

### **Erreur: "Unknown host db.ivcofgvpjrkntpzwlfhh.supabase.co"**

**Cause:** Host direct non accessible depuis l'extérieur

**❌ INCORRECT:**
- Host `db.ivcofgvpjrkntpzwlfhh.supabase.co`
- Port `5432`
- Username `postgres`

**✅ CORRECT (Transaction Pooler):**
- Host `aws-0-eu-central-1.pooler.supabase.com`
- Port `6543`
- Username `postgres.ivcofgvpjrkntpzwlfhh`

**Explication:** La connexion directe `db.PROJECT_REF.supabase.co:5432` n'est accessible que depuis les Edge Functions Supabase. Pour DBeaver, pgAdmin, et autres clients externes, utilisez TOUJOURS le Transaction Pooler.

---

**🎉 Félicitations! Votre connexion DBeaver est configurée!**

Vous pouvez maintenant gérer votre base de données Urban Mobility directement depuis DBeaver avec une interface graphique complète.
