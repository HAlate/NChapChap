# Guide d'Installation Supabase - Projet UUMO

Ce guide vous aide à configurer votre nouveau projet Supabase avec tous les schémas nécessaires pour faire fonctionner l'application UUMO.

**UUMO** est une plateforme de mobilité urbaine internationale, conçue pour les marchés mondiaux (hors Afrique) avec des solutions de paiement modernes.

## Prérequis

- Un compte Supabase (https://supabase.com)
- Un nouveau projet Supabase créé
- Accès au SQL Editor de votre projet

## Méthode 1: Utilisation du Supabase CLI (Recommandé)

### Installation du CLI

#### Windows (Recommandé: npm)

```powershell
# Option 1: Via npm (RECOMMANDÉ - nécessite Node.js)
npm install -g supabase

# Option 2: Via Scoop (nécessite Scoop Package Manager)
# Installer Scoop d'abord si non installé:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop install supabase

# Option 3: Téléchargement direct
# Télécharger depuis: https://github.com/supabase/cli/releases
# Décompresser et ajouter au PATH
```

#### macOS

```bash
brew install supabase/tap/supabase
```

#### Linux

```bash
# Via npm
npm install -g supabase

# Ou téléchargement direct
# https://github.com/supabase/cli/releases
```

### Configuration et Migration

1. **Initialiser la connexion** (depuis le dossier racine du projet)

```bash
cd c:\000APPS\UUMO
supabase login
```

2. **Lier votre projet Supabase**

```bash
# Récupérez votre Project Reference ID depuis le dashboard Supabase
# Paramètres > General > Reference ID
supabase link --project-ref VOTRE_PROJECT_REF
```

3. **Appliquer toutes les migrations**

```bash
supabase db push
```

## Méthode 2: Application Manuelle via SQL Editor

Si vous préférez ou ne pouvez pas utiliser le CLI, voici l'ordre d'exécution des migrations:

### Étape 1: Activer les extensions PostGIS (Important!)

Dans le SQL Editor, exécutez d'abord:

```sql
-- Activer uuid-ossp pour la génération d'UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Activer PostGIS pour les fonctionnalités géospatiales
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Activer pg_cron si vous avez besoin de tâches planifiées
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

### Étape 2: Exécuter les migrations dans l'ordre

Ouvrez chaque fichier dans l'ordre suivant et exécutez-le dans le SQL Editor:

#### Migrations de Base (OBLIGATOIRES)

1. ✅ `supabase/migrations/20251129153356_01_create_base_enums_and_users.sql`

   - Crée les types ENUM de base
   - Crée la table `users`

2. ✅ `supabase/migrations/20251129153421_02_create_token_tables.sql`

   - Tables pour le système de jetons (token_packages, token_balances, token_transactions)

3. ✅ `supabase/migrations/20251129153457_03_create_trips_and_offers.sql`

   - Tables pour les trajets et offres (trips, trip_offers)

4. ✅ `supabase/migrations/20251129153535_04_create_orders_and_delivery.sql`

   - Tables pour les commandes et livraisons

5. ✅ `supabase/migrations/20251129153609_05_create_profile_tables.sql`

   - Tables pour les profils détaillés (driver_profiles, merchant_profiles)

6. ✅ `supabase/migrations/20251129153635_06_create_products_and_menu.sql`

   - Tables pour les produits et menus

7. ✅ `supabase/migrations/20251129153711_07_create_payments_and_functions.sql`
   - Tables de paiement et fonctions utilitaires

#### Triggers et Automatisations

8. ✅ `supabase/migrations/20251130014703_create_token_deduction_trigger.sql`

   - Déduction automatique des jetons pour les trajets

9. ✅ `supabase/migrations/20251130061524_create_orders_token_deduction_trigger.sql`

   - Déduction automatique pour les commandes

10. ✅ `supabase/migrations/20251130064354_add_token_purchases_and_transactions.sql`
    - Système d'achat de jetons

#### Correctifs et Améliorations

11. ✅ `supabase/migrations/20251201000001_fix_users_insert_policy.sql`
    - Correction des politiques d'insertion des utilisateurs

#### Fonctionnalités Avancées

12. ✅ `supabase/migrations/20251214_create_trip_offers_view.sql`

    - Vue pour les offres de trajets

13. ✅ `supabase/migrations/20251215_admin_dashboard_view.sql`

    - Vue pour le dashboard admin

14. ✅ `supabase/migrations/20251216_add_driver_arrived_notification.sql`

    - Notifications d'arrivée du chauffeur

15. ✅ `supabase/migrations/20251216_add_rider_info_to_trip_offers_view.sql`
    - Amélioration de la vue des offres avec infos passager

> **Note:** Les méthodes de paiement modernes (cartes bancaires, Apple Pay, Google Pay, etc.) seront intégrées dans une phase ultérieure du développement.

## Étape 3: Configuration Supabase Dashboard

### 1. Configurer l'Authentification

Dans `Authentication > Providers`:

- ✅ Activer **Email**
- ✅ Activer **Phone** (si nécessaire)
- ✅ Configurer les redirections

### 2. Configurer les Storage Buckets (si nécessaire)

Dans `Storage`:

```sql
-- Bucket pour les photos de profil
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true);

