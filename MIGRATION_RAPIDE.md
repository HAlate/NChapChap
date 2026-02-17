# Guide Rapide - Migration Supabase UUMO

**UUMO** - Plateforme de mobilité urbaine internationale avec paiements modernes (Stripe, PayPal, Apple Pay, etc.)

## Option 1: Migration Automatique (Recommandé)

### Prérequis

- Installer Supabase CLI
- Avoir votre Project Reference ID (depuis Settings > General)

### Commande

```powershell
# Dans PowerShell, depuis le dossier UUMO
.\migrate_supabase.ps1 -ProjectRef "VOTRE_PROJECT_REF"
```

## Option 2: Migration Manuelle

### Étapes

1. **Activer PostGIS** (dans SQL Editor)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

2. **Exécuter les migrations** dans l'ordre suivant:

| #   | Fichier                                                    | Description              |
| --- | ---------------------------------------------------------- | ------------------------ |
| 1   | `20251129153356_01_create_base_enums_and_users.sql`        | Types ENUM + Table users |
| 2   | `20251129153421_02_create_token_tables.sql`                | Système de jetons        |
| 3   | `20251129153457_03_create_trips_and_offers.sql`            | Trajets et offres        |
| 4   | `20251129153535_04_create_orders_and_delivery.sql`         | Commandes                |
| 5   | `20251129153609_05_create_profile_tables.sql`              | Profils détaillés        |
| 6   | `20251129153635_06_create_products_and_menu.sql`           | Produits                 |
| 7   | `20251129153711_07_create_payments_and_functions.sql`      | Paiements                |
| 8   | `20251130014703_create_token_deduction_trigger.sql`        | Trigger jetons           |
| 9   | `20251130061524_create_orders_token_deduction_trigger.sql` | Trigger commandes        |
| 10  | `20251130064354_add_token_purchases_and_transactions.sql`  | Achats jetons            |
| 11  | `20251201000001_fix_users_insert_policy.sql`               | Fix policies             |
| 12  | `20251214_create_trip_offers_view.sql`                     | Vue offres               |
| 13  | `20251215_admin_dashboard_view.sql`                        | Dashboard admin          |
| 14  | `20251216_add_driver_arrived_notification.sql`             | Notifications            |
| 15  | `20251216_add_rider_info_to_trip_offers_view.sql`          | Info passagers           |

> **Note:** Les intégrations de paiement (Stripe, PayPal, Apple Pay, Google Pay) seront ajoutées ultérieurement. Ce projet est conçu pour une utilisation internationale (hors Afrique) avec des méthodes de paiement modernes.

## Configuration Post-Migration

### 1. Variables d'environnement

Créez `.env`:

```env
SUPABASE_URL=https://VOTRE_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=VOTRE_ANON_KEY
MAPBOX_ACCESS_TOKEN=VOTRE_MAPBOX_TOKEN
```

### 2. Mettre à jour les apps Flutter

**mobile_driver/lib/utils/constants.dart:**
**mobile_rider/lib/utils/constants.dart:**
**mobile_merchant/lib/utils/constants.dart:**
**mobile_eat/lib/utils/constants.dart:**

```dart
class Constants {
  static const String supabaseUrl = 'https://VOTRE_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'VOTRE_ANON_KEY';
  static const String mapboxAccessToken = 'VOTRE_MAPBOX_TOKEN';
}
```

### 3. Storage Buckets (optionnel)

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('profile-photos', 'profile-photos', true),
  ('product-images', 'product-images', true);
```

### 4. Données de test (optionnel)

```sql
-- Packages de jetons
INSERT INTO token_packages (name, token_type, token_amount, price_fcfa, bonus_tokens, is_active)
VALUES
  ('Starter', 'course', 5, 2500, 0, true),
  ('Pro', 'course', 10, 4500, 2, true),
  ('Premium', 'course', 20, 8000, 5, true);
```

## Vérification

```sql
-- Compter les tables
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public';
-- Devrait retourner ~20 tables

-- Lister les types ENUM
SELECT typname FROM pg_type
WHERE typtype = 'e'
ORDER BY typname;
-- Devrait montrer user_type, trip_status, etc.
```

## Dépannage

### Erreur "extension postgis does not exist"

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Erreur "permission denied"

- Utilisez le SQL Editor avec les droits admin
- Ou utilisez `supabase db push` avec le CLI

### Erreur "type already exists"

- Normal si vous réexécutez. Ignorez ou ajoutez `IF NOT EXISTS`

## Support

Consultez le guide complet: `GUIDE_INSTALLATION_SUPABASE.md`

---

**Version:** 1.0.0
**Date:** 7 janvier 2026
