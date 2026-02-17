# 🔍 Debug: Icône Rouge Solde Jetons

## ❌ Problème
L'icône rouge avec point d'exclamation s'affiche au lieu du solde de jetons.

## 🔎 Causes Possibles

### 1. Migration Base de Données Non Exécutée ⚠️ CAUSE PROBABLE
La table `driver_token_balance` n'existe pas encore en base de données.

**Solution:**
```bash
# Connectez-vous à Supabase
psql -h <votre-projet>.supabase.co -U postgres -d postgres

# Exécutez la migration
\i supabase/migrations/20231214_token_system.sql

# Ou copiez-collez le contenu SQL directement dans l'éditeur SQL Supabase
```

**Vérification:**
```sql
-- Vérifier que la table existe
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'driver_token_balance';

-- Vérifier les données (devrait être vide au début)
SELECT * FROM driver_token_balance;
```

### 2. Utilisateur Non Authentifié
L'utilisateur n'est pas connecté dans l'application.

**Solution:**
- Déconnectez-vous puis reconnectez-vous
- Vérifiez dans les logs: `flutter run` doit afficher "User authenticated"

**Vérification:**
```dart
// Dans le code, ajoutez temporairement:
debugPrint('Current user: ${Supabase.instance.client.auth.currentUser?.id}');
```

### 3. Problème de Connexion Supabase
L'URL ou la clé Supabase sont incorrectes.

**Solution:**
Vérifiez dans `lib/main.dart`:
```dart
await Supabase.initialize(
  url: 'https://VOTRE-PROJET.supabase.co',
  anonKey: 'VOTRE-CLE-ANON',
);
```

### 4. Règles RLS (Row Level Security)
Les règles RLS bloquent la lecture du solde.

**Vérification SQL:**
```sql
-- Vérifier les politiques RLS
SELECT * FROM pg_policies WHERE tablename = 'driver_token_balance';

-- Désactiver temporairement RLS (DÉVELOPPEMENT UNIQUEMENT)
ALTER TABLE driver_token_balance DISABLE ROW LEVEL SECURITY;

-- Réactiver après test
ALTER TABLE driver_token_balance ENABLE ROW LEVEL SECURITY;
```

## 🛠️ Amélioration Ajoutée

### Message d'Erreur Cliquable
Maintenant, vous pouvez **cliquer sur l'icône rouge** pour voir le message d'erreur détaillé.

**Ce que vous verrez:**
```
Erreur de chargement du solde: [Message d'erreur détaillé]
[Bouton: Réessayer]
```

### Affichage Détails Solde
Vous pouvez aussi **cliquer sur le badge vert** (quand ça marche) pour voir:
```
Solde: X jetons disponibles
Total: Y | Utilisés: Z
```

## 📝 Test Rapide

### Étape 1: Cliquer sur l'Icône Rouge
➡️ Vous verrez le message d'erreur exact

### Étape 2: Identifier le Message
- **"User not authenticated"** → Problème de connexion
- **"relation 'driver_token_balance' does not exist"** → Migration non exécutée
- **"permission denied"** → Problème RLS
- Autre → Vérifier connexion Supabase

### Étape 3: Appliquer la Solution
Voir section "Causes Possibles" ci-dessus.

## 🚀 Solution Rapide Recommandée

**Si c'est la première utilisation:**

1. **Exécutez la migration SQL** (très probablement la cause):
   - Allez sur [Supabase Dashboard](https://supabase.com/dashboard)
   - Sélectionnez votre projet
   - SQL Editor → New query
   - Copiez le contenu de `supabase/migrations/20231214_token_system.sql`
   - Cliquez "Run"

2. **Vérifiez la table:**
   ```sql
   SELECT * FROM driver_token_balance LIMIT 1;
   ```

3. **Rechargez l'app:**
   - Hot restart: `r` dans le terminal flutter
   - Ou redémarrez complètement

4. **Résultat attendu:**
   - Badge orange avec "0" jetons (solde initial vide)
   - Pas d'icône rouge

## 📊 Logs de Débogage

Pour voir exactement ce qui se passe, regardez les logs Flutter:

```bash
flutter run -d windows --verbose | findstr "TokenService"
```

**Messages importants:**
- `[TokenService] Error getting balance:` → Erreur détaillée
- `User not authenticated` → Problème auth
- `does not exist` → Table manquante

## ✅ État Normal

Quand tout fonctionne:
- Badge **orange** avec icône de jeton 🪙
- Nombre de jetons affiché (ex: "0", "10", "25")
- Cliquable pour voir détails
- Pas d'icône rouge

## 🔧 Code Source Modifié

Fichiers mis à jour pour meilleure gestion d'erreur:

1. **driver_requests_screen.dart**
   - Icône d'erreur cliquable avec message détaillé
   - Bouton "Réessayer" pour recharger
   - Badge de solde cliquable pour détails

2. **token_service.dart** (déjà correct)
   - Retourne solde vide (0) si pas de données
   - Gère l'absence d'authentification
   - Logs détaillés pour debug

## 📞 Support

Si le problème persiste après avoir:
1. ✅ Exécuté la migration SQL
2. ✅ Vérifié l'authentification
3. ✅ Cliqué sur l'icône rouge pour voir l'erreur

Partagez le message d'erreur exact qui s'affiche quand vous cliquez sur l'icône rouge.
