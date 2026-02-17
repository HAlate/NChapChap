# ✅ Correction: Logique de Déduction des Jetons

**Date**: 2025-11-30
**Correction appliquée**: Déduction de jeton lors de l'accord final, PAS lors de l'envoi

---

## 🎯 Problème Initial

Dans la première version, le jeton était déduit **immédiatement** après l'envoi de la proposition:

```dart
// ❌ INCORRECT
setState(() {
  _driverTokens--;  // Dépensé trop tôt!
});

Navigator.pop(context);

ScaffoldMessenger.showSnackBar(
  SnackBar(content: Text('Offre envoyée avec succès!')),
);
```

**Problème**:
- Si le rider refuse la proposition → Jeton perdu
- Si négociation échoue → Jeton perdu
- Si rider choisit un autre driver → Jeton perdu
- **Nécessite un système de remboursement complexe** ❌

---

## ✅ Solution Correcte

Le jeton est **vérifié** lors de l'envoi mais **dépensé SEULEMENT lors de l'accord final**.

### Code Corrigé

```dart
// ✅ CORRECT
ElevatedButton.icon(
  onPressed: _driverTokens < 1
      ? null  // Vérifie la disponibilité
      : () {
          // Validation
          if (price == null || price <= 0) return;

          // ❌ PAS de déduction ici!
          // Le jeton sera déduit lors de l'accord final

          Navigator.pop(context);

          ScaffoldMessenger.showSnackBar(
            SnackBar(
              content: Column(
                children: [
                  Text('Proposition envoyée!'),
                  Text('$price FCFA • Arrivée: ${eta}min'),
                  Text('Jeton dépensé si acceptée'),  // ← Clarification
                ],
              ),
            ),
          );
        },
  label: Text('Envoyer la proposition'),
)
```

---

## 📋 Flux Complet (Corrigé)

### Scénario 1: Accord Final (Jeton Dépensé)

```
1. Driver a 5 jetons
   ↓
2. Driver propose 1500 FCFA → Vérifie jetons >= 1 ✅
   ↓
3. Proposition envoyée → Jetons: toujours 5 ✅
   ↓
4. Rider sélectionne driver → Négociation
   ↓
5. Accord final (1500 FCFA accepté)
   ↓
6. ✅ DÉDUCTION: Jetons 5 → 4
   ↓
7. Course démarre
```

### Scénario 2: Refus (Jeton Intact)

```
1. Driver a 5 jetons
   ↓
2. Driver propose 1500 FCFA → Vérifie jetons >= 1 ✅
   ↓
3. Proposition envoyée → Jetons: toujours 5 ✅
   ↓
4. Rider sélectionne driver → Négociation
   ↓
5. Désaccord (driver refuse contre-offre)
   ↓
6. ❌ PAS DE DÉDUCTION: Jetons: toujours 5
   ↓
7. Rider choisit un autre driver
```

### Scénario 3: Jetons Insuffisants

```
1. Driver a 0 jetons
   ↓
2. Driver clique "Faire une offre"
   ↓
3. Modal affiche:
   - Badge: "Vérification: Jeton requis (0 disponibles)"
   - Bouton gris désactivé
   - Message: "Vous n'avez plus de jetons"
   ↓
4. ❌ Impossible d'envoyer
```

---

## 🔄 Changements dans l'UI

### Modal: Avant vs Après

**Avant (Incorrect)**:
```
┌───────────────────────────────────┐
│ Faire une offre                   │
├───────────────────────────────────┤
│ 🪙 Jetons disponibles: 5          │
│    ✓ Disponible                   │
│                                   │
│ Prix: [1500] FCFA                 │
│ ETA: [5] min                      │
│                                   │
│ [Envoyer l'offre (1 jeton)] ←❌  │
└───────────────────────────────────┘

Message après envoi:
"✓ Offre envoyée avec succès!"
Jetons: 5 → 4 ❌ (dépensé trop tôt)
```

**Après (Correct)**:
```
┌───────────────────────────────────┐
│ Faire une offre                   │
├───────────────────────────────────┤
│ ℹ️ Vérification: Jeton requis     │
│    (5 disponibles)                │
│                                   │
│ 🪙 Jeton dépensé SEULEMENT        │
│    si accord final                │
│                                   │
│ Prix: [1500] FCFA                 │
│ ETA: [5] min                      │
│                                   │
│ [Envoyer la proposition] ←✅      │
└───────────────────────────────────┘

Message après envoi:
"✓ Proposition envoyée!
1500 FCFA • Arrivée: 5min
Jeton dépensé si acceptée" ←✅
Jetons: toujours 5 ✅
```

---

## 💡 Avantages de la Correction

### 1. Pas de Remboursement
```
✅ Jeton intact si négociation échoue
✅ Jeton intact si rider choisit autre driver
✅ Jeton intact si proposition rejetée
✅ Pas besoin de système de remboursement complexe
```

