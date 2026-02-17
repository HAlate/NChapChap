# ☑️ CHECKLIST: Application migrations Supabase

Date: 8 janvier 2026  
Objectif: Corriger erreur création utilisateur + Appliquer nouvelles migrations

---

## 📋 ÉTAPES À SUIVRE (30 minutes)

### ✅ Étape 1: Préparation locale (5 min)

- [ ] Ouvrir PowerShell dans le dossier projet
- [ ] Naviguer vers `cd supabase`
- [ ] Exécuter `.\copy_migrations.ps1`
- [ ] Vérifier que 3 fichiers sont dans `migrations_to_apply/`:
  - [ ] `20260108000001_create_no_show_system.sql`
  - [ ] `20260108000002_change_token_deduction_to_trip_start.sql`
  - [ ] `20260108000003_fix_users_insert_policy_for_signup.sql`

### ✅ Étape 2: Accès Dashboard Supabase (2 min)

- [ ] Ouvrir navigateur: https://supabase.com/dashboard
- [ ] Se connecter avec compte
- [ ] Sélectionner projet **UUMO**
- [ ] Cliquer sur **SQL Editor** dans menu gauche

### ✅ Étape 3: Migration 1 - No Show System (5 min)

- [ ] Ouvrir `migrations_to_apply/20260108000001_create_no_show_system.sql` avec notepad
- [ ] Sélectionner TOUT le contenu (Ctrl+A)
- [ ] Copier (Ctrl+C)
- [ ] Dans Dashboard: New Query
- [ ] Coller le SQL (Ctrl+V)
- [ ] Cliquer **RUN** (ou F5)
- [ ] Vérifier: Message vert "Success" (pas d'erreur rouge)
- [ ] ✅ Migration 1 appliquée

**Vérification**:

```sql
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('no_show_reports', 'user_penalties');
-- Doit retourner 2 lignes
```

### ✅ Étape 4: Migration 2 - Token Deduction (5 min)

- [ ] Ouvrir `migrations_to_apply/20260108000002_change_token_deduction_to_trip_start.sql`
- [ ] Copier TOUT le contenu
- [ ] Dashboard: New Query
- [ ] Coller et RUN
- [ ] Vérifier: Success
- [ ] ✅ Migration 2 appliquée

**Vérification**:

```sql
SELECT tgname FROM pg_trigger
WHERE tgname = 'trigger_spend_token_on_trip_start';
-- Doit retourner 1 ligne
```

### ✅ Étape 5: Migration 3 - User Creation Fix (5 min) ⚠️ CRITIQUE

- [ ] Ouvrir `migrations_to_apply/20260108000003_fix_users_insert_policy_for_signup.sql`
- [ ] Copier TOUT le contenu
- [ ] Dashboard: New Query
- [ ] Coller et RUN
- [ ] Vérifier: Success
- [ ] ✅ Migration 3 appliquée
- [ ] **Cette migration corrige l'erreur d'inscription!**

**Vérification**:

```sql
-- Vérifier la politique RLS
SELECT policyname FROM pg_policies
WHERE tablename = 'users'
AND policyname LIKE '%signup%';
-- Doit retourner: "Users can create profile during signup"

-- Vérifier le trigger
SELECT tgname FROM pg_trigger
WHERE tgname = 'on_auth_user_created';
-- Doit retourner 1 ligne
```

### ✅ Étape 6: Tests inscription (8 min)

#### Test Driver (4 min)

- [ ] Ouvrir `mobile_driver` dans simulateur/émulateur
- [ ] Cliquer "S'inscrire"
- [ ] Remplir formulaire:
  - Nom complet: "Test Driver"
  - Téléphone: "+243999999999"
  - Password: "test123456"
  - Type véhicule: "car_standard"
  - Plaque: "AB-123-CD"
- [ ] Cliquer "S'inscrire"
- [ ] **Résultat attendu**: ✅ "Compte créé avec succès!"
- [ ] **Si erreur**: ❌ Voir section Dépannage

#### Test Rider (4 min)

- [ ] Ouvrir `mobile_rider` dans simulateur/émulateur
- [ ] Cliquer "S'inscrire"
- [ ] Remplir formulaire:
  - Nom complet: "Test Rider"
  - Téléphone: "+243888888888"
  - Password: "test123456"
- [ ] Cliquer "S'inscrire"
- [ ] **Résultat attendu**: ✅ "Compte créé avec succès!"
- [ ] **Si erreur**: ❌ Voir section Dépannage

### ✅ Étape 7: Vérification finale (2 min)

**Vérifier dans Dashboard Supabase**:

- [ ] Aller dans **Table Editor** → **users**
- [ ] Voir les 2 nouveaux utilisateurs (Test Driver, Test Rider)
- [ ] Vérifier colonnes:
  - [ ] `user_type` = 'driver' et 'rider'
  - [ ] `email` = téléphone + @driver.app / @rider.app
  - [ ] `full_name` = nom saisi

**Vérifier profils**:

- [ ] Table **driver_profiles**: 1 entrée pour Test Driver
- [ ] Colonnes `vehicle_plate`, `vehicle_type` remplies

---

## 🆘 DÉPANNAGE

### ❌ Erreur lors de l'application d'une migration

**Symptôme**: Message rouge dans SQL Editor

**Solutions**:

1. Lire le message d'erreur complet
2. Vérifier que les migrations précédentes sont appliquées
3. Si "relation already exists": Migration déjà appliquée, passer à la suivante
4. Si "syntax error": Vérifier que TOUT le fichier a été copié

### ❌ Inscription échoue toujours

**Symptôme**: Erreur RLS dans l'app

**Solutions**:

1. Vérifier que migration 3 est bien appliquée:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```
2. Si trigger manque, réappliquer migration 3
3. Vérifier logs Supabase: Dashboard → Logs → Auth Logs

### ❌ "supabase db push" échoue toujours

**Réponse**: C'est normal! L'historique des migrations est désynchronisé. Utilisez le Dashboard.

**Note**: Une fois toutes les migrations appliquées manuellement, vous pourrez créer un nouveau fichier de migration propre pour les futures modifications.

---

## 📊 RÉSULTAT ATTENDU

Après avoir coché toutes les cases:

- ✅ 3 migrations appliquées dans Supabase
- ✅ Système No Show opérationnel
- ✅ Déduction jeton au démarrage (protection No Show)
- ✅ Inscription Driver fonctionne
- ✅ Inscription Rider fonctionne
- ✅ Trigger crée automatiquement entrées `users`

---

## 📝 NOTES

- ⏱️ **Temps total**: ~30 minutes
- 🔴 **Priorité**: CRITIQUE (bloque inscriptions)
- 📅 **Date limite**: À faire AVANT test production
- 💾 **Backup**: Supabase fait backups auto quotidiens

---

## 📚 DOCUMENTATION

Si besoin d'aide:

- **[SOLUTION_ERREUR_ET_MIGRATIONS.md](SOLUTION_ERREUR_ET_MIGRATIONS.md)**: Résumé visuel
- **[GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md](GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md)**: Guide détaillé
- **[FIX_USER_CREATION_ERROR.md](FIX_USER_CREATION_ERROR.md)**: Explication technique

---

**Status**: [ ] À FAIRE → [ ] EN COURS → [✅] TERMINÉ

Date d'application: ******\_\_\_******  
Testé par: ******\_\_\_******  
Résultat: ******\_\_\_******
