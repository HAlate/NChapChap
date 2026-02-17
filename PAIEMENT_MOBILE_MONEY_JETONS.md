# 💳 Système de Paiement Mobile Money - Achat de Jetons

## 📋 Vue d'Ensemble

Système complet de paiement Mobile Money intégré dans l'app mobile_driver permettant l'achat de jetons via différents opérateurs mobiles selon le pays du chauffeur.

## 🎯 Workflow Utilisateur

### 1. Sélection du Pack
- Le chauffeur ouvre l'onglet **Compte**
- Il voit les packs disponibles (Standard, Pro, etc.)
- Il **clique sur un pack** → **Modal de paiement s'ouvre**

### 2. Modal de Paiement Mobile Money

Le modal affiche:

#### Zone Montant (Lecture Seule)
```
┌─────────────────────────────────┐
│  Montant à envoyer              │
│  12 750 FCFA                    │
│                                 │
│  Prix du pack:        12 000 F  │
│  Frais transaction:      750 F  │
└─────────────────────────────────┘
```
- **Montant total** = Prix pack + Frais (2.5%)
- Détails affichés en dessous
- Non éditable

#### Menu Déroulant Opérateur
```
┌─────────────────────────────────┐
│ 🏦 Opérateur Mobile Money       │
│                                 │
│ MTN ▼                          │
└─────────────────────────────────┘
```
- Liste des opérateurs filtrés par **pays du chauffeur**
- Récupéré depuis `driver_profiles.country_code`
- Exemple opérateurs Togo: MTN, Moov, Togocom
- Couleur de branding par opérateur

#### Code de Sécurité (Seul Champ Éditable)
```
┌─────────────────────────────────┐
│ 🔒 Code de Sécurité             │
│                                 │
│ [____] (4 chiffres)             │
└─────────────────────────────────┘
```
- Seul champ modifiable par l'utilisateur
- 4 chiffres requis
- Affiché comme password (masqué)

#### Accusés de Réception
```
☑ SMS Accusé
☐ WhatsApp Accusé
```
- Cases optionnelles
- Permet de recevoir confirmation par SMS/WhatsApp

#### Bouton Validation
```
┌─────────────────────────────────┐
│         ENVOYER                 │
└─────────────────────────────────┘
```

### 3. Soumission du Paiement

Quand le chauffeur clique sur **ENVOYER**:

1. **Validation formulaire**:
   - Code de sécurité présent et valide
   - Opérateur sélectionné

2. **Création transaction** dans `token_purchases`:
   ```sql
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
     security_code_hash,  -- JAMAIS en clair
     sms_notification,
     whatsapp_notification,
     status -- 'pending'
   )
   ```

3. **Confirmation utilisateur**:
   ```
   ✅ Paiement en cours de traitement.
      Vous recevrez une confirmation.
   ```

### 4. Validation Admin

L'administrateur:
1. Consulte la vue `pending_token_purchases`
2. Voit les détails complets de la demande
3. **Valide** le paiement via fonction SQL:
   ```sql
   SELECT validate_token_purchase(
     '<purchase_id>',
     'Paiement vérifié'
   );
   ```
4. → **Jetons automatiquement crédités** au chauffeur

### 5. Accusé de Réception

Le chauffeur reçoit:
- **Notification in-app** (mise à jour temps réel du solde)
- **SMS** si option cochée
- **WhatsApp** si option cochée

## 🗄️ Structure Base de Données

### Table: `driver_profiles` (Modifié)
```sql
ALTER TABLE driver_profiles 
ADD COLUMN country_code text DEFAULT 'TG';
```
- **country_code**: Code pays ISO (TG, BJ, CI, etc.)
- Utilisé pour filtrer les opérateurs disponibles

### Table: `token_purchases` (Nouveau)
```sql
CREATE TABLE token_purchases (
  id uuid PRIMARY KEY,
  driver_id uuid REFERENCES users(id),
  package_id uuid REFERENCES token_packages(id),
  mobile_money_number_id uuid REFERENCES mobile_money_numbers(id),
  
  -- Pack acheté
  token_amount int,
  bonus_tokens int,
  total_tokens int,
  
  -- Finances
  price_paid int,
  transaction_fee int,
  total_amount int,
  
  -- Sécurité
  security_code_hash text,  -- JAMAIS en clair!
  sms_notification boolean,
  whatsapp_notification boolean,
  
  -- Statut
  status text CHECK (status IN (
    'pending',      -- En attente validation admin
    'processing',   -- En cours de traitement
    'completed',    -- Validé, jetons crédités
    'failed',       -- Échec paiement
    'cancelled'     -- Annulé
  )),
  
  -- Timestamps
  created_at timestamptz,
  validated_at timestamptz,
  completed_at timestamptz
);
```