### 2. Transparence
```
✅ Message clair: "Jeton dépensé si acceptée"
✅ Driver comprend quand il sera facturé
✅ Pas de surprise
```

### 3. Équité
```
✅ Driver ne perd pas de jeton sans raison
✅ Seules les courses abouties coûtent un jeton
✅ Encourage les drivers à proposer
```

---

## 🔧 Implémentation Backend (À venir)

### Table `trip_offers`

```sql
CREATE TABLE trip_offers (
  id uuid PRIMARY KEY,
  trip_id uuid REFERENCES trips(id),
  driver_id uuid REFERENCES users(id),

  offered_price int NOT NULL,
  counter_price int,
  final_price int,

  status offer_status DEFAULT 'pending',
  token_spent boolean DEFAULT false,  -- ← Important!

  created_at timestamptz DEFAULT now(),
  accepted_at timestamptz  -- ← Moment de la dépense
);
```

### Logique de Déduction

```sql
-- Fonction appelée lors de l'acceptation finale
CREATE FUNCTION spend_token_on_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    -- Déduit 1 jeton
    UPDATE token_balances
    SET balance = balance - 1
    WHERE user_id = NEW.driver_id
      AND token_type = 'course'
      AND balance >= 1;

    -- Marque le jeton comme dépensé
    NEW.token_spent = true;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trigger_spend_token
  BEFORE UPDATE ON trip_offers
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_acceptance();
```

### API Endpoint

```typescript
// POST /trip-offers
{
  "trip_id": "uuid",
  "offered_price": 1500,
  "eta_minutes": 5
}

// Réponse
{
  "id": "offer-uuid",
  "status": "pending",
  "token_spent": false,  // ← Pas encore dépensé
  "message": "Proposition envoyée. Jeton dépensé si acceptée."
}

// PATCH /trip-offers/:id/accept
// Rider accepte → status = 'accepted' → token_spent = true
```

---

## 📊 Comparaison Avant/Après

| Aspect | Avant (Incorrect) | Après (Correct) |
|--------|-------------------|-----------------|
| **Moment dépense** | Envoi proposition | Accord final |
| **Jetons après envoi** | -1 immédiat | Inchangés |
| **Si refus rider** | Jeton perdu ❌ | Jeton intact ✅ |
| **Si négociation échoue** | Jeton perdu ❌ | Jeton intact ✅ |
| **Message utilisateur** | "Offre envoyée" | "Proposition envoyée. Jeton si acceptée" |
| **Remboursement** | Nécessaire ❌ | Pas nécessaire ✅ |
| **Complexité** | Haute | Basse |

---

## 🧪 Tests à Effectuer

### Test 1: Envoi Proposition avec Jetons
```
1. Driver a 5 jetons
2. Envoie proposition 1500 FCFA
3. ✅ Vérifier: Jetons toujours 5
4. ✅ Notification: "Jeton dépensé si acceptée"
```

### Test 2: Accord Final
```
1. Driver a 5 jetons
2. Envoie proposition
3. Rider accepte
4. ✅ Vérifier: Jetons 5 → 4
5. ✅ Course démarre
```

### Test 3: Refus Rider
```
1. Driver a 5 jetons
2. Envoie proposition
3. Rider refuse ou choisit autre driver
4. ✅ Vérifier: Jetons toujours 5
```

### Test 4: Jetons Insuffisants
```
1. Driver a 0 jetons
2. Clique "Faire une offre"
3. ✅ Bouton désactivé
4. ✅ Message: "Jetons insuffisants"
```

---

## 📝 Checklist de Vérification

- [x] ❌ Supprimer `setState(() { _driverTokens--; })` de l'envoi
- [x] ✅ Ajouter message "Jeton dépensé si acceptée"
- [x] ✅ Modifier texte bouton: "Envoyer la proposition"
- [x] ✅ Ajouter badge info dans modal
- [x] ✅ Clarifier moment de dépense
- [x] ✅ Mettre à jour documentation
- [ ] ⏳ Implémenter logique backend (à venir)
- [ ] ⏳ Ajouter trigger Supabase (à venir)
- [ ] ⏳ Tests end-to-end (à venir)

---

## 🎉 Résumé

**Correction appliquée avec succès!**

Le système suit maintenant la logique décrite dans `NEGOTIATION_CONTEXTE_AFRICAIN.md`:

> **Jeton dépensé SEULEMENT SI accepté** (ligne 68-80)

Cette approche:
- ✅ Évite les remboursements complexes
- ✅ Plus équitable pour les drivers
- ✅ Plus simple à implémenter
- ✅ Plus transparent pour l'utilisateur

Le driver peut maintenant envoyer des propositions en toute confiance, sachant que son jeton ne sera dépensé que si la course est acceptée! 🚀
