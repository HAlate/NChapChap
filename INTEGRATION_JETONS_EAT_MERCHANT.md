# Intégration système de jetons - mobile_eat & mobile_merchant

## ✅ Fichiers intégrés

### mobile_eat

#### Modèles (`lib/models/`)
- ✅ `mobile_money_provider.dart` - Opérateurs Mobile Money
- ✅ `pending_token_purchase.dart` - Achats en attente (dashboard admin)

#### Services (`lib/services/`)
- ✅ `token_service.dart` - Service complet de gestion des jetons
- ✅ `admin_token_service.dart` - Service de validation admin

#### Widgets (`lib/widgets/`)
- ✅ `buy_tokens_widget.dart` - Widget d'achat avec packages
- ✅ `payment_bottom_sheet.dart` - Modal de paiement USSD automatique

#### Écrans
- ✅ `lib/features/tokens/presentation/screens/buy_tokens_screen.dart` - Mis à jour pour utiliser BuyTokensWidget
- ✅ `lib/screens/admin/pending_purchases_screen.dart` - Dashboard de validation admin

---

### mobile_merchant

#### Même structure que mobile_eat
- ✅ Tous les fichiers copiés identiquement
- ✅ `buy_tokens_screen.dart` mis à jour
- ✅ Dashboard admin créé

---

## 🔄 Workflow complet (mobile_eat & mobile_merchant)

```
Restaurant/Marchand ouvre l'onglet Compte
         ↓
Clique "Acheter des jetons"
         ↓
Sélectionne un package (ex: 10 jetons, 12,000 F)
         ↓
Modal de paiement s'ouvre
         ↓
Sélectionne opérateur Mobile Money (MTN, Moov, etc.)
         ↓
Entre code de sécurité (4 chiffres)
         ↓
Coche SMS/WhatsApp si souhaité
         ↓
Clique ENVOYER
         ↓
Code USSD généré: *133*1*1*12750*1234#
         ↓
Téléphone ouvre dialer automatiquement
         ↓
Restaurant/Marchand confirme avec PIN
         ↓
Paiement enregistré (status: pending)
         ↓
Admin reçoit SMS Mobile Money
         ↓
Admin ouvre dashboard (bouton admin)
         ↓
Admin valide le paiement
         ↓
Jetons crédités instantanément
         ↓
Balance mise à jour en temps réel
```

---

## 🎨 Interface

### Onglet Compte (déjà existant)
```
Le widget BuyTokensWidget s'affiche dans l'écran:
- Solde actuel
- Packages disponibles
- Bouton pour ouvrir modal
```

### Modal de paiement
```
┌──────────────────────────────┐
│ Pack Standard                │
│ 10 jetons + 2 bonus          │
├──────────────────────────────┤
│ Montant: 12,750 FCFA         │
│ (12,000 + 750 frais 2.5%)    │
├──────────────────────────────┤
│ Opérateur: [MTN ▼]           │
│ Code sécurité: ••••          │
│ ☑ SMS Accusé                 │
│ ☐ WhatsApp                   │
├──────────────────────────────┤
│        [ENVOYER]             │
└──────────────────────────────┘
```

### Dashboard Admin
```
┌─────────────────────────────┐
│ Paiements en attente   [🔄] │
├─────────────────────────────┤
│ En attente: 3    38,250 F   │
├─────────────────────────────┤
│ Restaurant Le Délice        │
│ 12 jetons  💰 12,750 F      │
│ 📱 MTN    il y a 2 min      │
│ [❌ Refuser] [✅ Valider]   │
└─────────────────────────────┘
```

---

## 📝 Adaptations nécessaires

### token_service.dart (à ajuster si besoin)

**Actuellement** : 
- Utilise `token_type = 'course'` (pour chauffeurs)
- Query sur `driver_profiles.country_code`

**Pour mobile_eat** :
- Utiliser `token_type = 'delivery_food'` (déjà existant dans DB)
- Query sur `restaurant_profiles` ou `users.country_code`

**Pour mobile_merchant** :
- Utiliser `token_type = 'marketplace'` (déjà existant dans DB)
- Query sur `merchant_profiles` ou `users.country_code`

### Exemple d'adaptation :

