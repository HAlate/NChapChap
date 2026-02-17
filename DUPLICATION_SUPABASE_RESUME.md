# Résumé de la Duplication Supabase - 15 janvier 2026

## ✅ Actions Effectuées

### 1. Documentation Créée

- **GUIDE_DUPLICATION_SUPABASE.md** : Guide complet étape par étape
- **duplicate_supabase_project.ps1** : Script PowerShell automatisé

### 2. Problèmes Identifiés et Résolus

#### Problème #1 : Migrations en Double

**Erreur** : `type "vehicle_type" does not exist`

**Cause** : Des migrations avec timestamps antérieurs (151xxx) étaient en conflit avec les nouvelles migrations numérotées (153xxx)

**Solution** :

```powershell
# Anciennes migrations déplacées vers backup
cd C:\000APPS\UUMO\supabase
New-Item -ItemType Directory -Force -Path "migrations_old_backup"
Move-Item -Path "migrations\20251129151*.sql" -Destination "migrations_old_backup\" -Force
```

**Migrations déplacées** :

- `20251129151241_create_trip_offers_table.sql`
- `20251129151318_create_delivery_tables.sql`
- `20251129151348_create_products_and_menu_tables.sql`
- `20251129151418_create_payments_table.sql`
- `20251129151459_create_profile_tables.sql`

#### Problème #2 : Fonction UUID Incorrecte

**Erreur** : `function uuid_generate_v4() does not exist`

**Cause** : La migration `20260108000001_create_no_show_system.sql` utilisait `uuid_generate_v4()` au lieu de `gen_random_uuid()`

**Solution** : Migration corrigée pour utiliser la fonction native PostgreSQL

```sql
-- ❌ Avant
id UUID PRIMARY KEY DEFAULT uuid_generate_v4()

-- ✅ Après
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

### 3. Migrations Appliquées avec Succès

**26 migrations appliquées** sur le projet Supabase (xmbuoprspzhtkbgllwfj) :

1. ✅ 20251129153356_01_create_base_enums_and_users.sql
2. ✅ 20251129153421_02_create_token_tables.sql
3. ✅ 20251129153457_03_create_trips_and_offers.sql
4. ✅ 20251129153535_04_create_orders_and_delivery.sql
5. ✅ 20251129153609_05_create_profile_tables.sql
6. ✅ 20251129153635_06_create_products_and_menu.sql
7. ✅ 20251129153711_07_create_payments_and_functions.sql
8. ✅ 20251130014703_create_token_deduction_trigger.sql
9. ✅ 20251130061524_create_orders_token_deduction_trigger.sql
10. ✅ 20251130064354_add_token_purchases_and_transactions.sql
11. ✅ 20251201000001_fix_users_insert_policy.sql
12. ✅ 20251214_create_trip_offers_view.sql
13. ✅ 20251215_admin_dashboard_view.sql
14. ✅ 20251216000001_add_driver_arrived_notification.sql
15. ✅ 20251216000002_add_driver_counter_price.sql
16. ✅ 20251216000003_add_rider_info_to_trip_offers_view.sql
17. ✅ 20260107000001_update_vehicle_types.sql
18. ✅ 20260107000002_add_booking_type.sql
19. ✅ 20260107000003_create_new_trip_function.sql
20. ✅ 20260107000004_add_kyc_system.sql
21. ✅ 20260107000005_add_stripe_payments.sql
22. ✅ 20260107000006_add_sumup_payments.sql
23. ✅ 20260107000007_add_sumup_individual_keys.sql
24. ✅ 20260108000001_create_no_show_system.sql
25. ✅ 20260108000002_change_token_deduction_to_trip_start.sql
26. ✅ 20260108000003_fix_users_insert_policy_for_signup.sql

## 📋 Prochaines Étapes pour la Duplication

Maintenant que les migrations sont testées et fonctionnent, vous pouvez procéder à la duplication :

### 1. Créer un Nouveau Projet Supabase

```
1. Allez sur supabase.com
2. Créez un nouveau projet (ex: UUMO-Staging)
3. Notez les credentials :
   - Project Ref
   - Anon Key
   - Service Role Key
