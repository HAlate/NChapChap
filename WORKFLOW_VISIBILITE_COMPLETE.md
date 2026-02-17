# 🔐 Workflow Complet - Visibilité & Commandes

**Date**: 2025-11-30

---

## 🎯 Schéma: Restaurant VISIBLE vs INVISIBLE

### Restaurant VISIBLE (>= 5 jetons)

```
┌─────────────────────────────────────────────┐
│          APP RIDER (Utilisateur)            │
├─────────────────────────────────────────────┤
│                                             │
│  1️⃣ Rider ouvre "Restaurants"               │
│     ✅ Restaurant "Chez Maman" APPARAÎT     │
│                                             │
│  2️⃣ Rider clique sur restaurant             │
│     ✅ Menu ACCESSIBLE                      │
│     ✅ Prix affichés                        │
│     ✅ Peut ajouter au panier               │
│                                             │
│  3️⃣ Rider passe commande                    │
│     ✅ RLS autorise INSERT orders           │
│     ✅ Commande CRÉÉE                       │
│                                             │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│       APP RESTAURANT "Chez Maman"           │
├─────────────────────────────────────────────┤
│                                             │
│  4️⃣ Restaurant REÇOIT commande              │
│     ✅ Notification                         │
│     ✅ Détails commande visibles            │
│     ✅ Peut accepter (coût: 5 jetons)       │
│                                             │
│  5️⃣ Restaurant accepte                      │
│     ⚡ TRIGGER: -5 jetons                   │
│     ✅ Balance: 10 → 5                      │
│     ✅ Encore visible (>= 5)                │
│                                             │
└─────────────────────────────────────────────┘
```

---

### Restaurant INVISIBLE (< 5 jetons)

```
┌─────────────────────────────────────────────┐
│          APP RIDER (Utilisateur)            │
├─────────────────────────────────────────────┤
│                                             │
│  1️⃣ Rider ouvre "Restaurants"               │
│     ❌ Restaurant "Chez Papa" N'APPARAÎT PAS│
│     (filtré par RLS: is_visible = false)    │
│                                             │
│  2️⃣ Rider ne peut PAS cliquer dessus        │
│     ❌ Restaurant invisible dans liste      │
│     ❌ Pas de résultat recherche            │
│                                             │
│  3️⃣ SI rider a URL directe:                 │
│     ❌ Menu INACCESSIBLE (RLS bloque)       │
│     ❌ Message: "Restaurant indisponible"   │
│                                             │
│  4️⃣ SI rider essaie forcer commande:        │
│     ❌ RLS REFUSE INSERT orders             │
│     ❌ Erreur: "Action non autorisée"       │
│                                             │
│  ❌ AUCUNE TRANSACTION POSSIBLE             │
│                                             │
└─────────────────────────────────────────────┘
                     ✗ (BLOQUÉ)
┌─────────────────────────────────────────────┐
│       APP RESTAURANT "Chez Papa"            │
├─────────────────────────────────────────────┤
│                                             │
│  ❌ Restaurant NE REÇOIT AUCUNE commande    │
│     🔴 Badge: "INVISIBLE"                   │
│     ⚠️  "Rechargez pour recevoir commandes" │
│                                             │
│  ✅ Voit commandes existantes               │
│     (en cours de préparation)               │
│                                             │
│  🛒 Bouton "Recharger jetons"               │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 🔒 Protection RLS (Row Level Security)

### Point 1: Liste Restaurants

```sql
-- Requête Rider
SELECT * FROM users 
WHERE user_type = 'restaurant';

-- RLS Policy appliquée automatiquement:
WHERE user_type = 'restaurant' 
AND is_visible = true;  ← Filtre automatique

Résultat:
✅ Restaurants avec >= 5 jetons retournés
❌ Restaurants avec < 5 jetons EXCLUS
```

### Point 2: Accès Menu

```sql
-- Rider essaie voir menu restaurant_id = 'xyz'
SELECT * FROM menu_items 
WHERE restaurant_id = 'xyz';

-- RLS Policy vérifie:
WHERE restaurant_id = 'xyz'
AND EXISTS (
  SELECT 1 FROM users
  WHERE id = 'xyz'
  AND is_visible = true  ← Vérification
);

Résultat:
✅ Si restaurant visible: menu retourné
❌ Si restaurant invisible: AUCUNE ligne (liste vide)
```

### Point 3: Création Commande

```sql
-- Rider essaie créer commande
INSERT INTO orders (
  rider_id,
  provider_id,  -- Restaurant invisible
  items,
  total
);

-- RLS Policy vérifie AVANT insertion:
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = provider_id
    AND is_visible = true  ← Vérification
  )
);

Résultat:
✅ Si restaurant visible: INSERT réussit
❌ Si restaurant invisible: ERROR "new row violates RLS policy"
```

---

## 📱 Workflow Complet: Restaurant Passe de Visible à Invisible

```
Timeline Complète
═════════════════════════════════════════════════════════════

10h00 │ Restaurant "Délices d'Afrique"
      │ Balance: 10 jetons
      │ is_visible: true
      │ 
      │ APP RIDER:
      │ ✅ Restaurant visible dans liste
      │ ✅ Menu accessible
      │ ✅ 15 riders consultent le menu
      │
      ▼

