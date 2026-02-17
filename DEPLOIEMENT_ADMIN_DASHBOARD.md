# Déploiement Dashboard Admin - Instructions

## 📋 Prérequis

- ✅ Migration `20251215_mobile_money_payment.sql` déjà exécutée
- ✅ Fonctions SQL `validate_token_purchase()` et `cancel_token_purchase()` présentes
- ✅ Application mobile_driver fonctionnelle

---

## 🚀 Étapes de déploiement

### 1. Migration base de données

```bash
# Se connecter à Supabase
cd c:\0000APP\APPZEDGO

# Exécuter la migration pour créer la vue
# Option A : Via Supabase Dashboard
# - Aller dans SQL Editor
# - Copier/coller le contenu de supabase/migrations/20251215_admin_dashboard_view.sql
# - Exécuter

# Option B : Via CLI Supabase (si installé)
supabase db push
```

**Contenu de la migration** :
```sql
-- Crée la vue pending_token_purchases
-- Join de toutes les tables nécessaires
-- Filtre automatique sur status='pending'
```

### 2. Vérifier la vue créée

```sql
-- Dans SQL Editor Supabase
SELECT * FROM pending_token_purchases;

-- Doit retourner :
-- - Colonnes : id, driver_id, driver_name, driver_phone, package_name, 
--   token_amount, total_amount, mobile_money_provider, created_at, etc.
-- - Données : Tous les paiements avec status='pending'
```

### 3. Configurer RLS (Row Level Security)

```sql
-- Permettre lecture de la vue aux utilisateurs authentifiés
-- (À affiner selon vos besoins de sécurité)

-- Option 1 : Accès admin uniquement (recommandé)
CREATE POLICY "Admin can view pending purchases"
ON pending_token_purchases
FOR SELECT
TO authenticated
USING (
  -- Vérifier que l'utilisateur a le rôle admin
  auth.jwt() ->> 'role' = 'admin'
);

-- Option 2 : Accès à tous (temporaire, Phase 1)
CREATE POLICY "All authenticated can view pending purchases"
ON pending_token_purchases
FOR SELECT
TO authenticated
USING (true);
```

**⚠️ Note** : En Phase 1, utiliser Option 2 pour faciliter les tests. Passer à Option 1 avant production.

### 4. Activer Realtime sur token_purchases

```bash
# Dans Supabase Dashboard
# Database → Replication → token_purchases
# Activer "Enable Realtime"

# Ou via SQL :
ALTER PUBLICATION supabase_realtime ADD TABLE token_purchases;
```

### 5. Compiler l'application mobile

```bash
cd mobile_driver

# Nettoyer les builds précédents
flutter clean
flutter pub get

# Vérifier qu'il n'y a pas d'erreurs
flutter analyze

# Compiler pour Android
flutter build apk --release

# Ou pour iOS
flutter build ios --release

# Ou pour tester en dev
flutter run
```

### 6. Tester le dashboard

#### Test 1 : Affichage vide
1. Ouvrir l'app mobile_driver
2. Cliquer "Admin - Paiements"
3. Vérifier message : "Aucun paiement en attente"

#### Test 2 : Créer paiement test
```sql
-- Dans Supabase SQL Editor
INSERT INTO token_purchases (
  driver_id,
  package_id,
  mobile_money_number_id,
  token_amount,
  bonus_tokens,
  total_tokens,
  price_paid,
  transaction_fee,
  total_amount,
  security_code_hash,
  sms_notification,
  whatsapp_notification,
  status
)
SELECT 
  u.id as driver_id,
  pkg.id as package_id,
  mmn.id as mobile_money_number_id,
  pkg.token_amount,
  0 as bonus_tokens,
  pkg.token_amount as total_tokens,
  pkg.price_fcfa as price_paid,
  ROUND(pkg.price_fcfa * 0.025) as transaction_fee,
  ROUND(pkg.price_fcfa * 1.025) as total_amount,
  '1234567' as security_code_hash,
  true as sms_notification,
  false as whatsapp_notification,
  'pending' as status
FROM users u
CROSS JOIN token_packages pkg
CROSS JOIN mobile_money_numbers mmn
WHERE u.role = 'driver'
AND pkg.is_active = true
AND mmn.is_active = true
LIMIT 1;
```

#### Test 3 : Vérifier affichage
1. Retourner dans dashboard admin (ou cliquer 🔄)
2. Paiement doit apparaître automatiquement (Realtime)
3. Vérifier toutes les infos :
   - ✅ Nom du chauffeur
   - ✅ Téléphone
   - ✅ Montant total
   - ✅ Jetons
   - ✅ Opérateur
   - ✅ Timestamp "il y a XX min"

#### Test 4 : Tester validation
1. Cliquer "Valider"
2. Vérifier dialog de confirmation
3. Confirmer
4. Vérifier :
   - ✅ SnackBar vert "X jetons crédités"
   - ✅ Paiement disparaît de la liste
   - ✅ Jetons ajoutés dans token_balances

#### Test 5 : Tester rejet
1. Créer nouveau paiement test (SQL ci-dessus)
2. Cliquer "Refuser"
3. Saisir raison : "Test de rejet"
4. Confirmer
5. Vérifier :
   - ✅ SnackBar orange "Paiement refusé"
   - ✅ Status='cancelled' en DB

---

## 🔐 Sécurisation (avant production)

### 1. Ajouter rôle admin aux utilisateurs

