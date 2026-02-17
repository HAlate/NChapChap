# 🔄 Modifications du Système de Jetons - Version Simplifiée

**Date** : 14 décembre 2024  
**Objectif** : Simplifier le système d'achat de jetons avec prix fixe et sécurisation des numéros Mobile Money

---

## 📊 Modifications principales

### 1. Prix fixe : **1 jeton = 20 F CFA**

Tous les packages sont maintenant basés sur ce prix unitaire.

### 2. Packages simplifiés : 2 packs uniquement

| Pack | Jetons | Bonus | Total | Prix | Prix unitaire |
|------|--------|-------|-------|------|---------------|
| **Pack Standard** | 10 | 0 | 10 | 200 F | 20 F/jeton |
| **Pack Pro** | 50 | 20 | 70 | 1000 F | ~14 F/jeton |

### 3. Numéros Mobile Money invisibles

Les numéros de réception Mobile Money ne sont **plus affichés** aux chauffeurs pour des raisons de sécurité.

---

## 🔄 Nouveau flux d'achat

### Avant (ancien système)
```
1. Chauffeur choisit un pack
2. Chauffeur choisit son pays
3. Chauffeur voit les numéros Mobile Money disponibles ❌ (SUPPRIMÉ)
4. Chauffeur sélectionne un numéro Mobile Money ❌ (SUPPRIMÉ)
5. Chauffeur voit les instructions de paiement détaillées ❌ (SUPPRIMÉ)
6. Chauffeur envoie le paiement manuellement
7. Chauffeur confirme l'envoi
8. Attente de validation admin
```

### Après (nouveau système simplifié)
```
1. Chauffeur choisit un pack
2. Chauffeur voit le prix à payer (calculé automatiquement)
3. Chauffeur saisit son numéro de téléphone ✅
4. Chauffeur ajoute une note optionnelle ✅
5. Chauffeur soumet la demande ✅
6. Admin contacte le chauffeur pour le paiement ✅
7. Admin valide après réception du paiement ✅
8. Jetons crédités automatiquement ✅
```

---

## 🛠️ Changements techniques

### Base de données (SQL)

**Fichier** : `supabase/migrations/20231214_token_system.sql`

**Changements** :
```sql
-- AVANT : 4 packages
('Pack Starter', 10, 1000, 0),
('Pack Standard', 25, 2000, 5),
('Pack Pro', 50, 3500, 20),
('Pack Premium', 100, 6000, 60)

-- APRÈS : 2 packages
('Pack Standard', 10, 200, 0),   -- 10 jetons × 20 F = 200 F
('Pack Pro', 50, 1000, 20)       -- 50 jetons × 20 F = 1000 F (+ 20 bonus)
```

### Service (Dart)

**Fichier** : `mobile_driver/lib/services/token_service.dart`

**Nouvelle méthode ajoutée** :
```dart
/// Crée une demande d'achat sans révéler les numéros Mobile Money
Future<TokenPurchase> createPurchaseRequest({
  required String packageId,
  required String senderPhone,
  String? transactionReference,
}) async {
  // Récupère automatiquement un numéro Mobile Money actif (invisible au chauffeur)
  // L'admin verra ce numéro dans le dashboard
  ...
}
```

**Méthode conservée** (pour usage futur si besoin) :
```dart
/// Version originale avec numéro Mobile Money visible
Future<TokenPurchase> createPurchase({
  required String packageId,
  required String mobileMoneyNumberId,
  required String senderPhone,
  String? transactionReference,
}) async { ... }
```

### Interface utilisateur (Widget)

**Fichier** : `mobile_driver/lib/widgets/buy_tokens_widget.dart`

**Éléments supprimés** :
- ❌ `_selectedCountryCode` - Variable d'état
- ❌ `_selectedMobileMoneyNumber` - Variable d'état
- ❌ `_CountrySelector` - Widget de sélection de pays
- ❌ `_MobileMoneyNumberSelector` - Widget de sélection de numéro
- ❌ `_PaymentInstructions` - Widget d'instructions détaillées avec numéro

**Éléments conservés** :
- ✅ `_InstructionStep` - Widget pour les étapes simplifiées

**Nouveau formulaire** :
```dart
// Instructions simplifiées
Container(
  child: Column(
    children: [
      _InstructionStep('1', 'Soumettez votre demande ci-dessous'),
      _InstructionStep('2', 'Un administrateur vous contactera pour finaliser le paiement'),
      _InstructionStep('3', 'Vos jetons seront crédités après validation (sous 24h)'),
    ],
  ),
)

// Champs du formulaire
TextField(
  controller: _phoneController,
  labelText: 'Votre numéro de téléphone *',
  helperText: 'Nous vous contacterons sur ce numéro',
)

TextField(
  controller: _referenceController,
  labelText: 'Note / Commentaire (optionnel)',
  hintText: 'Ex: Préférence de paiement',
)
```

---

## 📱 Expérience utilisateur

### Interface chauffeur

