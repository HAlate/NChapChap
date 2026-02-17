# 🪙 Système de Jetons - Restaurants & Marchands

**Date**: 2025-11-30
**Règle**: ✅ **5 jetons par commande acceptée**

---

## 🎯 Résumé Complet

### Qui Possède des Jetons?

| Utilisateur | Jetons? | Coût | Type de Jeton |
|-------------|---------|------|---------------|
| **Rider** | ❌ NON | - | - |
| **Driver** | ✅ OUI | **1 jeton** / course | `course` |
| **Restaurant** | ✅ OUI | **5 jetons** / commande | `delivery_food` |
| **Marchand** | ✅ OUI | **5 jetons** / commande | `delivery_product` |

---

## 🍽️ Workflow Restaurant

### 1. Rider Commande (GRATUIT)
```
Rider → Sélectionne articles → Valide commande
✅ GRATUIT pour rider
```

### 2. Restaurant Voit Commande (SI balance ≥ 5)
```
IF restaurant.token_balance >= 5:
  ✅ Commandes visibles
ELSE:
  ❌ Doit recharger
```

### 3. Restaurant Accepte Commande
```
Restaurant clique "Accepter"
→ TRIGGER SQL automatique:
   - Vérifie balance >= 5
   - Déduit 5 jetons
   - status = 'confirmed'
   - provider_token_spent = true

✅ Restaurant: -5 jetons
✅ Commande confirmée
```

### 4. Restaurant Refuse Commande
```
Restaurant clique "Refuser"
→ status = 'rejected'

❌ Jetons PAS dépensés
✅ Balance intacte
```

---

## 🔐 Trigger Automatique

```sql
CREATE TRIGGER trigger_spend_tokens_on_order_confirmation
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION spend_tokens_on_order_confirmation();
```

**Fonction:**
- Détecte quand `status` passe à `'confirmed'`
- Détermine type jeton: `delivery_food` ou `delivery_product`
- Vérifie balance >= 5
- Déduit 5 jetons
- Enregistre transaction
- Marque `provider_token_spent = true`

---

## 💰 Packages Jetons

| Package | Jetons | Prix | Prix/Jeton | Commandes |
|---------|--------|------|------------|-----------|
| Starter | 5 | 500 F | 100 F | 1 |
| Populaire | 25 | 2250 F | 90 F | 5 |
| Business | 50 | 4000 F | 80 F | 10 |
| Premium | 100 | 7000 F | 70 F | 20 |
| Pro | 250 | 15000 F | 60 F | 50 |

**Exemple ROI:**
```
Restaurant achète: 50 jetons = 4000 F
10 commandes × 5 jetons = 50 jetons
Revenus: 10 × 8000 F = 80 000 F
Coût jetons: 4000 F
Bénéfice: 76 000 F
ROI: 1900%
```

---

## 📊 États Commande

```
pending → confirmed → preparing → ready → picked_up → delivered
           ↓ 5 jetons
        rejected (jetons intacts)
```

---

## ✅ Implémentation

✅ **Migration créée**: `create_orders_token_deduction_trigger.sql`
✅ **Trigger installé**: Sur table `orders`
✅ **Déduction**: 5 jetons automatique quand `status = 'confirmed'`
✅ **Types**: `delivery_food` (restaurants) et `delivery_product` (marchands)

---

**Règle Simple**: **5 jetons = 1 commande acceptée** (trigger automatique)
