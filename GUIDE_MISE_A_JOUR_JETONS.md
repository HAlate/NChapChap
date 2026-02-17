# 🚀 Guide de Mise à Jour - Système de Jetons Simplifié

## 📋 Résumé des changements

✅ **1 jeton = 20 F CFA** (prix fixe)  
✅ **2 packs uniquement** : Standard (10 jetons - 200 F) et Pro (70 jetons - 1000 F)  
✅ **Numéros Mobile Money cachés** aux chauffeurs pour sécurité  
✅ **Flux simplifié** : demande → contact admin → paiement → validation

---

## 🔄 Fichiers modifiés

### 1. Migration SQL
**Fichier** : `supabase/migrations/20231214_token_system.sql`
- ✅ Packages réduits de 4 à 2
- ✅ Prix ajustés (200 F et 1000 F)

### 2. Service de jetons
**Fichier** : `mobile_driver/lib/services/token_service.dart`
- ✅ Nouvelle méthode `createPurchaseRequest()` sans numéro visible
- ✅ Ancienne méthode `createPurchase()` conservée

### 3. Interface d'achat
**Fichier** : `mobile_driver/lib/widgets/buy_tokens_widget.dart`
- ✅ Suppression sélecteurs de pays et numéros
- ✅ Formulaire simplifié (téléphone + note optionnelle)
- ✅ Instructions claires en 3 étapes

---

## 📦 Étapes de déploiement

### Étape 1 : Mettre à jour la base de données

```bash
# Option A : Via Supabase SQL Editor (RECOMMANDÉ)
# 1. Ouvrir https://supabase.com/dashboard
# 2. Aller dans SQL Editor
# 3. Copier-coller le contenu de supabase/migrations/20231214_token_system.sql
# 4. Exécuter

# Option B : Via ligne de commande
psql -h <votre-supabase-host> -U postgres -d postgres -f supabase/migrations/20231214_token_system.sql
```

**Vérification** :
```sql
-- Vérifier que les packages sont bien créés
SELECT name, token_amount, price_fcfa, bonus_tokens FROM token_packages;

-- Résultat attendu :
--  name            | token_amount | price_fcfa | bonus_tokens
-- -----------------+--------------+------------+--------------
--  Pack Standard   |           10 |        200 |            0
--  Pack Pro        |           50 |       1000 |           20
```

### Étape 2 : Configurer les vrais numéros Mobile Money

```sql
-- IMPORTANT : Remplacer XX XX XX XX par les vrais numéros

-- Bénin
UPDATE mobile_money_numbers
SET 
  phone_number = '+229 97 XX XX XX',
  account_name = 'ZEDGO SERVICES',
  is_active = true
WHERE country_code = 'BJ' AND provider = 'MTN Mobile Money';

UPDATE mobile_money_numbers
SET 
  phone_number = '+229 96 XX XX XX',
  account_name = 'ZEDGO SERVICES',
  is_active = true
WHERE country_code = 'BJ' AND provider = 'Moov Money';

-- Togo
UPDATE mobile_money_numbers
SET 
  phone_number = '+228 90 XX XX XX',
  account_name = 'ZEDGO SERVICES',
  is_active = true
WHERE country_code = 'TG' AND provider = 'Flooz (Moov)';

-- Vérification
SELECT country_name, provider, phone_number, is_active 
FROM mobile_money_numbers 
WHERE is_active = true;
```

### Étape 3 : Compiler et déployer l'app mobile

```bash
cd mobile_driver

# Nettoyer le cache
flutter clean
flutter pub get

# Tester en mode debug
flutter run

# Compiler pour production
flutter build apk --release
# ou
flutter build ios --release
```

### Étape 4 : Tester le flux complet

#### Test 1 : Création d'une demande
1. Ouvrir l'app mobile_driver
2. Aller dans l'onglet "Compte"
3. Trouver le widget "Acheter des jetons"
4. Vérifier l'affichage du solde actuel
5. Sélectionner "Pack Pro"
6. Vérifier que le prix affiché est **1000 F**
7. Entrer un numéro de téléphone test : `+229 97 12 34 56`
8. Ajouter une note : `Test de la nouvelle version`
9. Cliquer sur "Envoyer la demande"
10. Vérifier le message de confirmation

#### Test 2 : Vérification en base de données
```sql
-- Vérifier que la demande a été créée
SELECT 
  tp.created_at,
  dp.full_name as driver_name,
  tp.sender_phone,
  pkg.name as package_name,
  tp.price_paid,
  tp.total_tokens,
  tp.status
FROM token_purchases tp
JOIN driver_profiles dp ON dp.id = tp.driver_id
JOIN token_packages pkg ON pkg.id = tp.package_id
ORDER BY tp.created_at DESC
LIMIT 5;

-- Résultat attendu :
-- Une ligne avec status='pending', price_paid=1000, total_tokens=70
```

#### Test 3 : Historique des achats
1. Dans l'app, naviguer vers l'écran d'historique
2. Vérifier que la demande apparaît avec statut "En attente"
3. Cliquer pour voir les détails
4. Vérifier toutes les informations

#### Test 4 : Validation admin (simulation)
```sql
-- Simuler une validation par un admin
UPDATE token_purchases
SET 
  status = 'validated',
  validated_at = NOW(),
  validated_by = (SELECT id FROM auth.users LIMIT 1)
WHERE sender_phone = '+229 97 12 34 56'
  AND status = 'pending';

-- Vérifier que le solde a été crédité automatiquement (grâce au trigger)
SELECT * FROM driver_token_balance 
WHERE driver_id = (
  SELECT driver_id FROM token_purchases 
  WHERE sender_phone = '+229 97 12 34 56'
  LIMIT 1
);

-- Résultat attendu :
-- total_tokens=70, tokens_available=70, tokens_used=0
```

