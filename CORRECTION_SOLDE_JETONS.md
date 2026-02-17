# ✅ Correction Affichage Solde Jetons

**Date:** 14 décembre 2025  
**Problème:** Icône rouge au lieu du solde de jetons  
**Cause:** Utilisation de tables inexistantes (nouvelles tables au lieu des tables existantes)

---

## 🔧 Corrections Apportées

### 1. Adaptation aux Tables Existantes

**Avant:**
```dart
// Utilisait des tables qui n'existent pas:
- driver_token_balance
- token_purchases
- mobile_money_numbers
```

**Après:**
```dart
// Utilise maintenant les tables existantes:
- token_balances (avec token_type='course')
- token_transactions
- token_packages
```

### 2. Fichiers Modifiés

#### A. **token_service.dart**
```dart
// AVANT: Requête incorrecte
.from('driver_token_balance')
.eq('driver_id', driverId)

// APRÈS: Requête correcte
.from('token_balances')
.eq('user_id', driverId)
.eq('token_type', 'course')
```

**Méthodes corrigées:**
- ✅ `getBalance()` - Récupère le solde depuis token_balances
- ✅ `watchBalance()` - Stream temps réel depuis token_balances
- ✅ Mapping correct des champs:
  - `total_purchased` → `totalTokens`
  - `total_spent` → `tokensUsed`
  - `balance` → `tokensAvailable`

#### B. **driver_requests_screen.dart**
```dart
// Ajout gestion d'erreur améliorée
error: (e, s) => GestureDetector(
  onTap: () {
    // Affiche le message d'erreur détaillé
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: ${e.toString()}'),
        action: SnackBarAction(
          label: 'Réessayer',
          onPressed: () => ref.invalidate(tokenBalanceProvider),
        ),
      ),
    );
  },
  child: Icon(Icons.error_outline, color: Colors.red),
),
```

---

## 📊 Structure Base de Données Existante

### Table: `token_balances`
```sql
CREATE TABLE token_balances (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  token_type token_type, -- ENUM: 'course', 'delivery_food', 'delivery_product'
  balance integer DEFAULT 0,
  total_purchased integer DEFAULT 0,
  total_spent integer DEFAULT 0,
  updated_at timestamptz
);
```

### Table: `token_transactions`
```sql
CREATE TABLE token_transactions (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  transaction_type transaction_type, -- ENUM: 'purchase', 'spend', 'refund', 'bonus'
  token_type token_type,
  amount integer,
  balance_before integer,
  balance_after integer,
  reference_id uuid,
  payment_method text,
  notes text,
  created_at timestamptz
);
```

### Table: `token_packages`
```sql
CREATE TABLE token_packages (
  id uuid PRIMARY KEY,
  name text,
  token_type token_type,
  token_amount integer,
  price_fcfa integer,
  bonus_tokens integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz
);
```

---

## 🎯 Fonctions PostgreSQL Existantes

### 1. `add_tokens()` - Ajouter des jetons
```sql
-- Utilisation:
SELECT add_tokens(
  'driver_id',           -- user_id
  'course',              -- token_type
  10,                    -- amount
  'mobile_money',        -- payment_method
  'reference_id'         -- reference_id
);
```

**Ce que fait la fonction:**
1. Crée une entrée dans `token_balances` si inexistante
2. Incrémente `balance` et `total_purchased`
3. Enregistre la transaction dans `token_transactions`

### 2. `spend_driver_token()` - Dépenser un jeton
```sql
-- Utilisation:
SELECT spend_driver_token(
  'driver_id',           -- driver_id
  'course',              -- token_type
  'trip_offer_id',       -- reference_id
  'trip_offer'           -- reference_type
);
```

**Ce que fait la fonction:**
1. Vérifie que le solde est suffisant
2. Décrémente `balance` et incrémente `total_spent`
3. Enregistre la transaction dans `token_transactions`

---

## 🧪 Test de la Correction

### Étape 1: Vérifier la Base de Données

```sql
-- Vérifier que la table token_balances existe
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'token_balances';

-- Vérifier le solde actuel du driver
SELECT 
  u.full_name,
  tb.token_type,
  tb.balance,
  tb.total_purchased,
  tb.total_spent
FROM token_balances tb
JOIN users u ON tb.user_id = u.id
WHERE u.user_type = 'driver';
```

### Étape 2: Créer un Solde de Test

Si aucun driver n'a de jetons, créez un solde de test:

```sql
-- Trouver un driver
SELECT id, full_name FROM users WHERE user_type = 'driver' LIMIT 1;

-- Ajouter 10 jetons de test
SELECT add_tokens(
  'DRIVER_ID_ICI',  -- Remplacer par l'ID du driver
  'course',
  10,
  'test',
  gen_random_uuid()
);

-- Vérifier le résultat
SELECT balance FROM token_balances 
WHERE user_id = 'DRIVER_ID_ICI' AND token_type = 'course';
```

### Étape 3: Tester l'Application

1. **Lancer l'app driver:**
   ```bash
   cd mobile_driver
   flutter run -d <device>
   ```

2. **Se connecter** avec le compte du driver testé

3. **Aller sur "Demandes"** (Requests screen)