```dart
// Dans token_service.dart pour mobile_eat
Future<String> getDriverCountryCode() async {
  // Renommer en getUserCountryCode()
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return _defaultCountryCode;
  
  final response = await _supabase
      .from('restaurant_profiles')  // Au lieu de driver_profiles
      .select('country_code')
      .eq('id', userId)
      .maybeSingle();
  
  return response?['country_code'] as String? ?? _defaultCountryCode;
}
```

---

## 🔐 Sécurité

### Accès admin
Ajouter bouton admin dans l'écran home (ou compte) pour restaurateurs/marchands admin :

```dart
// Dans restaurant_home_screen.dart ou merchant_home_screen.dart
import '../screens/admin/pending_purchases_screen.dart';

// Ajouter bouton (similaire à mobile_driver)
OutlinedButton.icon(
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
  style: OutlinedButton.styleFrom(
    foregroundColor: Colors.orange,
  ),
),
```

**Note** : Sécuriser avec vérification rôle admin avant production.

---

## 🗄️ Base de données

### Tables existantes (à vérifier)
- ✅ `token_balances` - Soldes par utilisateur
- ✅ `token_transactions` - Historique
- ✅ `token_packages` - Packages disponibles
- ✅ `mobile_money_numbers` - Opérateurs
- ✅ `token_purchases` - Demandes de paiement

### Migrations SQL (déjà exécutées pour driver)
- ✅ `20251215_mobile_money_payment.sql` - Ajout fields USSD
- ✅ `20251215_admin_dashboard_view.sql` - Vue pending_purchases

**Ces migrations fonctionnent pour tous les types d'utilisateurs** (driver, restaurant, merchant) car:
- `token_purchases.driver_id` peut être n'importe quel `users.id`
- La vue `pending_token_purchases` join simplement sur `users`

### Token types dans la DB
```sql
-- Vérifier que ces types existent
SELECT DISTINCT token_type FROM token_balances;

-- Devrait retourner:
-- course (chauffeurs)
-- delivery_food (restaurants)
-- marketplace (marchands)
```

---

## ✅ Checklist d'intégration

### mobile_eat
- [x] Modèles copiés
- [x] Services copiés
- [x] Widgets copiés
- [x] BuyTokensScreen mis à jour
- [x] Dashboard admin créé
- [ ] Ajuster token_type dans token_service.dart
- [ ] Ajouter bouton admin dans home/compte
- [ ] Tester compilation
- [ ] Tester achat complet

### mobile_merchant
- [x] Modèles copiés
- [x] Services copiés
- [x] Widgets copiés
- [x] BuyTokensScreen mis à jour
- [x] Dashboard admin créé
- [ ] Ajuster token_type dans token_service.dart
- [ ] Ajouter bouton admin dans home/compte
- [ ] Tester compilation
- [ ] Tester achat complet

---

## 🚀 Prochaines étapes

1. **Ajuster les services** :
   - Modifier `getDriverCountryCode()` → `getUserCountryCode()`
   - Adapter query selon le type d'utilisateur

2. **Ajouter boutons admin** :
   - Dans `restaurant_home_screen.dart`
   - Dans `merchant_home_screen.dart`

3. **Tester** :
   ```bash
   cd mobile_eat
   flutter pub get
   flutter run
   
   cd mobile_merchant
   flutter pub get
   flutter run
   ```

4. **Vérifier compatibilité DB** :
   - Token types corrects
   - Profiles tables existent (restaurant_profiles, merchant_profiles)

---

## 📊 Avantages

✅ **Uniformité** : Même système pour driver, restaurant, merchant  
✅ **USSD automatique** : Pas de saisie manuelle du code  
✅ **Validation admin** : Contrôle avant crédit  
✅ **Temps réel** : Balance mise à jour instantanément  
✅ **Phase 2 ready** : Prêt pour auto-validation SMS  

---

## 📚 Documentation liée

- **Système complet** : `IMPLEMENTATION_ADMIN_DASHBOARD.md`
- **Guide admin** : `GUIDE_ADMIN_VALIDATION_PAIEMENTS.md`
- **Déploiement** : `DEPLOIEMENT_ADMIN_DASHBOARD.md`
- **Phase 2** : `PHASE2_AUTOMATISATION_SMS.md`