-- Bucket pour les photos de produits
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true);
```

### 3. Variables d'Environnement

Créez un fichier `.env` à la racine du projet:

```env
# Supabase
SUPABASE_URL=https://VOTRE_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=VOTRE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=VOTRE_SERVICE_ROLE_KEY

# Mapbox (pour la navigation)
MAPBOX_ACCESS_TOKEN=VOTRE_MAPBOX_TOKEN
```

## Étape 4: Insérer des Données de Test (Optionnel)

Pour tester le système, insérez des données de test:

```sql
-- Insérer un package de jetons de test
INSERT INTO token_packages (name, token_type, token_amount, price_fcfa, bonus_tokens, is_active)
VALUES
  ('Starter Pack', 'course', 5, 2500, 0, true),
  ('Pro Pack', 'course', 10, 4500, 2, true),
  ('Premium Pack', 'course', 20, 8000, 5, true);
```

## Vérification

Pour vérifier que tout est bien installé:

```sql
-- Vérifier les tables créées
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Vérifier les types ENUM
SELECT typname
FROM pg_type
WHERE typtype = 'e'
ORDER BY typname;

-- Vérifier les fonctions
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

## Configuration des Applications Mobiles

### Flutter Apps

Mettez à jour les constantes dans chaque app:

**mobile_driver/lib/utils/constants.dart:**

```dart
class Constants {
  static const String supabaseUrl = 'https://VOTRE_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'VOTRE_ANON_KEY';
  static const String mapboxAccessToken = 'VOTRE_MAPBOX_TOKEN';
}
```

**mobile_rider/lib/utils/constants.dart:**

```dart
class Constants {
  static const String supabaseUrl = 'https://VOTRE_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'VOTRE_ANON_KEY';
  static const String mapboxAccessToken = 'VOTRE_MAPBOX_TOKEN';
}
```

## Dépannage

### Erreur: "type vehicle_type does not exist" (ou autres types ENUM)

Cette erreur signifie que la migration 1 n'a pas été exécutée. Vérifiez d'abord si les types ENUM existent:

```sql
-- Vérifier les types ENUM créés
SELECT typname
FROM pg_type
WHERE typtype = 'e'
AND typname IN ('user_type', 'user_status', 'vehicle_type', 'payment_method', 'token_type', 'transaction_type')
ORDER BY typname;

-- Devrait retourner les 6 types
```

**Si les types n'existent pas**, exécutez d'abord:

- `supabase/migrations/20251129153356_01_create_base_enums_and_users.sql`

**Ordre CRITIQUE des migrations:**

1. Migration 01 - Crée les types ENUM (OBLIGATOIRE EN PREMIER)
2. Migration 02-07 - Utilisent ces types
3. Migrations 08+ - Dépendent des tables créées par 01-07

**Important:** Ne sautez JAMAIS la migration 01, elle est la base de tout le schéma.

### Erreur: "extension postgis does not exist"

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Erreur: "function uuid_generate_v4() does not exist"

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Erreur: "relation driver_profiles does not exist"

Cette erreur signifie que la migration 5 n'a pas été exécutée ou a échoué. Vérifiez:

```sql
-- Vérifier si la table existe
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name = 'driver_profiles'
);
```

Si elle n'existe pas, exécutez manuellement:

- `supabase/migrations/20251129153609_05_create_profile_tables.sql`

Puis continuez avec les migrations suivantes.

### Erreur: "type already exists"

- Certains types peuvent déjà exister. Ajoutez `IF NOT EXISTS`:

```sql
CREATE TYPE IF NOT EXISTS user_type AS ENUM (...);
```

### Erreur de politique RLS

- Vérifiez que l'utilisateur est authentifié
- Consultez les logs dans `Logs > Postgres Logs`

### Vérifier l'état des migrations

Avant de continuer, vérifiez que toutes les tables requises existent:

```sql
-- Liste des tables qui doivent exister
SELECT table_name,
  CASE
    WHEN table_name IN ('users', 'token_packages', 'token_balances',
                        'token_transactions', 'trips', 'trip_offers',
                        'driver_profiles', 'merchant_profiles', 'orders',
                        'deliveries', 'products', 'restaurant_menus')
    THEN '✅ Existe'
    ELSE '❌ Manquante'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('users', 'token_packages', 'token_balances',
                     'token_transactions', 'trips', 'trip_offers',
                     'driver_profiles', 'merchant_profiles', 'orders',
                     'deliveries', 'products', 'restaurant_menus')
ORDER BY table_name;
```

## Commandes Utiles

```bash
# Voir les migrations en attente
supabase db diff

# Créer une nouvelle migration
supabase migration new nom_de_la_migration

# Reset de la base (ATTENTION: efface toutes les données!)
supabase db reset

# Générer les types TypeScript
supabase gen types typescript --local > types/supabase.ts
```

## Support

En cas de problème:

1. Consultez les logs Supabase Dashboard
2. Vérifiez les politiques RLS
3. Testez les requêtes SQL manuellement dans le SQL Editor

## Prochaines Étapes

Une fois la migration terminée:

1. ✅ Tester l'authentification
2. ✅ Créer des utilisateurs de test
3. ✅ Tester la création de trajets
4. ✅ Tester le système de jetons
5. ✅ Déployer les applications mobiles

---

**Date de création:** 7 janvier 2026
**Version:** 1.0.0
**Projet:** UUMO - Urban Mobility Platform