4. **Vérifier le badge en haut à droite:**
   - ✅ Badge orange avec le nombre de jetons (ex: "10")
   - ✅ Cliquer dessus pour voir les détails
   - ❌ Icône rouge = erreur (cliquer pour voir le message)

---

## 🐛 Débogage

### Si l'icône rouge persiste:

1. **Cliquer sur l'icône rouge** pour voir le message d'erreur exact

2. **Messages possibles:**

   **a) "User not authenticated"**
   ```
   Solution: Se déconnecter puis se reconnecter
   ```

   **b) "relation 'token_balances' does not exist"**
   ```
   Solution: La table n'existe pas. Vérifier votre base Supabase.
   Les tables devraient déjà exister si vous utilisez la base en production.
   ```

   **c) "permission denied for table token_balances"**
   ```
   Solution: Problème RLS. Vérifier les politiques:
   
   -- Politique RLS pour token_balances
   CREATE POLICY "Users can view own token balances"
   ON token_balances FOR SELECT
   TO authenticated
   USING (auth.uid() = user_id);
   ```

   **d) Aucune donnée retournée (0 jetons affichés)**
   ```
   Normal si le driver n'a jamais acheté de jetons.
   Créer un solde de test avec add_tokens() (voir ci-dessus).
   ```

### Logs de Débogage

Pour voir les logs détaillés:

```bash
# Android
flutter run --verbose | findstr "TokenService"

# iOS
flutter run --verbose | grep "TokenService"
```

**Logs importants:**
- `[TokenService] Error getting balance:` → Détails de l'erreur
- `User not authenticated` → Problème connexion
- `does not exist` → Table manquante

---

## 📱 Affichage Final

### État Normal (avec jetons)
```
┌─────────────────────────────┐
│  Demandes            🪙 25  │ ← Badge orange cliquable
└─────────────────────────────┘
```

**Au clic sur le badge:**
```
Solde: 25 jetons disponibles
Total: 30 | Utilisés: 5
```

### État Chargement
```
┌─────────────────────────────┐
│  Demandes              ⚪   │ ← Spinner de chargement
└─────────────────────────────┘
```

### État Erreur
```
┌─────────────────────────────┐
│  Demandes              ⚠️   │ ← Icône rouge cliquable
└─────────────────────────────┘
```

**Au clic sur l'icône rouge:**
```
Erreur de chargement du solde: [message détaillé]
[Bouton: Réessayer]
```

---

## ✅ Validation

### Checklist de Test

- [ ] Badge orange s'affiche (si jetons > 0)
- [ ] Badge affiche "0" (si pas de jetons)
- [ ] Clic sur badge montre détails corrects
- [ ] Solde se met à jour en temps réel
- [ ] Pas d'icône rouge d'erreur
- [ ] Logs Flutter propres (pas d'erreurs)

### Commandes de Vérification

```bash
# Vérifier que l'app compile
cd mobile_driver
flutter analyze

# Vérifier le formatage
flutter format lib/

# Lancer les tests (si configurés)
flutter test
```

---

## 📝 Prochaines Étapes

### 1. Système d'Achat de Jetons
Le système actuel utilise les fonctions PostgreSQL `add_tokens()`. Pour permettre aux drivers d'acheter des jetons:

**Options:**
- **Admin Dashboard:** Admin ajoute manuellement les jetons après paiement Mobile Money
- **API Backend:** Intégration API Mobile Money (MTN, Moov, etc.)
- **Webhook:** Notification automatique après paiement confirmé

### 2. Utilisation des Jetons
Modifier `driver_offer_service.dart` pour appeler `spend_driver_token()` lors de la création d'une offre:

```dart
// Dans createOffer()
final tokenSpent = await _supabase.rpc('spend_driver_token', params: {
  'p_driver_id': driverId,
  'p_token_type': 'course',
  'p_reference_id': offerId,
  'p_reference_type': 'trip_offer',
});

if (!tokenSpent) {
  throw Exception('Jetons insuffisants');
}
```

### 3. Historique des Transactions
Afficher l'historique complet via `token_transactions`:

```dart
final history = await _supabase
  .from('token_transactions')
  .select()
  .eq('user_id', driverId)
  .eq('token_type', 'course')
  .order('created_at', ascending: false)
  .limit(50);
```

---

## 🔗 Fichiers Modifiés

1. `mobile_driver/lib/services/token_service.dart`
   - Méthode `getBalance()` adaptée
   - Méthode `watchBalance()` adaptée
   - Utilise tables existantes

2. `mobile_driver/lib/features/requests/presentation/screens/driver_requests_screen.dart`
   - Gestion d'erreur améliorée
   - Message détaillé au clic
   - Bouton "Réessayer"

3. **Nouveaux fichiers de documentation:**
   - `CORRECTION_SOLDE_JETONS.md` (ce fichier)
   - `SOLDE_JETONS_DEBUG.md` (guide débogage)

---

## 📞 Support

Si le problème persiste:

1. ✅ Vérifier que les tables existent dans Supabase
2. ✅ Vérifier les politiques RLS
3. ✅ Cliquer sur l'icône rouge pour voir l'erreur exacte
4. ✅ Partager le message d'erreur complet

**Tables requises:**
- ✅ token_balances
- ✅ token_transactions
- ✅ token_packages
- ✅ users

**Fonctions requises:**
- ✅ add_tokens()
- ✅ spend_driver_token()