### Vue Admin: `pending_token_purchases`
```sql
CREATE VIEW pending_token_purchases AS
SELECT 
  tp.id,
  u.full_name AS driver_name,
  u.phone AS driver_phone,
  pkg.name AS package_name,
  tp.total_amount,
  mm.provider AS mobile_money_provider,
  mm.phone_number AS payment_number,
  tp.created_at
FROM token_purchases tp
JOIN users u ON tp.driver_id = u.id
JOIN token_packages pkg ON tp.package_id = pkg.id
JOIN mobile_money_numbers mm ON tp.mobile_money_number_id = mm.id
WHERE tp.status = 'pending';
```

## 🔧 Fonctions PostgreSQL

### `validate_token_purchase(purchase_id, admin_notes)`
Valide un achat et crédite les jetons:
```sql
SELECT validate_token_purchase(
  '<purchase-uuid>',
  'Paiement MTN vérifié - Réf: 123456'
);
```
- Change status → `completed`
- Appelle `add_tokens()` pour créditer
- Enregistre timestamp validation

### `cancel_token_purchase(purchase_id, reason)`
Annule une demande:
```sql
SELECT cancel_token_purchase(
  '<purchase-uuid>',
  'Paiement non reçu après 48h'
);
```
- Change status → `cancelled`
- Aucun jeton crédité

## 📱 Architecture Code

### Fichiers Créés

#### 1. `mobile_money_provider.dart`
```dart
class MobileMoneyProvider {
  final String id;
  final String name;        // "MTN Mobile Money"
  final String code;        // "MTN"
  final String countryCode; // "TG"
  final String phoneNumber; // Numéro pour paiement
  final Color color;        // Couleur branding
}
```

#### 2. `payment_bottom_sheet.dart`
```dart
class PaymentBottomSheet extends StatefulWidget {
  final TokenPackage package;
  final TokenService tokenService;
  
  // Affiche:
  // - Montant total (pack + 2.5% frais)
  // - Dropdown opérateurs
  // - TextField code sécurité
  // - Checkboxes SMS/WhatsApp
  // - Bouton ENVOYER
}
```

#### 3. `token_service.dart` (Modifié)
Nouvelles méthodes:
```dart
// Récupère pays du chauffeur
Future<String> getDriverCountryCode()

// Récupère opérateurs filtrés par pays
Future<List<MobileMoneyProvider>> getMobileMoneyProviders()

// Crée demande de paiement
Future<void> createPaymentRequest({
  required String packageId,
  required String providerId,
  required String securityCode,
  required int totalAmount,
  ...
})
```

#### 4. `buy_tokens_widget.dart` (Modifié)
```dart
// AVANT: Clic sur pack → affiche formulaire téléphone
// APRÈS: Clic sur pack → ouvre PaymentBottomSheet

onTap: () => _openPaymentModal(package)
```

## 🎨 UX/UI

### Design du Modal
- **Handle bar** en haut (indicateur swipe)
- **Header** avec icône paiement + nom pack
- **Zone montant** avec gradient vert + shadow
- **Dropdown** avec couleurs branding opérateurs
- **Code sécurité** masqué (dots)
- **Checkboxes** Material Design
- **Bouton** pleine largeur, élevation, loading state
- **Animations** avec `flutter_animate`

### Couleurs Opérateurs
```dart
MTN      → Jaune (#FFCC00)
Moov     → Bleu (#0066CC)
Togocom  → Orange (#FF6600)
Orange   → Orange (#FF6600)
Celtiis  → Vert (#00AA00)
Airtel   → Rouge (#CC0000)
```

## 🔐 Sécurité

### Code de Sécurité
- ⚠️ **JAMAIS stocké en clair**
- Hashé avant insertion: `security_code_hash`
- Utilisé uniquement pour vérification admin

### Row Level Security (RLS)
```sql
-- Drivers voient leurs propres achats
CREATE POLICY token_purchases_select_own
  ON token_purchases FOR SELECT
  USING (auth.uid() = driver_id);

-- Drivers peuvent créer demandes
CREATE POLICY token_purchases_insert_own
  ON token_purchases FOR INSERT
  WITH CHECK (auth.uid() = driver_id);
```

## 📊 Workflow Complet

