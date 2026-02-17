# Guide de Duplication du Projet Supabase UUMO

Ce guide vous explique comment créer une copie complète de votre projet Supabase (par exemple, pour créer un environnement de staging ou de développement).

## Prérequis

- Un compte Supabase (gratuit ou payant)
- CLI Supabase installé : `npm install -g supabase`
- Accès au projet Supabase existant
- Git installé

## Étape 1 : Créer un Nouveau Projet Supabase

1. Connectez-vous à [supabase.com](https://supabase.com)
2. Cliquez sur "New Project"
3. Remplissez les informations :
   - **Name**: `UUMO-Dev` (ou autre nom selon votre besoin)
   - **Database Password**: Choisissez un mot de passe fort (notez-le !)
   - **Region**: Choisissez la même région que votre projet principal
   - **Pricing Plan**: Sélectionnez votre plan
4. Attendez que le projet soit créé (2-3 minutes)

## Étape 2 : Récupérer les Credentials du Nouveau Projet

Une fois le projet créé :

1. Allez dans **Settings** > **API**
2. Notez les informations suivantes :
   - **Project URL**: `https://[project-ref].supabase.co`
   - **anon/public key**: La clé publique
   - **service_role key**: La clé de service (gardez-la secrète !)

## Étape 3 : Appliquer les Migrations

### Option A : Via le CLI Supabase (Recommandé)

```powershell
# 1. Se connecter au CLI Supabase
supabase login

# 2. Lier le projet
supabase link --project-ref [nouveau-project-ref]

# 3. Appliquer toutes les migrations
supabase db push
```

### Option B : Manuellement via l'Interface SQL

1. Allez dans **SQL Editor** de votre nouveau projet
2. Copiez et exécutez les migrations dans l'ordre chronologique :

```powershell
# Script PowerShell pour appliquer les migrations manuellement
$migrations = Get-ChildItem "c:\000APPS\UUMO\supabase\migrations" -Filter "*.sql" | Sort-Object Name

foreach ($migration in $migrations) {
    Write-Host "Migration à appliquer : $($migration.Name)"
    Write-Host "Copiez le contenu dans SQL Editor de Supabase"
    Get-Content $migration.FullName | clip
    Read-Host "Appuyez sur Entrée après avoir exécuté la migration"
}
```

### Liste des Migrations (dans l'ordre)

Les migrations se trouvent dans `supabase/migrations/` :

**Note importante** : Si vous avez des anciennes migrations avec timestamps `20251129151xxx`, déplacez-les d'abord dans un dossier de backup avant d'appliquer les migrations.

1. `20251129153356_01_create_base_enums_and_users.sql`
2. `20251129153421_02_create_token_tables.sql`
3. `20251129153457_03_create_trips_and_offers.sql`
4. `20251129153535_04_create_orders_and_delivery.sql`
5. `20251129153609_05_create_profile_tables.sql`
6. `20251129153635_06_create_products_and_menu.sql`
7. `20251129153711_07_create_payments_and_functions.sql`
8. `20251130014703_create_token_deduction_trigger.sql`
9. `20251130061524_create_orders_token_deduction_trigger.sql`
10. `20251130064354_add_token_purchases_and_transactions.sql`
11. `20251201000001_fix_users_insert_policy.sql`
12. `20251214_create_trip_offers_view.sql`
13. `20251215_admin_dashboard_view.sql`
14. `20251216000001_add_driver_arrived_notification.sql`
15. `20251216000002_add_driver_counter_price.sql`
16. `20251216000003_add_rider_info_to_trip_offers_view.sql`
17. `20260107000001_update_vehicle_types.sql`
18. `20260107000002_add_booking_type.sql`
19. `20260107000003_create_new_trip_function.sql`
20. `20260107000004_add_kyc_system.sql`
21. `20260107000005_add_stripe_payments.sql`
22. `20260107000006_add_sumup_payments.sql`
23. `20260107000007_add_sumup_individual_keys.sql`
24. `20260108000001_create_no_show_system.sql`
25. `20260108000002_change_token_deduction_to_trip_start.sql`
26. `20260108000003_fix_users_insert_policy_for_signup.sql`

## Étape 4 : Déployer les Edge Functions

```powershell
# Se placer dans le répertoire supabase
cd c:\000APPS\UUMO\supabase

# Déployer toutes les fonctions
supabase functions deploy stripe-webhook --project-ref [nouveau-project-ref]
supabase functions deploy stripe-create-payment-intent --project-ref [nouveau-project-ref]
```

## Étape 5 : Configurer les Variables d'Environnement des Functions

Dans **Edge Functions** > **Secrets**, ajoutez :

```
STRIPE_SECRET_KEY=votre_clé_stripe_secret
STRIPE_WEBHOOK_SECRET=votre_webhook_secret_stripe
```

## Étape 6 : Activer les Extensions Nécessaires

Allez dans **Database** > **Extensions** et activez :

- ✅ `postgis` (pour les fonctionnalités de géolocalisation)
- ✅ `pg_net` (pour les webhooks)
- ✅ `uuid-ossp` (pour les UUID)

## Étape 7 : Configurer l'Authentification

1. Allez dans **Authentication** > **Settings**
2. Configurez :
   - **Email Confirmation**: Désactivé (selon vos besoins)
   - **Site URL**: `http://localhost` (ou votre domaine)
   - **Redirect URLs**: Ajoutez vos URLs autorisées

## Étape 8 : Mettre à Jour les Applications

### Mobile Driver App

Créez ou modifiez `mobile_driver/.env` :

```env
# Supabase Configuration - NOUVEAU PROJET
SUPABASE_URL=https://[nouveau-project-ref].supabase.co
SUPABASE_ANON_KEY=[nouvelle-anon-key]

# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key_here

# SumUp Configuration (Optional)
# SUMUP_AFFILIATE_KEY=your_sumup_affiliate_key_here
```

### Mobile Rider App

Si vous avez une app rider, créez `mobile_rider/.env` :

```env
SUPABASE_URL=https://[nouveau-project-ref].supabase.co
SUPABASE_ANON_KEY=[nouvelle-anon-key]
```

### Admin Dashboard

Créez ou modifiez `admin/.env` :

```env
VITE_SUPABASE_URL=https://[nouveau-project-ref].supabase.co
VITE_SUPABASE_ANON_KEY=[nouvelle-anon-key]
```

### Backend (si applicable)

Créez ou modifiez `backend/.env` :

```env
SUPABASE_URL=https://[nouveau-project-ref].supabase.co
SUPABASE_SERVICE_ROLE_KEY=[nouvelle-service-role-key]
```

## Étape 9 : Importer les Données de Test (Optionnel)

Si vous voulez copier les données du projet original :

```powershell
# 1. Exporter depuis l'ancien projet
# Dans le SQL Editor de l'ancien projet, exécutez :
COPY (SELECT * FROM users WHERE role = 'driver' LIMIT 5) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM trips LIMIT 10) TO STDOUT WITH CSV HEADER;
# etc.

# 2. Importer dans le nouveau projet
# Utilisez le SQL Editor ou l'interface Import de Supabase
```

**OU** créez des données de test avec les scripts existants :

```powershell
# Créer des chauffeurs de test
cd c:\000APPS\UUMO\supabase
# Modifier les credentials dans create_test_drivers.sql et l'exécuter
```

## Étape 10 : Tester la Duplication

### Vérifications essentielles :

```sql
-- 1. Vérifier les tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- 2. Vérifier les policies RLS
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public';

-- 3. Vérifier les fonctions
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION';

-- 4. Vérifier les triggers
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public';

-- 5. Vérifier les extensions
SELECT * FROM pg_extension;
```

## Étape 11 : Configurer les Webhooks (si nécessaire)

Si vous utilisez des webhooks Stripe ou autres :

1. Allez sur le dashboard Stripe
2. Créez un nouveau webhook endpoint
3. URL : `https://[nouveau-project-ref].supabase.co/functions/v1/stripe-webhook`
4. Événements à écouter :
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `charge.succeeded`
5. Copiez le signing secret et ajoutez-le aux secrets des Edge Functions

## Étape 12 : Documentation et Suivi

Créez un fichier pour suivre les différents environnements :

```markdown
# Environnements UUMO

## Production

- URL: https://xmbuoprspzhtkbgllwfj.supabase.co
- Usage: Production en direct

## Staging (nouveau)

- URL: https://[nouveau-project-ref].supabase.co
- Usage: Tests avant mise en production
- Créé le: [DATE]
```

## Script PowerShell de Duplication Automatique

Créez `duplicate_supabase_project.ps1` :

```powershell
# Script de duplication automatique
param(
    [Parameter(Mandatory=$true)]
    [string]$NewProjectRef,

    [Parameter(Mandatory=$true)]
    [string]$NewAnonKey,

    [string]$Environment = "staging"
)

Write-Host "=== Duplication du Projet Supabase UUMO ===" -ForegroundColor Green
Write-Host ""

# 1. Lier le nouveau projet
Write-Host "1. Liaison au nouveau projet..." -ForegroundColor Cyan
supabase link --project-ref $NewProjectRef

# 2. Appliquer les migrations
Write-Host "2. Application des migrations..." -ForegroundColor Cyan
supabase db push

# 3. Mettre à jour les fichiers .env
Write-Host "3. Mise à jour des configurations..." -ForegroundColor Cyan

$envFiles = @(
    "mobile_driver\.env.$Environment",
    "admin\.env.$Environment"
)

foreach ($envFile in $envFiles) {
    $fullPath = "c:\000APPS\UUMO\$envFile"
    Write-Host "   - Création de $envFile" -ForegroundColor Yellow

    $content = @"
SUPABASE_URL=https://$NewProjectRef.supabase.co
SUPABASE_ANON_KEY=$NewAnonKey
"@

    Set-Content -Path $fullPath -Value $content
}

Write-Host ""
Write-Host "=== Duplication Terminée ===" -ForegroundColor Green
Write-Host "N'oubliez pas de :" -ForegroundColor Yellow
Write-Host "  1. Déployer les Edge Functions" -ForegroundColor Yellow
Write-Host "  2. Configurer les secrets des fonctions" -ForegroundColor Yellow
Write-Host "  3. Activer les extensions nécessaires" -ForegroundColor Yellow
Write-Host "  4. Tester la connexion depuis les apps" -ForegroundColor Yellow
```

## Utilisation du Script

```powershell
.\duplicate_supabase_project.ps1 -NewProjectRef "abc123def456" -NewAnonKey "eyJhbGc..." -Environment "staging"
```

## Troubleshooting

### Problème : Erreur "type vehicle_type does not exist"

- **Cause** : Des anciennes migrations avec des timestamps antérieurs existent dans le dossier
- **Solution** : Déplacez les anciennes migrations (151xxx) vers un backup

```powershell
cd C:\000APPS\UUMO\supabase
New-Item -ItemType Directory -Force -Path "migrations_old_backup"
Move-Item -Path "migrations\20251129151*.sql" -Destination "migrations_old_backup\" -Force
```

### Problème : Erreur "function uuid_generate_v4() does not exist"

- **Cause** : Utilisation de `uuid_generate_v4()` au lieu de `gen_random_uuid()`
- **Solution** : Dans vos migrations, utilisez `gen_random_uuid()` (fonction native PostgreSQL)

```sql
-- ❌ NE PAS UTILISER
id UUID PRIMARY KEY DEFAULT uuid_generate_v4()

-- ✅ UTILISER CECI
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

### Problème : Migration échoue

- **Solution** : Vérifiez que PostGIS est activé
- Exécutez : `CREATE EXTENSION IF NOT EXISTS postgis;`

### Problème : RLS Policies bloquent l'accès

- **Solution** : Vérifiez que les policies sont bien créées
- Utilisez `check_current_rls_policies.sql` pour diagnostiquer

### Problème : Les Edge Functions ne fonctionnent pas

- **Solution** : Vérifiez les secrets/variables d'environnement
- Consultez les logs dans **Edge Functions** > **Logs**

### Problème : Authentification échoue

- **Solution** : Vérifiez les Site URLs et Redirect URLs dans les settings

## Maintenance Continue

Pour synchroniser les modifications futures :

```powershell
# 1. Créer une nouvelle migration dans le projet principal
supabase migration new "description_du_changement"

# 2. Appliquer sur staging
supabase db push --project-ref [staging-ref]

# 3. Tester sur staging

# 4. Appliquer sur production
supabase db push --project-ref [production-ref]
```

## Checklist Finale

- [ ] Nouveau projet Supabase créé
- [ ] Toutes les migrations appliquées
- [ ] Extensions activées (postgis, pg_net, uuid-ossp)
- [ ] Edge Functions déployées
- [ ] Secrets des fonctions configurés
- [ ] Fichiers .env mis à jour dans toutes les apps
- [ ] Tests de connexion réussis
- [ ] Données de test créées (si nécessaire)
- [ ] Webhooks configurés (si nécessaire)
- [ ] Documentation mise à jour
- [ ] Équipe informée des nouvelles URLs

## Support

Pour plus d'aide :

- Documentation Supabase : https://supabase.com/docs
- CLI Supabase : https://supabase.com/docs/guides/cli
- GitHub Issues du projet UUMO

---

**Note** : Conservez précieusement les credentials de tous vos environnements dans un gestionnaire de mots de passe sécurisé.
