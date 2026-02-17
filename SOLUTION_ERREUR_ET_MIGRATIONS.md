# 🔧 Solution: Erreur création utilisateur + Application migrations

## ❌ Problème rencontré

1. **Erreur RLS lors de l'inscription**: `auth.uid()` était NULL pendant `signUp()`
2. **`supabase db push` échoue**: Désynchronisation historique migrations locale/distante

## ✅ Solutions implémentées

### 1. Fix création utilisateur (Migration 20260108000003)

**Avant**:

```dart
// ❌ Échouait avec erreur RLS
await supabase.auth.signUp(...);
await supabase.from('users').insert({...}); // ERRF CFA ICI
```

**Après**:

```dart
// ✅ Fonctionne - trigger automatique
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'phone': phone,
    'full_name': fullName,
    'user_type': 'driver',
  },
);
// Le trigger handle_new_user() crée automatiquement l'entrée users!
```

**Migration SQL**:

- Nouvelle politique RLS permissive
- Trigger `handle_new_user()` sur `auth.users`
- Création automatique entrée `public.users`

### 2. Application manuelle des migrations

Puisque `supabase db push` échoue, utilisez le **Dashboard Supabase**:

#### 📋 Étapes rapides

1. **Préparer les fichiers**:

   ```powershell
   cd supabase
   .\copy_migrations.ps1
   ```

   ➡️ Les 3 fichiers SQL sont copiés dans `migrations_to_apply/`

2. **Ouvrir Dashboard**:

   - Aller sur https://supabase.com/dashboard
   - Projet: **UUMO**
   - Menu: **SQL Editor**

3. **Appliquer les migrations** (dans l'ordre):

   **a) No Show System**

   ```
   Fichier: 20260108000001_create_no_show_system.sql
   - Ouvrir avec notepad
   - Copier TOUT le contenu
   - Coller dans SQL Editor
   - Cliquer RUN (F5)
   ```

   **b) Token Deduction**

   ```
   Fichier: 20260108000002_change_token_deduction_to_trip_start.sql
   - Même processus
   ```

   **c) User Creation Fix (CRITIQUE)**

   ```
   Fichier: 20260108000003_fix_users_insert_policy_for_signup.sql
   - Même processus
   - ⚠️ Cette migration corrige l'erreur d'inscription!
   ```

4. **Vérifier le succès**:
   - Pas d'erreurs rouges dans SQL Editor
   - Message "Success" ou "Query executed successfully"

## 🧪 Test

Après avoir appliqué les 3 migrations:

**Test inscription Driver**:

```
1. Ouvrir mobile_driver
2. Cliquer "S'inscrire"
3. Remplir: Nom, Téléphone, Password, Plaque
4. Soumettre
5. ✅ Devrait réussir sans erreur RLS!
```

**Test inscription Rider**:

```
1. Ouvrir mobile_rider
2. Cliquer "S'inscrire"
3. Remplir: Nom, Téléphone, Password
4. Soumettre
5. ✅ Devrait réussir sans erreur RLS!
```

**Vérification SQL** (optionnel):

```sql
-- Vérifier que le trigger est actif
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname = 'on_auth_user_created';

-- Vérifier synchronisation auth.users <-> public.users
SELECT
  au.id,
  au.email AS auth_email,
  u.full_name,
  u.user_type
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
ORDER BY au.created_at DESC
LIMIT 5;
```

## 📚 Documentation complète

- **[GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md](GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md)**: Guide détaillé avec screenshots
- **[FIX_USER_CREATION_ERROR.md](FIX_USER_CREATION_ERROR.md)**: Explication technique du fix RLS
- **supabase/migrations_to_apply/README.txt**: Instructions rapides

## 📦 Commits Git

**c35ec73**: Fix création utilisateur (RLS + trigger)

- Migration 20260108000003
- Code Flutter simplifié (driver + rider)
- Documentation

**39d32bf**: Guide + scripts application manuelle

- Documentation complète
- Scripts PowerShell helpers
- Fichiers migrations prêts à copier

## 🆘 Aide

**Si erreur lors de l'application**:

1. Vérifier l'ordre des migrations (respecter 1 → 2 → 3)
2. Vérifier qu'aucune erreur rouge dans SQL Editor
3. Si erreur SQL, consulter [GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md](GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md)
4. Ou partager l'erreur complète pour assistance

**Si inscription échoue toujours**:

1. Vérifier que migration 3 est bien appliquée:
   ```sql
   SELECT policyname FROM pg_policies WHERE tablename = 'users' AND policyname LIKE '%signup%';
   ```
2. Vérifier que le trigger existe:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```

## 🎯 Résultat attendu

Après avoir suivi ces étapes:

- ✅ Les 3 migrations sont appliquées dans Supabase
- ✅ Le trigger crée automatiquement les utilisateurs dans `public.users`
- ✅ L'inscription fonctionne dans Driver et Rider
- ✅ Système No Show opérationnel
- ✅ Protection contre No Show passagers active
- ✅ Déduction jeton au démarrage (pas à l'acceptation)

## 📝 Étapes suivantes

1. **Appliquer les migrations** (30 min max)
2. **Tester l'inscription** (5 min)
3. **Tester une course complète**:
   - Rider crée course
   - Driver fait offre
   - Rider accepte
   - Driver démarre (jeton déduit ici)
   - Driver complète
4. **Vérifier jetons**: Solde driver devrait diminuer de 1

---

**Date**: 8 janvier 2026  
**Statut**: ✅ PRÊT POUR APPLICATION  
**Priorité**: 🔴 CRITIQUE (bloque inscriptions)