```
┌──────────────────────────────────────────────────────────┐
│                     CHAUFFF CFA                             │
└──────────────────────────────────────────────────────────┘
  1. Ouvre onglet Compte
  2. Voit solde actuel: 3 jetons
  3. Clique sur "Pack Standard (10 jetons - 12 000 F)"
           ↓
  ┌─────────────────────────────────┐
  │  Modal Paiement s'ouvre         │
  │                                 │
  │  Montant: 12 750 F              │
  │  (12 000 + 750 frais)           │
  │                                 │
  │  Opérateur: [MTN ▼]             │
  │  Code: [••••]                   │
  │  ☑ SMS  ☐ WhatsApp              │
  │                                 │
  │  [ENVOYER]                      │
  └─────────────────────────────────┘
  4. Sélectionne MTN
  5. Entre code: 1234
  6. Coche SMS
  7. Clique ENVOYER
           ↓
  ✅ "Paiement en cours..."

┌──────────────────────────────────────────────────────────┐
│                  BASE DE DONNÉES                          │
└──────────────────────────────────────────────────────────┘
  INSERT INTO token_purchases
    status = 'pending'
    total_amount = 12750
    mobile_money_provider = MTN
    ...

┌──────────────────────────────────────────────────────────┐
│                    ADMINISTRATF CFA                         │
└──────────────────────────────────────────────────────────┘
  1. Consulte pending_token_purchases
  2. Voit demande de Koffi (12 750 F, MTN)
  3. Vérifie paiement reçu
  4. Exécute:
     SELECT validate_token_purchase('<id>')
           ↓
  - status = 'completed'
  - add_tokens(driver_id, 'course', 10)
  - Jetons crédités

┌──────────────────────────────────────────────────────────┐
│                CHAUFFF CFA (Notification)                   │
└──────────────────────────────────────────────────────────┘
  ✅ Solde mis à jour en temps réel: 13 jetons
  📱 SMS: "Votre achat de 10 jetons a été validé"
```

## 🚀 Déploiement

### 1. Migration Base de Données
```bash
# Dans Supabase Dashboard → SQL Editor
# Exécuter: supabase/migrations/20251215_mobile_money_payment.sql
```

### 2. Mise à Jour App Mobile
```bash
cd mobile_driver
flutter pub get
flutter run
```

### 3. Configuration Opérateurs

Ajouter des opérateurs dans `mobile_money_numbers`:
```sql
INSERT INTO mobile_money_numbers (
  provider, 
  phone_number, 
  country_code, 
  is_active
) VALUES
  ('MTN Mobile Money', '+228 XX XX XX XX', 'TG', true),
  ('Moov Money', '+228 XX XX XX XX', 'TG', true),
  ('Togocom Cash', '+228 XX XX XX XX', 'TG', true);
```

### 4. Configurer Pays Chauffeurs

Mettre à jour les profils:
```sql
UPDATE driver_profiles 
SET country_code = 'TG' 
WHERE country_code IS NULL;
```

## 📈 Améliorations Futures

### Phase 2: Automatisation
- **Intégration API Mobile Money**
  - MTN Mobile Money API
  - Moov Money API
  - Orange Money API
- **Webhook de confirmation**
  - Validation automatique paiements
  - Pas besoin d'admin manuel

### Phase 3: Notifications Push
- Notification quand paiement validé
- Historique accessible in-app
- Reçus PDF téléchargeables

### Phase 4: Multi-Devises
- Support XOF, XAF, etc.
- Conversion automatique
- Prix packages par pays

## 🐛 Dépannage

### Aucun opérateur ne s'affiche
**Cause**: `country_code` NULL ou pas d'opérateurs pour ce pays
**Solution**:
```sql
-- Vérifier country_code du chauffeur
SELECT country_code FROM driver_profiles WHERE id = '<driver-id>';

-- Vérifier opérateurs disponibles
SELECT * FROM mobile_money_numbers WHERE country_code = 'TG';
```

### Erreur "User not authenticated"
**Cause**: Session Supabase expirée
**Solution**: Se reconnecter dans l'app

### Paiement bloqué en "pending"
**Cause**: Admin n'a pas validé
**Solution**: Appeler `validate_token_purchase()`

## 📞 Support

Pour questions techniques:
- Voir code source dans `mobile_driver/lib/widgets/payment_bottom_sheet.dart`
- Consulter `token_service.dart` pour logique métier
- Vérifier migration SQL: `supabase/migrations/20251215_mobile_money_payment.sql`

---

**Date de création**: 15 décembre 2025  
**Version**: 1.0  
**Auteur**: GitHub Copilot
