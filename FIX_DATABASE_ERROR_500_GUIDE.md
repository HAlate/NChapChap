# 🚨 Fix: Database Error 500 - Nouvel Utilisateur

**Erreur** : "Database error saving new user" avec status code 500  
**Contexte** : Lors de l'inscription (signup) d'un nouvel utilisateur

---

## 🔍 Diagnostic Rapide

### Exécuter ce script dans Supabase SQL Editor:

```sql
-- Voir le fichier: diagnose_database_error_500.sql
```

Ce script va identifier automatiquement le problème parmi :

1. ❌ Fonction `handle_new_user()` manquante ou mal configurée
2. ❌ Trigger `on_auth_user_created` désactivé
3. ❌ Policy RLS INSERT manquante sur `users`
4. ❌ Permissions insuffisantes pour `authenticated`/`anon`

---

## ✅ Solution (Exécution en 2 minutes)

### Étape 1 : Diagnostic

1. Ouvrir **Supabase Dashboard** → SQL Editor
2. Exécuter le fichier : [diagnose_database_error_500.sql](diagnose_database_error_500.sql)
3. Noter les ❌ rouges dans les résultats

### Étape 2 : Correction

1. Toujours dans SQL Editor
2. Exécuter le fichier : [fix_database_error_500_new_user.sql](fix_database_error_500_new_user.sql)
3. Vérifier que tous les checks sont verts ✅

### Étape 3 : Test

1. Redémarrer l'app mobile Flutter
2. Essayer de créer un nouveau compte
3. L'inscription devrait fonctionner ✅

---

## 🛠️ Ce que fait le fix

### 1. Recréer le trigger avec SECURITY DEFINER

```sql
CREATE FUNCTION handle_new_user()
RETURNS trigger
SECURITY DEFINER  -- ← Permet de bypass RLS pendant l'inscription
...
```

**Pourquoi ?** Pendant `auth.signUp()`, l'utilisateur n'a pas encore de session, donc `auth.uid()` = NULL. SECURITY DEFINER permet au trigger de fonctionner quand même.

### 2. Policy RLS permissive pour l'inscription

```sql
CREATE POLICY "Allow insert during signup"
  ON users FOR INSERT
  TO authenticated, anon
  WITH CHECK (
    EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = users.id)
  );
```

**Pourquoi ?** Vérifie que l'ID existe dans `auth.users` (sécurité) mais ne vérifie pas `auth.uid()` qui est NULL.

### 3. Gestion d'erreur robuste

```sql
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Erreur handle_new_user...';
  RETURN NEW;  -- Continue l'inscription même en cas d'erreur
```

**Pourquoi ?** Si une erreur se produit dans le trigger, l'inscription ne sera pas bloquée.

---

## 📋 Causes Fréquentes

### Cause 1 : Trigger sans SECURITY DEFINER

**Symptôme** : Erreur 500 systématique  
**Solution** : Ajouter `SECURITY DEFINER` à la fonction

### Cause 2 : Policy RLS trop restrictive

**Symptôme** : "new row violates row-level security policy"  
**Solution** : Policy doit accepter `anon` role et ne pas vérifier `auth.uid()`

### Cause 3 : Trigger désactivé

**Symptôme** : User créé dans `auth.users` mais pas dans `public.users`  
**Solution** : Recréer le trigger

### Cause 4 : Permissions manquantes

**Symptôme** : "permission denied for table users"  
**Solution** : `GRANT INSERT ON users TO authenticated, anon`

---

## 🔬 Vérification Manuelle

### Dans Supabase Dashboard → SQL Editor:

#### 1. Vérifier la fonction

```sql
SELECT proname, prosecdef
FROM pg_proc
WHERE proname = 'handle_new_user';
-- prosecdef doit être 'true'
```

#### 2. Vérifier le trigger

```sql
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgname = 'on_auth_user_created';
-- tgenabled doit être 'O' (O = Originale/Actif)
```

#### 3. Vérifier les policies

