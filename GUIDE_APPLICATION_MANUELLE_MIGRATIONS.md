# Guide: Application manuelle des migrations via Dashboard Supabase

## Problème

`supabase db push` échoue car il y a un désalignement entre l'historique des migrations locales et distantes.

## Solution: Application manuelle via Dashboard

### Étape 1: Accéder au SQL Editor

1. Ouvrir [Supabase Dashboard](https://supabase.com/dashboard)
2. Sélectionner votre projet **UUMO**
3. Aller dans **SQL Editor** (menu gauche)

### Étape 2: Appliquer les 3 nouvelles migrations

#### Migration 1: No Show System

Copier et exécuter le contenu de:
`supabase/migrations/20260108000001_create_no_show_system.sql`

**Résumé**:

- Crée tables `no_show_reports` et `user_penalties`
- Ajoute colonnes tracking No Show dans `users`
- Configure RLS et fonctions d'expiration automatique

**Commandes clés**:

```sql
CREATE TABLE IF NOT EXISTS no_show_reports (...);
CREATE TABLE IF NOT EXISTS user_penalties (...);
ALTER TABLE users ADD COLUMN IF NOT EXISTS no_show_count INTEGER DEFAULT 0;
-- etc.
```

#### Migration 2: Token Deduction au démarrage

Copier et exécuter le contenu de:
`supabase/migrations/20260108000002_change_token_deduction_to_trip_start.sql`

**Résumé**:

- Désactive l'ancien trigger (déduction à l'acceptation)
- Crée nouveau trigger: déduction quand `status = 'started'`
- Protège contre No Show passagers

**Commandes clés**:

```sql
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;
CREATE FUNCTION spend_token_on_trip_start() ...
CREATE TRIGGER trigger_spend_token_on_trip_start ...
```

#### Migration 3: Fix User Creation (IMPORTANT pour votre bug!)

Copier et exécuter le contenu de:
`supabase/migrations/20260108000003_fix_users_insert_policy_for_signup.sql`

**Résumé**:

- Nouvelle politique RLS pour inscription
- Trigger automatique `handle_new_user()`
- **Corrige l'erreur de création d'utilisateur**

**Commandes clés**:

```sql
DROP POLICY IF EXISTS "Users can create own profile" ON users;
CREATE POLICY "Users can create profile during signup" ...
CREATE FUNCTION handle_new_user() ...
CREATE TRIGGER on_auth_user_created ...
```

### Étape 3: Vérification

Après avoir exécuté les 3 migrations:

```sql
-- Vérifier que les tables existent
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('no_show_reports', 'user_penalties');

-- Vérifier que les triggers sont actifs
SELECT tgname, tgrelid::regclass, tgenabled
FROM pg_trigger
WHERE tgname IN (
  'trigger_spend_token_on_trip_start',
  'on_auth_user_created'
);

-- Vérifier la nouvelle politique RLS
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'users'
AND policyname LIKE '%signup%';
```

### Étape 4: Mettre à jour l'historique local

Une fois les migrations appliquées manuellement via le dashboard, mettez à jour votre historique local:

```powershell
cd supabase

# Créer un fichier vide pour enregistrer que les migrations sont appliquées
New-Item -ItemType File -Path ".applied_migrations.txt" -Force
Add-Content -Path ".applied_migrations.txt" -Value "20260108000001 - No Show System - Applied manually $(Get-Date)"
Add-Content -Path ".applied_migrations.txt" -Value "20260108000002 - Token Deduction - Applied manually $(Get-Date)"
Add-Content -Path ".applied_migrations.txt" -Value "20260108000003 - User Creation Fix - Applied manually $(Get-Date)"
```

### Étape 5: Tester

**Test 1: Inscription (Fix principal)**

```
1. Ouvrir mobile_driver ou mobile_rider
2. Cliquer "S'inscrire"
3. Remplir le formulaire
4. L'inscription devrait réussir sans erreur RLS!
```

**Test 2: No Show**

```sql
-- Insérer un report No Show de test
INSERT INTO no_show_reports (trip_id, reported_by, reported_user, user_type, reason)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  auth.uid(),
  '00000000-0000-0000-0000-000000000002',
  'rider',
  'Test No Show'
);
```

**Test 3: Trigger token deduction**

```sql
-- Vérifier que le trigger existe
SELECT * FROM pg_trigger WHERE tgname = 'trigger_spend_token_on_trip_start';
```

## Alternative: Reset complet (si problèmes persistent)

Si les migrations échouent, vous pouvez faire un reset complet:

### ⚠️ ATTENTION: Cela supprimera TOUTES les données!

```sql
-- Dashboard Supabase > SQL Editor
-- Exécuter ces commandes UNE PAR UNE

-- 1. Désactiver RLS temporairement
ALTER TABLE no_show_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_penalties DISABLE ROW LEVEL SECURITY;
-- ... pour toutes les tables

-- 2. Supprimer toutes les données (optionnel)
TRUNCATE TABLE no_show_reports CASCADE;
TRUNCATE TABLE user_penalties CASCADE;
-- ... pour toutes les tables

-- 3. Réappliquer toutes les migrations via Dashboard
-- Copier/coller chaque fichier .sql dans l'ordre chronologique
```

## Notes importantes

- **Ordre des migrations**: Respectez l'ordre chronologique (timestamps)
- **Dépendances**: Certaines migrations dépendent des précédentes
- **Transactions**: Le Dashboard Supabase encapsule automatiquement dans une transaction
- **Rollback**: Si erreur, la transaction est annulée automatiquement
- **Backup**: Supabase fait des backups automatiques quotidiens

## Prochaines fois

Pour éviter ce problème à l'avenir:

1. **Toujours tester localement d'abord**:

   ```powershell
   supabase start
   supabase db reset
   ```

2. **Puis pousser vers prod**:

   ```powershell
   supabase db push
   ```

3. **Ou utiliser le dashboard** pour les migrations critiques

## Aide

Si vous rencontrez des erreurs SQL, partagez:

- Le message d'erreur complet
- La migration qui échoue
- Les logs du dashboard Supabase (section "Logs")