#### Test 5 : Utilisation de jetons
```dart
// Dans l'app, tester l'utilisation de jetons
final tokenService = ref.read(tokenServiceProvider);

// Vérifier le solde
final balance = await tokenService.getBalance();
print('Solde: ${balance.tokensAvailable} jetons');

// Utiliser 2 jetons
final success = await tokenService.useTokens(
  tokensToUse: 2,
  usageType: 'trip_offer',
  description: 'Test d\'utilisation',
);
print('Utilisation: ${success ? 'OK' : 'KO'}');

// Revérifier le solde
final newBalance = await tokenService.getBalance();
print('Nouveau solde: ${newBalance.tokensAvailable} jetons'); // Devrait être 68
```

---

## 🔍 Vérifications post-déploiement

### ✅ Checklist fonctionnelle

- [ ] Les 2 packages s'affichent correctement
- [ ] Prix corrects : Pack Standard = 200 F, Pack Pro = 1000 F
- [ ] Bonus affiché : Pack Pro = +20 jetons bonus
- [ ] Formulaire simplifié sans sélection de pays/numéro
- [ ] Instructions en 3 étapes affichées
- [ ] Champ téléphone requis fonctionne
- [ ] Champ note optionnel fonctionne
- [ ] Bouton "Envoyer la demande" fonctionne
- [ ] Message de confirmation s'affiche
- [ ] Demande créée en base avec status='pending'
- [ ] Numéro Mobile Money assigné automatiquement (invisible au chauffeur)
- [ ] Historique affiche la demande
- [ ] Détails de la demande accessibles
- [ ] Validation admin crédite automatiquement les jetons
- [ ] Solde mis à jour en temps réel
- [ ] Utilisation de jetons fonctionne

### ✅ Checklist technique

- [ ] Aucune erreur de compilation
- [ ] Aucun warning dans le code
- [ ] Formatage Dart correct
- [ ] Tables créées dans Supabase
- [ ] Triggers fonctionnels
- [ ] RLS (Row Level Security) activée
- [ ] Logs propres (pas d'erreurs dans la console)
- [ ] Performance acceptable (<2s pour charger les packages)

---

## 🐛 Dépannage

### Problème : "Aucun numéro Mobile Money disponible"

**Cause** : Aucun numéro actif en base de données

**Solution** :
```sql
-- Activer au moins un numéro
UPDATE mobile_money_numbers
SET is_active = true
WHERE country_code = 'BJ'
LIMIT 1;
```

### Problème : Les packages ne s'affichent pas

**Cause** : Packages non créés ou inactifs

**Solution** :
```sql
-- Vérifier les packages
SELECT * FROM token_packages;

-- Si vide, les créer
INSERT INTO token_packages (name, description, token_amount, price_fcfa, bonus_tokens, display_order) VALUES
  ('Pack Standard', 'Achat minimum', 10, 200, 0, 1),
  ('Pack Pro', 'Pour les professionnels - 20 jetons bonus', 50, 1000, 20, 2);
```

### Problème : Jetons non crédités après validation

**Cause** : Trigger non fonctionnel

**Solution** :
```sql
-- Vérifier que le trigger existe
SELECT * FROM pg_trigger WHERE tgname = 'trigger_update_token_balance';

-- Si absent, recréer le trigger
CREATE TRIGGER trigger_update_token_balance
AFTER UPDATE ON token_purchases
FOR EACH ROW
EXECUTE FUNCTION update_driver_token_balance();
```

### Problème : Erreur "User not authenticated"

**Cause** : Chauffeur non connecté

**Solution** :
```dart
// Vérifier l'authentification
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
  // Rediriger vers la page de connexion
  context.goNamed('login');
}
```

---

## 📊 Monitoring

### Requêtes utiles pour suivi

```sql
-- Demandes en attente aujourd'hui
SELECT COUNT(*) as demandes_en_attente
FROM token_purchases
WHERE status = 'pending'
  AND created_at::date = CURRENT_DATE;

-- Revenus du jour
SELECT SUM(price_paid) as revenus_jour
FROM token_purchases
WHERE status = 'validated'
  AND validated_at::date = CURRENT_DATE;

-- Taux de validation
SELECT 
  status,
  COUNT(*) as nombre,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pourcentage
FROM token_purchases
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY status;

-- Top chauffeurs acheteurs
SELECT 
  dp.full_name,
  COUNT(tp.id) as nb_achats,
  SUM(tp.total_tokens) as total_jetons
FROM token_purchases tp
JOIN driver_profiles dp ON dp.id = tp.driver_id
WHERE tp.status = 'validated'
GROUP BY dp.id, dp.full_name
ORDER BY total_jetons DESC
LIMIT 10;
```

---

## 🎯 Prochaines étapes

### Court terme (1 semaine)
1. Créer le dashboard admin pour validation des demandes
2. Configurer les notifications push (validation/rejet)
3. Former l'équipe support sur le nouveau flux

### Moyen terme (1 mois)
1. Analyser les données d'utilisation
2. Ajuster les prix si nécessaire
3. Ajouter des offres promotionnelles

### Long terme (3 mois)
1. Intégrer une API de paiement automatique (MTN, Moov)
2. Ajouter d'autres moyens de paiement
3. Créer un système d'abonnement

---

## 📞 Support

**Questions techniques** : Contacter l'équipe dev  
**Configuration Supabase** : Vérifier la documentation Supabase  
**Problèmes de paiement** : Contacter les providers Mobile Money

---

**Version** : 2.0 Simplifiée  
**Date de mise à jour** : 14 décembre 2024  
**Statut** : ✅ Prêt pour déploiement