```sql
-- Ajouter colonne role si n'existe pas
ALTER TABLE users ADD COLUMN IF NOT EXISTS role text DEFAULT 'driver';

-- Définir admin
UPDATE users 
SET role = 'admin' 
WHERE email = 'admin@zedgo.com';  -- Remplacer par votre email admin
```

### 2. Vérifier rôle dans l'app

Modifier `driver_home_screen.dart` :

```dart
// Afficher bouton admin seulement si rôle = admin
FutureBuilder<bool>(
  future: _isAdmin(),
  builder: (context, snapshot) {
    if (snapshot.data != true) return SizedBox.shrink();
    
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PendingPurchasesScreen(),
          ),
        );
      },
      icon: const Icon(Icons.admin_panel_settings),
      label: const Text('Admin - Paiements'),
    );
  },
)

// Méthode pour vérifier si admin
Future<bool> _isAdmin() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  
  final response = await Supabase.instance.client
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single();
  
  return response['role'] == 'admin';
}
```

### 3. Appliquer RLS strict

```sql
-- Supprimer policy permissive
DROP POLICY IF EXISTS "All authenticated can view pending purchases" 
ON pending_token_purchases;

-- Créer policy stricte
CREATE POLICY "Admin only can view pending purchases"
ON pending_token_purchases
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  )
);
```

---

## 📊 Monitoring

### Vérifier logs Supabase

```sql
-- Voir les dernières validations
SELECT 
  id,
  driver_id,
  total_amount,
  status,
  created_at,
  validated_at,
  EXTRACT(EPOCH FROM (validated_at - created_at))/60 as minutes_to_validate
FROM token_purchases
WHERE status IN ('completed', 'cancelled')
ORDER BY validated_at DESC
LIMIT 20;
```

### Vérifier logs Flutter

```bash
# En développement
flutter run
# Ouvrir dashboard admin
# Vérifier console pour :
# [AdminTokenService] Found X pending purchases
# [AdminTokenService] Validating purchase: xxx
# [AdminTokenService] Purchase validated successfully
```

---

## 🐛 Dépannage

### Erreur : "No matching view"
```bash
# La vue pending_token_purchases n'existe pas
# Solution : Exécuter migration 20251215_admin_dashboard_view.sql
```

### Erreur : "Function validate_token_purchase does not exist"
```bash
# Solution : Exécuter migration 20251215_mobile_money_payment.sql
```

### Dashboard vide mais paiements existent
```sql
-- Vérifier status des paiements
SELECT status, COUNT(*) 
FROM token_purchases 
GROUP BY status;

-- Si paiements en 'pending' mais pas dans vue :
-- Vérifier que la vue est bien créée
SELECT * FROM pending_token_purchases;
```

### Realtime ne fonctionne pas
```bash
# Vérifier activation Realtime
# Supabase Dashboard → Database → Replication
# token_purchases doit avoir "Enable Realtime" coché

# Vérifier dans l'app :
# Logs doivent montrer : [AdminTokenService] Stream update: X purchases
```

### Bouton admin invisible
```dart
// Vérifier imports dans driver_home_screen.dart
import 'admin/pending_purchases_screen.dart';

// Vérifier que le bouton est bien dans le build()
OutlinedButton.icon(...)
```

---

## ✅ Checklist de déploiement

### Avant mise en production
- [ ] Migration SQL exécutée
- [ ] Vue `pending_token_purchases` créée
- [ ] Fonctions `validate_token_purchase` et `cancel_token_purchase` présentes
- [ ] RLS configuré (Option 2 pour tests, Option 1 pour prod)
- [ ] Realtime activé sur `token_purchases`
- [ ] Application compilée sans erreurs
- [ ] Tests validés (affichage, validation, rejet)
- [ ] Rôle admin assigné aux utilisateurs appropriés
- [ ] Bouton admin sécurisé (vérification rôle)
- [ ] Documentation remise à l'équipe admin

### Post-déploiement
- [ ] Former équipe admin (guide GUIDE_ADMIN_VALIDATION_PAIEMENTS.md)
- [ ] Monitorer premiers paiements
- [ ] Vérifier temps de validation < 5 min
- [ ] Mesurer volume quotidien
- [ ] Planifier Phase 2 si volume > 50/semaine

---

## 📈 Passage en production

### Environnement de staging (recommandé)
1. Dupliquer projet Supabase (staging)
2. Déployer sur staging
3. Tests complets avec données réelles
4. Valider 1 semaine
5. Déployer en production

### Déploiement direct
1. Maintenance app (30 min)
2. Exécuter migrations
3. Déployer nouvelle version app
4. Tests en production (paiement test)
5. Activer pour tous les utilisateurs

---

## 🎓 Formation équipe admin

### Session 1 : Découverte (30 min)
- Démonstration du dashboard
- Workflow complet (de l'achat à la validation)
- Vérification SMS Mobile Money

### Session 2 : Pratique (1h)
- Créer paiements tests
- Valider plusieurs paiements
- Rejeter un paiement
- Gérer cas d'erreur

### Session 3 : Autonomie (30 min)
- Checklist quotidienne
- Résolution de problèmes courants
- Escalation si bug technique

---

## 📞 Support post-déploiement

### Première semaine
- Support technique disponible 9h-18h
- Monitoring quotidien des validations
- Ajustements rapides si nécessaire

### Long terme
- Guide admin accessible (GUIDE_ADMIN_VALIDATION_PAIEMENTS.md)
- Logs Supabase pour diagnostic
- Hotline technique si besoin

---

**Déploiement estimé : 2-3 heures** (migrations + tests + formation)
