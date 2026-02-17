# Correction: Erreur lors de la création d'utilisateur

## Problème identifié

Lors de l'inscription d'un nouvel utilisateur, l'application échouait avec une erreur RLS (Row Level Security).

### Cause

La politique RLS `"Users can create own profile"` utilisait la condition:

```sql
WITH CHECK (id = auth.uid())
```

Pendant le processus `auth.signUp()`:

1. Supabase crée l'utilisateur dans `auth.users`
2. L'application tente d'insérer dans `public.users`
3. **Problème**: À ce moment, `auth.uid()` peut être NULL ou non défini
4. La politique RLS bloque l'insertion

## Solution implémentée

### 1. Migration Supabase (`20260108000003_fix_users_insert_policy_for_signup.sql`)

**Nouvelle politique RLS plus permissive**:

```sql
CREATE POLICY "Users can create profile during signup"
  ON users
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (
    -- L'ID doit exister dans auth.users (sécurité)
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = users.id
    )
    -- OU l'ID correspond à l'utilisateur authentifié
    OR id = auth.uid()
  );
```

**Trigger automatique**:

```sql
CREATE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, phone, full_name, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Utilisateur'),
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'rider')::user_type
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 2. Modifications code Flutter

#### Driver (auth_service.dart)

**Avant**:

```dart
final authResponse = await _supabase.auth.signUp(...);
await _supabase.from('users').insert({...}); // ❌ Échouait
await _supabase.from('driver_profiles').insert({...});
```

**Après**:

```dart
final authResponse = await _supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'phone': phone,
    'full_name': fullName,
    'user_type': 'driver',
  },
);
// ✅ Le trigger crée automatiquement l'entrée dans users
await Future.delayed(const Duration(milliseconds: 500));
await _supabase.from('driver_profiles').insert({...});
```

#### Rider (register_screen.dart)

Même principe - suppression de l'insertion manuelle dans `users`, le trigger le fait automatiquement.

## Avantages de cette solution

1. **Sécurité**: La politique vérifie que l'ID existe dans `auth.users`
2. **Simplicité**: Le code d'inscription est plus simple (moins d'étapes)
3. **Cohérence**: Tous les utilisateurs ont automatiquement une entrée dans `users`
4. **Fiabilité**: Évite les conditions de course (race conditions)
5. **DRY**: Pas de duplication de code entre Driver et Rider

## Migration

### Étapes d'application

1. **Appliquer la migration Supabase**:

```bash
cd supabase
supabase db push
```

Ou via Dashboard Supabase → SQL Editor → Copier/coller le contenu de la migration.

2. **Déployer le code Flutter mis à jour**:

```bash
# Driver
cd mobile_driver
flutter pub get
flutter run

# Rider
cd mobile_rider
flutter pub get
flutter run
```

### Vérification

**Tester l'inscription**:

1. Ouvrir l'app Driver ou Rider
2. Cliquer sur "S'inscrire"
3. Remplir le formulaire
4. L'inscription doit réussir sans erreur RLS

**Vérifier dans Supabase**:

```sql
-- Voir les utilisateurs créés
SELECT id, email, phone, full_name, user_type, created_at
FROM users
ORDER BY created_at DESC
LIMIT 10;

-- Vérifier que auth.users et public.users sont synchronisés
SELECT
  au.id,
  au.email AS auth_email,
  u.email AS public_email,
  u.full_name,
  u.user_type
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
ORDER BY au.created_at DESC
LIMIT 10;
```

## Rollback (si nécessaire)

Si besoin de revenir en arrière:

```sql
-- Supprimer le trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Restaurer l'ancienne politique
DROP POLICY IF EXISTS "Users can create profile during signup" ON users;
CREATE POLICY "Users can create own profile"
  ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());
```

Et remettre l'insertion manuelle dans le code Flutter.

## Notes importantes

- Le délai `Future.delayed(500ms)` laisse le temps au trigger de s'exécuter
- Les métadonnées (`data`) dans `signUp()` sont stockées dans `auth.users.raw_user_meta_data`
- Le trigger utilise `ON CONFLICT DO NOTHING` pour éviter les doublons
- La politique permet à `authenticated` et `anon` d'insérer (nécessaire pendant signup)

## Date de correction

8 janvier 2026