```sql
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'users' AND cmd = 'a';
-- cmd='a' signifie INSERT. Doit retourner au moins 1 ligne
```

#### 4. Vérifier les permissions

```sql
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'users' AND privilege_type = 'INSERT';
-- Doit inclure 'authenticated' et 'anon'
```

---

## 🧪 Tester Manuellement

### Test 1 : Créer un utilisateur via SQL

```sql
-- Simuler une inscription
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'test@uumo.app',
  crypt('Test1234!', gen_salt('bf')),
  NOW(),
  '{"phone": "123456", "full_name": "Test User", "user_type": "rider"}'::jsonb
);

-- Vérifier que l'entrée apparaît dans public.users
SELECT * FROM public.users WHERE email = 'test@uumo.app';
-- Doit retourner 1 ligne créée par le trigger
```

### Test 2 : Via l'app Flutter

```dart
final response = await Supabase.instance.client.auth.signUp(
  email: 'test@uumo.app',
  password: 'Test1234!',
  data: {
    'phone': '123456',
    'full_name': 'Test User',
    'user_type': 'rider',
  },
);

print('User ID: ${response.user?.id}');
// Vérifier dans Supabase Dashboard que l'user est dans les 2 tables
```

---

## 📊 Dashboard Supabase - Vérifications

### 1. Table Editor → auth.users

- L'utilisateur doit apparaître ici après `signUp()`
- Noter l'ID (UUID)

### 2. Table Editor → public.users

- L'utilisateur avec le même ID doit apparaître ici aussi
- Si absent → Le trigger a échoué

### 3. Logs → Postgres Logs

- Chercher "handle_new_user"
- Chercher "ERROR" ou "WARNING"
- Les erreurs du trigger apparaissent ici

---

## 🆘 Si le problème persiste

### Option 1 : Désactiver temporairement RLS

**⚠️ À utiliser uniquement pour tester**

```sql
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
-- Tester l'inscription
-- Puis réactiver:
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
```

### Option 2 : Insertion manuelle dans le code

**Dans auth_service.dart:**

```dart
// Créer dans auth.users
final authResponse = await _supabase.auth.signUp(...);

// Attendre un peu
await Future.delayed(Duration(milliseconds: 500));

// Vérifier si le trigger a fonctionné
final userCheck = await _supabase
    .from('users')
    .select()
    .eq('id', authResponse.user!.id)
    .maybeSingle();

// Si pas présent, créer manuellement
if (userCheck == null) {
  await _supabase.from('users').insert({
    'id': authResponse.user!.id,
    'email': authResponse.user!.email,
    'phone': phone,
    'full_name': fullName,
    'user_type': 'driver',
  });
}
```

### Option 3 : Réinitialiser complètement le système d'auth

```sql
-- ⚠️ DANGER: Supprime tous les utilisateurs!
DELETE FROM public.users;
DELETE FROM auth.users;

-- Puis réexécuter fix_database_error_500_new_user.sql
```

---

## 📝 Fichiers Impliqués

- **Fix principal** : [fix_database_error_500_new_user.sql](fix_database_error_500_new_user.sql)
- **Diagnostic** : [diagnose_database_error_500.sql](diagnose_database_error_500.sql)
- **Migration Supabase** : `supabase/migrations/20260108000003_fix_users_insert_policy_for_signup.sql`
- **Code Flutter Driver** : `mobile_driver/lib/services/auth_service.dart`
- **Code Flutter Rider** : `mobile_rider/lib/features/auth/presentation/screens/register_screen.dart`

---

## 💡 Prévention

Pour éviter ce problème à l'avenir :

1. **Toujours utiliser SECURITY DEFINER** sur les triggers qui modifient des données
2. **Policies RLS permissives** pendant l'inscription (vérifient l'existence mais pas auth.uid())
3. **Gestion d'erreur robuste** dans les triggers (EXCEPTION WHEN OTHERS)
4. **Tests** après chaque modification du schéma

---

**Généré le** : 16 janvier 2026  
**Projet** : CHAPCHAP - Urban Mobility Platform
