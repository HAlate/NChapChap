# 🪙 Système de Jetons - Résumé Ultra-Simplifié

**Date**: 2025-11-30

---

## 🎯 Qui a des Jetons?

| Utilisateur | Jetons? | Coût |
|-------------|---------|------|
| **Rider** | ❌ NON | GRATUIT |
| **Driver** | ✅ OUI | **1 jeton** = 1 course |
| **Restaurant** | ✅ OUI | **5 jetons** = 1 commande |
| **Marchand** | ✅ OUI | **5 jetons** = 1 commande |

---

## 💡 Règles Simples

### Riders (GRATUIT)
```
✅ Créer demandes: GRATUIT
✅ Passer commandes: GRATUIT
✅ Négocier: GRATUIT
✅ Annuler: GRATUIT
```

### Drivers (1 jeton)
```
Voir demandes: balance >= 1 (vérifié)
Faire offre: GRATUIT
Négocier: GRATUIT

✅ JETON DÉPENSÉ quand:
   - Rider accepte offre
   - Driver accepte contre-offre

❌ JETON INTACT si:
   - Offre refusée
   - Annulation
```

### Restaurants/Marchands (5 jetons)
```
Voir commandes: balance >= 5 (vérifié)

✅ 5 JETONS DÉPENSÉS quand:
   - Restaurant accepte commande

❌ JETONS INTACTS si:
   - Restaurant refuse
   - Rider annule
```

---

## 🔐 Déduction Automatique

### Drivers
```sql
TRIGGER: trip_offers.status = 'accepted'
→ -1 jeton type 'course'
```

### Restaurants/Marchands
```sql
TRIGGER: orders.status = 'confirmed'
→ -5 jetons type 'delivery_food' ou 'delivery_product'
```

---

## ✅ Résumé Final

**Riders**: 100% GRATUIT
**Drivers**: 1 jeton = 1 course acceptée
**Restaurants/Marchands**: 5 jetons = 1 commande acceptée

**Tous les triggers sont automatiques!**

---

Voir documents détaillés:
- `SYSTEME_JETONS_RESUME.md` - Drivers complet
- `ORDERS_TOKEN_SYSTEM.md` - Restaurants/Marchands complet
