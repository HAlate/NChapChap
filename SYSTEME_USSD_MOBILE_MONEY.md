# 📱 Système USSD - Paiement Mobile Money

## 🎯 Principe

Le système génère automatiquement le **code USSD** que le chauffeur doit composer sur son téléphone pour effectuer le paiement Mobile Money.

## 🔧 Comment ça fonctionne

### 1. Pattern USSD avec Placeholders

Chaque opérateur a un **pattern USSD** unique stocké dans la base de données avec des placeholders :

```sql
-- Exemple pour MTN
ussd_pattern = '*133*1*1*{amount}*{code}#'

Placeholders:
- {amount} : Montant à envoyer (ex: 12750)
- {code}   : Code de sécurité (ex: 1234)
- {phone}  : Numéro destinataire (optionnel)
```

### 2. Génération du Code Final

Quand le chauffeur valide le formulaire, le système :

1. **Récupère** le pattern de l'opérateur sélectionné
2. **Remplace** les placeholders par les valeurs réelles
3. **Affiche** le code USSD final dans un dialog

**Exemple concret :**

```dart
Pattern : *133*1*1*{amount}*{code}#
Amount  : 12750
Code    : 1234

Résultat final : *133*1*1*12750*1234#
```

### 3. Affichage au Chauffeur

Le code s'affiche dans un dialog avec :
- ✅ Code USSD en gros, sélectionnable
- ✅ Instructions étape par étape
- ✅ Bouton "Copier" pour copier le code
- ✅ Style monospace pour lisibilité

## 📊 Patterns USSD par Opérateur

### Togo (TG)

| Opérateur | Pattern USSD |
|-----------|--------------|
| MTN Mobile Money | `*133*1*1*{amount}*{code}#` |
| Moov Money | `*555*1*{amount}*{code}#` |
| Togocom Cash | `*900*1*{amount}*{code}#` |

### Bénin (BJ)

| Opérateur | Pattern USSD |
|-----------|--------------|
| MTN Mobile Money | `*133*1*1*{amount}*{code}#` |
| Moov Money | `*555*1*{amount}*{code}#` |
| Celtiis Cash | `*901*{amount}*{code}#` |

### Côte d'Ivoire (CI)

| Opérateur | Pattern USSD |
|-----------|--------------|
| MTN Mobile Money | `*133*1*1*{amount}*{code}#` |
| Moov Money | `*555*1*{amount}*{code}#` |
| Orange Money | `*144*4*1*{amount}*{code}#` |

### Sénégal (SN)

| Opérateur | Pattern USSD |
|-----------|--------------|
| Orange Money | `*144*4*1*{amount}*{code}#` |
| Wave | `*#888#` puis menu |
| Free Money | `*155#` puis menu |

> **Note:** Certains opérateurs (Wave, Free) utilisent des menus interactifs après composition du code initial.

## 💻 Implémentation Code

### Modèle MobileMoneyProvider

```dart
class MobileMoneyProvider {
  final String ussdPattern; // '*133*1*1*{amount}*{code}#'
  
  /// Génère le code USSD final
  String generateUssdCode({
    required int amount,
    required String securityCode,
    String? recipientPhone,
  }) {
    return ussdPattern
        .replaceAll('{amount}', amount.toString())
        .replaceAll('{code}', securityCode)
        .replaceAll('{phone}', recipientPhone ?? phoneNumber);
  }
}
```

### Utilisation dans PaymentBottomSheet

```dart
Future<void> _submitPayment() async {
  // ... validation et insertion en DB
  
  // Générer le code USSD
  final ussdCode = _selectedProvider!.generateUssdCode(
    amount: _totalAmount,
    securityCode: _securityCodeController.text,
  );
  
  // Afficher au chauffeur
  _showUssdCodeDialog(ussdCode);
}

void _showUssdCodeDialog(String ussdCode) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Code USSD à composer'),
      content: SelectableText(
        ussdCode, // *133*1*1*12750*1234#
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      // ...
    ),
  );
}
```

## 🗄️ Base de Données

### Colonne ussd_pattern dans mobile_money_numbers

```sql
-- Ajouter la colonne
ALTER TABLE mobile_money_numbers
ADD COLUMN ussd_pattern text;

-- Mettre à jour les patterns existants
UPDATE mobile_money_numbers
SET ussd_pattern = CASE
  WHEN UPPER(provider) LIKE '%MTN%' THEN '*133*1*1*{amount}*{code}#'
  WHEN UPPER(provider) LIKE '%MOOV%' THEN '*555*1*{amount}*{code}#'
  WHEN UPPER(provider) LIKE '%ORANGE%' THEN '*144*4*1*{amount}*{code}#'
  WHEN UPPER(provider) LIKE '%TOGOCOM%' THEN '*900*1*{amount}*{code}#'
  ELSE '*XXX*{amount}*{code}#'
END;
```