10h30 │ Commande 1 (Rider Alice)
      │ 3 plats, 8500 FCFA
      │ 
      │ Restaurant accepte:
      │ ⚡ TRIGGER: -5 jetons
      │ Balance: 10 → 5
      │ is_visible: true ✅ (encore >= 5)
      │
      ▼

11h00 │ Commande 2 (Rider Bob)
      │ 2 plats, 6000 FCFA
      │
      │ Restaurant accepte:
      │ ⚡ TRIGGER: -5 jetons
      │ Balance: 5 → 0
      │ ⚡ TRIGGER: is_visible = false ❌
      │
      │ CHANGEMENT IMMÉDIAT:
      │ ════════════════════════════════════════════
      │
      ▼

11h00 │ APP RIDER (Instantané):
      │ ❌ Restaurant disparaît de la liste
      │ ❌ 15 riders qui consultaient: erreur
      │ ❌ Recherches: aucun résultat
      │ ❌ Favoris: "indisponible"
      │
      │ APP RESTAURANT:
      │ 🔴 Badge: "INVISIBLE"
      │ ⚠️  Notification: "Vous êtes invisible!"
      │ ⚠️  "Rechargez pour recevoir commandes"
      │
      ▼

11h05 │ Rider Charlie cherche "Délices d'Afrique"
      │ ❌ Aucun résultat (RLS filtre)
      │
      │ Rider David clique favori
      │ ❌ "Restaurant indisponible"
      │
      │ Rider Emma a URL directe
      │ ❌ Menu vide (RLS bloque)
      │
      ▼

11h10 │ Restaurant termine commandes Alice & Bob
      │ ✅ Peut préparer normalement
      │ ✅ Peut livrer normalement
      │ ❌ NE REÇOIT aucune nouvelle commande
      │
      ▼

12h00 │ Restaurant recharge 50 jetons
      │ Balance: 0 → 50
      │ ⚡ TRIGGER: is_visible = true ✅
      │
      │ CHANGEMENT IMMÉDIAT:
      │ ════════════════════════════════════════════
      │
      │ APP RIDER:
      │ ✅ Restaurant RÉAPPARAÎT dans liste
      │ ✅ Menu accessible
      │ ✅ Peut passer commandes
      │
      │ APP RESTAURANT:
      │ 🟢 Badge: "VISIBLE"
      │ ✅ "Peut accepter 10 commandes"
      │
      ▼

12h15 │ Commande 3 (Rider Fatou)
      │ ✅ Commande reçue normalement
      │ ✅ Restaurant peut accepter
```

---

## 🎨 Messages d'Erreur Clairs

### Erreur 1: Rider ne trouve pas restaurant

```dart
// Liste vide (RLS filtre)
if (restaurants.isEmpty) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('Aucun restaurant disponible'),
        Text('Réessayez plus tard'),
      ],
    ),
  );
}
```

### Erreur 2: Rider clique favori restaurant invisible

```dart
try {
  final menu = await supabase
    .from('menu_items')
    .select()
    .eq('restaurant_id', restaurantId);
    
  if (menu.isEmpty) {
    throw Exception('Restaurant indisponible');
  }
} catch (e) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Restaurant indisponible'),
      content: Text(
        'Ce restaurant n\'accepte plus de commandes pour le moment. '
        'Veuillez choisir un autre restaurant.'
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);  // Retour liste
          },
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

### Erreur 3: Rider essaie forcer commande

```dart
try {
  await supabase.from('orders').insert({
    'rider_id': riderId,
    'provider_id': restaurantId,  // Invisible
    'items': items,
  });
} catch (e) {
  // RLS bloque avec erreur "new row violates policy"
  showSnackBar(
    context,
    'Impossible de passer commande. Restaurant indisponible.',
    backgroundColor: Colors.red,
  );
}
```

---

## ✅ Résumé Final

### Question Initiale
> "Le marchand/restaurant quand ils sont invisible il ne peut pas avoir des commandes car le rider ne peut pas accéder aux offres à la transaction."

### Réponse
**✅ EXACT! C'est exactement ce qui est implémenté:**

1. **Rider ne voit PAS le restaurant** (filtré par RLS)
2. **Rider ne peut PAS accéder au menu** (bloqué par RLS)
3. **Rider ne peut PAS créer de commande** (refusé par RLS)
4. **Restaurant ne reçoit AUCUNE nouvelle commande**

**Protection à 3 niveaux:**
- Niveau 1: Liste (RLS filtre invisibles)
- Niveau 2: Menu (RLS bloque accès)
- Niveau 3: Commande (RLS refuse INSERT)

**Garantie base de données:**
- Impossible de contourner
- Automatique
- Fiable à 100%

---

## 🚀 Implémentation

**Backend Supabase**: ✅ 100% Fonctionnel

**Migrations Appliquées:**
1. ✅ Colonne `is_visible`
2. ✅ Trigger mise à jour auto
3. ✅ RLS blocage liste
4. ✅ RLS blocage menu
5. ✅ RLS blocage commandes

**Frontend Flutter à faire:**
- Badge visibilité
- Bannière avertissement
- Messages erreur clairs

---

**Document créé**: 2025-11-30
**Confirmation**: Restaurant invisible = AUCUNE transaction possible ✅