```

### 2. Utiliser le Script Automatique

```powershell
cd C:\000APPS\UUMO
.\duplicate_supabase_project.ps1 `
  -NewProjectRef "abc123" `
  -NewAnonKey "eyJ..." `
  -Environment "staging"
```

### 3. Actions Manuelles Post-Duplication

#### A. Extensions PostgreSQL

Activer dans Database > Extensions :

- ✅ postgis
- ✅ pg_net
- ✅ uuid-ossp (normalement déjà activé)

#### B. Configuration Auth

Dans Authentication > Settings :

- Email Confirmation : Désactivé ou selon besoin
- Site URL : Votre domaine
- Redirect URLs : Ajouter les URLs autorisées

#### C. Edge Functions

```powershell
# Déployer les fonctions
cd C:\000APPS\UUMO\supabase
supabase functions deploy stripe-webhook --project-ref [nouveau-ref]
supabase functions deploy stripe-create-payment-intent --project-ref [nouveau-ref]
```

Puis configurer les secrets dans Edge Functions > Secrets :

```
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

#### D. Webhooks Stripe

Créer un nouveau webhook endpoint :

- URL : `https://[nouveau-ref].supabase.co/functions/v1/stripe-webhook`
- Événements : payment_intent.succeeded, payment_intent.payment_failed

## 📁 Structure du Projet

```
C:\000APPS\UUMO\
├── supabase/
│   ├── migrations/               # 26 migrations actives
│   ├── migrations_old_backup/    # 5 anciennes migrations (backup)
│   ├── functions/
│   │   ├── stripe-webhook/
│   │   └── stripe-create-payment-intent/
│   └── ...
├── mobile_driver/
│   └── .env.example             # Template de configuration
├── admin/
│   └── .env.example             # Template de configuration
├── GUIDE_DUPLICATION_SUPABASE.md    # Documentation complète
└── duplicate_supabase_project.ps1    # Script automatisé
```

## 🔍 Vérifications Recommandées

Après duplication, exécutez ces requêtes SQL pour valider :

```sql
-- 1. Vérifier les tables
SELECT COUNT(*) as total_tables
FROM information_schema.tables
WHERE table_schema = 'public';
-- Devrait retourner environ 20-25 tables

-- 2. Vérifier les policies RLS
SELECT COUNT(*) as total_policies
FROM pg_policies
WHERE schemaname = 'public';
-- Devrait retourner environ 40-50 policies

-- 3. Vérifier les fonctions
SELECT COUNT(*) as total_functions
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION';
-- Devrait retourner environ 5-10 fonctions

-- 4. Vérifier les extensions
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('postgis', 'pg_net', 'uuid-ossp');
```

## ⚠️ Points d'Attention

1. **Ordre des Migrations** : Toujours respecter l'ordre chronologique (timestamp)
2. **Fonction UUID** : Utiliser `gen_random_uuid()` et non `uuid_generate_v4()`
3. **Extensions** : Activer les extensions nécessaires avant d'appliquer les migrations
4. **Backup** : Toujours garder un backup des anciennes migrations
5. **Credentials** : Ne jamais commiter les fichiers .env avec de vraies clés

## 📞 Support

Pour toute question :

- Consultez [GUIDE_DUPLICATION_SUPABASE.md](GUIDE_DUPLICATION_SUPABASE.md)
- Documentation Supabase : https://supabase.com/docs
- CLI Supabase : https://supabase.com/docs/guides/cli

---

**Généré le** : 15 janvier 2026  
**Projet** : UUMO (HAlate/UUMO)  
**Projet Supabase** : xmbuoprspzhtkbgllwfj.supabase.co