#### Étape 1 : Sélection du pack
```
┌─────────────────────────────────────┐
│ Acheter des jetons        [🪙 25]  │
│ Les jetons sont utilisés pour...   │
├─────────────────────────────────────┤
│ Choisissez un pack                  │
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🪙 Pack Standard                ││
│ │ 10 jetons                       ││
│ │                          200 F  ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🪙 Pack Pro                     ││
│ │ 50 jetons + 20 bonus            ││
│ │                         1000 F  ││
│ │                           [-20%]││
│ └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

#### Étape 2 : Soumission de la demande
```
┌─────────────────────────────────────┐
│ ℹ️ Comment ça marche ?             │
├─────────────────────────────────────┤
│ ① Soumettez votre demande          │
│ ② Un admin vous contactera         │
│ ③ Jetons crédités après validation │
├─────────────────────────────────────┤
│ Votre numéro de téléphone *         │
│ ┌─────────────────────────────────┐│
│ │ 📱 +229 XX XX XX XX             ││
│ └─────────────────────────────────┘│
│ Nous vous contacterons sur ce n°    │
│                                     │
│ Note / Commentaire (optionnel)      │
│ ┌─────────────────────────────────┐│
│ │ 📝 Ex: Préférence de paiement   ││
│ └─────────────────────────────────┘│
│                                     │
│      [Envoyer la demande]           │
└─────────────────────────────────────┘
```

#### Étape 3 : Confirmation
```
┌─────────────────────────────────────┐
│ ✅ Demande envoyée!                │
│                                     │
│ Un administrateur vous contactera   │
│ pour finaliser le paiement.         │
└─────────────────────────────────────┘
```

### Interface admin (à créer)

L'admin recevra les demandes avec :
- Nom du chauffeur
- Pack demandé (ex: Pack Pro - 70 jetons)
- Montant à recevoir (ex: 1000 F)
- Numéro du chauffeur (ex: +229 97 XX XX XX)
- Note du chauffeur (si présente)
- **Numéro Mobile Money de réception** (invisible au chauffeur)

Actions admin :
1. Contacter le chauffeur au numéro fourni
2. Lui communiquer le numéro Mobile Money à utiliser
3. Attendre le paiement
4. Vérifier la réception sur le compte Mobile Money
5. Valider la demande
6. Les jetons sont crédités automatiquement

---

## 🔒 Sécurité améliorée

### Avant
- ❌ Numéros Mobile Money visibles publiquement dans l'app
- ❌ Risque de spam/fraude sur ces numéros
- ❌ Difficulté à changer les numéros sans mise à jour d'app

### Après
- ✅ Numéros Mobile Money cachés aux chauffeurs
- ✅ Admin contrôle quel numéro communiquer
- ✅ Flexibilité totale pour changer les numéros
- ✅ Traçabilité améliorée (admin sait qui doit payer)

---

## ✅ Checklist de déploiement

- [x] Migration SQL mise à jour (2 packages uniquement)
- [x] Service `createPurchaseRequest()` créé
- [x] Widget simplifié (suppression des sélecteurs)
- [x] Widgets inutiles supprimés (_CountrySelector, etc.)
- [ ] Tester la création d'une demande d'achat
- [ ] Tester l'affichage dans l'historique
- [ ] Créer le dashboard admin pour validation
- [ ] Configurer les vrais numéros Mobile Money en base
- [ ] Tester le flux complet avec paiement réel

---

## 🚀 Déploiement

### 1. Exécuter la migration SQL mise à jour
```bash
# Se connecter à Supabase et exécuter :
psql -h <supabase_host> -U postgres -d postgres -f supabase/migrations/20231214_token_system.sql
```

### 2. Configurer les numéros Mobile Money (exemples)
```sql
-- Bénin
UPDATE mobile_money_numbers
SET phone_number = '+229 97 XX XX XX', account_name = 'ZEDGO SERVICES'
WHERE country_code = 'BJ' AND provider = 'MTN Mobile Money';

-- Togo  
UPDATE mobile_money_numbers
SET phone_number = '+228 90 XX XX XX', account_name = 'ZEDGO SERVICES'
WHERE country_code = 'TG' AND provider = 'Flooz';
```

### 3. Tester dans l'app
```dart
// Dans mobile_driver, onglet Compte
// 1. Sélectionner Pack Pro
// 2. Entrer un numéro test
// 3. Soumettre
// 4. Vérifier dans Supabase que la demande est créée avec status='pending'
```

---

## 📞 Support

### FAQ Chauffeurs

**Q : Où sont les numéros Mobile Money pour payer ?**  
R : Pour votre sécurité et la nôtre, vous recevrez les instructions de paiement directement de notre équipe après avoir soumis votre demande.

**Q : Combien de temps pour recevoir mes jetons ?**  
R : Généralement sous 24h. Vous recevrez une notification dès la validation.

**Q : Je n'ai pas reçu d'appel de l'admin**  
R : Vérifiez que vous avez bien entré votre numéro. Contactez le support si besoin.

**Q : Puis-je payer autrement que par Mobile Money ?**  
R : Actuellement, seul le Mobile Money est accepté. D'autres moyens seront ajoutés prochainement.

---

## 🔄 Évolutions futures possibles

1. **Paiement automatisé** : Intégration API Mobile Money (MTN, Moov, etc.)
2. **Plus de packs** : Pack Débutant (5 jetons - 100 F)
3. **Offres promotionnelles** : Bonus temporaires lors d'événements
4. **Abonnements** : Pack mensuel avec jetons récurrents
5. **Programme de fidélité** : Bonus pour les gros acheteurs

---

**Version** : 2.0 (Simplifiée)  
**Auteur** : Système ZEDGO  
**Dernière mise à jour** : 14 décembre 2024