### Insertion avec pattern

```sql
INSERT INTO mobile_money_numbers (
  provider,
  phone_number,
  country_code,
  ussd_pattern,
  is_active
) VALUES (
  'MTN Mobile Money',
  '+228 90 12 34 56',
  'TG',
  '*133*1*1*{amount}*{code}#',
  true
);
```

## 🎬 Workflow Utilisateur Complet

```
┌─────────────────────────────────────────────────────────┐
│ 1. Chauffeur sélectionne Pack (12 000 F)               │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Modal s'ouvre avec montant total (12 750 F)         │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Chauffeur choisit opérateur: MTN                     │
│    Pattern DB: *133*1*1*{amount}*{code}#                │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Chauffeur entre code sécurité: 1234                  │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Clique ENVOYER                                       │
│    → Transaction créée en DB (status: pending)          │
│    → Code USSD généré: *133*1*1*12750*1234#             │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Dialog affiche le code USSD                          │
│                                                          │
│    ┌──────────────────────────────────────┐            │
│    │  📱 Code USSD à composer              │            │
│    │                                       │            │
│    │  *133*1*1*12750*1234#                │            │
│    │                                       │            │
│    │  Instructions:                        │            │
│    │  1. Ouvrez votre clavier              │            │
│    │  2. Composez le code                  │            │
│    │  3. Appuyez sur Appel                 │            │
│    │                                       │            │
│    │  [Fermer]  [Copier]                   │            │
│    └──────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 7. Chauffeur compose le code sur son téléphone          │
│    → Menu Mobile Money s'affiche                        │
│    → Confirme le paiement                               │
│    → Entre son code PIN personnel                       │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 8. Admin reçoit le paiement                             │
│    → Vérifie dans pending_token_purchases                │
│    → Valide: validate_token_purchase(id)                │
│    → Jetons crédités automatiquement                    │
└─────────────────────────────────────────────────────────┘
```

## ⚙️ Configuration Avancée

### Patterns Complexes

Certains opérateurs ont des patterns plus complexes :

```sql
-- Orange Money avec numéro destinataire
ussd_pattern = '*144*4*1*{phone}*{amount}*{code}#'

-- Wave (menu interactif)
ussd_pattern = '*#888#'  -- Puis navigation manuelle
notes = 'Après composition, sélectionner: 1. Envoyer > 2. Vers...'
```

### Fallback Pattern

Si un opérateur n'a pas de pattern défini :

```dart
static String _getDefaultUssdPattern(String name) {
  // ... vérifications par nom
  
  // Fallback générique
  return '*XXX*{amount}*{code}#';
}
```

### Personnalisation par Pays

```sql
-- Pattern spécifique pour MTN Côte d'Ivoire
UPDATE mobile_money_numbers
SET ussd_pattern = '*133*2*{amount}*{code}#'
WHERE provider LIKE '%MTN%' 
  AND country_code = 'CI';
```

## 🔒 Sécurité

### Code de Sécurité
- ✅ Saisi par le chauffeur
- ✅ Utilisé dans le code USSD
- ⚠️ **Jamais stocké en clair** dans la DB
- ✅ Hashé avant insertion (`security_code_hash`)

### Validation

Le code USSD généré est :
1. **Affiché** au chauffeur (peut le copier)
2. **Composé** par le chauffeur sur son téléphone
3. **Validé** par l'opérateur Mobile Money (authentification PIN)

## 🐛 Débogage

### Vérifier le pattern d'un opérateur

```sql
SELECT 
  provider,
  country_code,
  ussd_pattern
FROM mobile_money_numbers
WHERE id = '<operator-id>';
```

### Tester la génération

```dart
final provider = MobileMoneyProvider(
  ussdPattern: '*133*1*1*{amount}*{code}#',
  // ...
);

final code = provider.generateUssdCode(
  amount: 12750,
  securityCode: '1234',
);

print(code); // *133*1*1*12750*1234#
```

### Pattern incorrect?

Si le code USSD ne fonctionne pas :

1. **Vérifier** le pattern dans la DB
2. **Tester** manuellement sur téléphone
3. **Corriger** le pattern :
   ```sql
   UPDATE mobile_money_numbers
   SET ussd_pattern = '*NOUVEAU*PATTERN*{amount}*{code}#'
   WHERE id = '<operator-id>';
   ```

## 📚 Ressources

### Codes USSD Officiels

- **MTN**: Documentation sur [mtn.com](https://www.mtn.com)
- **Moov**: Documentation sur [moov-africa.com](https://www.moov-africa.com)
- **Orange**: Documentation sur [orange.com](https://www.orange.com)

### Variables Supportées

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{amount}` | Montant total | `12750` |
| `{code}` | Code de sécurité | `1234` |
| `{phone}` | Numéro destinataire | `90123456` |

---

**Date**: 15 décembre 2025  
**Auteur**: GitHub Copilot
