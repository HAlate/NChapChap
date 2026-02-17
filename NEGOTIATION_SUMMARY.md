# 🤝 Résumé Système de Négociation

**Date:** 2025-11-29
**Version:** 1.0 FINAL
**Contexte:** Adapté à la réalité africaine

---

## 🎯 Principe Fondamental

### ❌ PAS d'Estimation de Prix

Dans notre système, **AUCUNE estimation de prix n'est affichée**. Les prix sont **proposés par les acteurs** (drivers) et **négociés librement**.

---

## 📊 Les 2 Types de Négociation

### 1️⃣ TRAJETS (Rider ↔ Driver)

```
┌─────────────────────────────────────────────────────┐
│  FLUX: Rider demande → Drivers proposent → Négocie │
└─────────────────────────────────────────────────────┘

Étape 1: Rider demande trajet
   📍 Départ: Lomé Centre
   📍 Destination: Aéroport
   🚗 Véhicule: Voiture

   ❌ PAS de: "Prix estimé 2500-3000 F"
   ❌ PAS de: "Distance 12 km"
   ❌ PAS de: "Durée ~25 min"

   ✅ Message: "Les chauffeurs proposeront leurs prix"

Étape 2: Drivers proposent LEURS prix
   Driver A: 1200 F • 8 min (Kojo)
   Driver B: 1500 F • 5 min (Ama)
   Driver C: 1800 F • 3 min (Kwame)

   ✅ Chaque driver fixe SON prix
   ✅ Basé sur connaissance locale
   ✅ Selon trafic/météo/conditions
   ⚠️ Jeton PAS encore dépensé

Étape 3: Rider voit liste et choisit
   ┌─────────────────────────────────┐
   │ 3 propositions reçues           │
   │                                 │
   │ 👤 Kojo    💰 1200 F  ⏱️ 8min  │
   │ 👤 Ama     💰 1500 F  ⏱️ 5min  │
   │ 👤 Kwame   💰 1800 F  ⏱️ 3min  │
   └─────────────────────────────────┘

   ✅ Compare prix/note/ETA
   ✅ Sélectionne selon priorité

Étape 4: Négociation avec driver sélectionné
   ┌─────────────────────────────────┐
   │ Prix proposé: 1500 F (Ama)      │
   │                                 │
   │ [✓ Accepter 1500 F]             │
   │ [↔ Contre-proposer]             │
   │ [← Choisir autre driver]        │
   └─────────────────────────────────┘

   Option A: Accepte 1500 F
      → Driver dépense 1 jeton ✅
      → Course démarre

   Option B: Contre-propose 1200 F
      → Driver peut accepter → 1 jeton ✅
      → Driver peut refuser → Jeton intact

   Option C: Retour liste
      → Choisit Kojo (1200 F) à la place
```

---

### 2️⃣ LIVRAISONS (Restaurant/Marchand ↔ Driver)

```
┌──────────────────────────────────────────────────────────────┐
│  FLUX: Restaurant demande → Drivers proposent → Négocie PRIX│
└──────────────────────────────────────────────────────────────┘

Étape 1: Restaurant demande livraison
   📦 Commande #4521 prête
   📍 Pickup: Restaurant XYZ, Lomé
   📍 Livraison: Client, Hédzranawoé

   ❌ PAS de: "Prix livraison estimé 400 F"
   ❌ PAS de: "Distance 3.2 km"

   ✅ Message: "Les livreurs proposeront leurs prix"

Étape 2: Drivers proposent LEURS prix de livraison
   Driver A: 350 F • 10 min (Afi)
   Driver B: 400 F • 8 min (Kojo)
   Driver C: 500 F • 5 min (Mensah)

   ✅ Chaque driver fixe SON prix livraison
   ✅ Selon distance/trafic/urgence
   ⚠️ Jeton PAS encore dépensé

Étape 3: Restaurant voit liste et choisit
   ┌─────────────────────────────────┐
   │ 3 livreurs disponibles          │
   │                                 │
   │ 👤 Afi     💰 350 F  ⏱️ 10min  │
   │ 👤 Kojo    💰 400 F  ⏱️ 8min   │
   │ 👤 Mensah  💰 500 F  ⏱️ 5min   │
   └─────────────────────────────────┘

   ✅ Compare prix/note/ETA
   ✅ Choisit selon budget/urgence

Étape 4: NÉGOCIATION PRIX livraison
   ┌─────────────────────────────────┐
   │ Prix proposé: 400 F (Kojo)      │
   │                                 │
   │ [✓ Accepter 400 F]              │
   │ [↔ Proposer autre prix]         │
   │ [← Retour liste]                │
   └─────────────────────────────────┘

   Option A: Accepte 400 F
      → Driver dépense 1 jeton ✅
      → Livraison démarre

   Option B: Contre-propose 350 F
      ┌─────────────────────────────────┐
      │ Votre prix: [350___] F          │
      │ Message: "C'est proche"         │
      │ [Envoyer]                       │
      └─────────────────────────────────┘

      → Kojo peut accepter → 1 jeton ✅
      → Kojo peut refuser → Jeton intact

   Option C: Retour liste
      → Choisit Afi (350 F) à la place
```

---

## 🌍 Pourquoi C'est Adapté à l'Afrique

### 1. Négociation = Culture

```
✅ Pratique courante et attendue
✅ Fait partie des transactions quotidiennes
✅ Relation humaine préservée
✅ Pas de rigidité "occidentale"
```

### 2. Prix Variables Selon Contexte

```
Pluie forte:
   Driver: "Je propose 2000 F (pluie + trafic)"
   ✅ Logique et accepté

Heure pointe:
   Driver A: 1500 F (urgent, proche)
   Driver B: 800 F (pas pressé, loin)
   ✅ Marché s'autorégule naturellement

Longue distance avec retour:
   Driver A: 15,000 F (rentre à vide)
   Driver B: 8,000 F (rentre chez lui)
   ✅ Contexte pris en compte
```

### 3. Connaissance Locale Valorisée

```
✅ Driver connaît secteur mieux qu'algorithme
✅ Sait détours nécessaires
✅ Connaît trafic temps réel
✅ Adapte selon conditions réelles
✅ Pas de sous-paiement algorithmique
```

### 4. Transparence Totale

```
✅ TOUS les prix proposés visibles
✅ Facile de comparer
✅ Pas de surprise
✅ Pas de "surge pricing" opaque
```

---

## 📊 Tableau Récapitulatif

| Transaction | Qui Négocie | Objet Négociation | Jeton Dépensé |
|-------------|-------------|-------------------|---------------|
| **Trajet** | Rider ↔ Driver | **Prix course** | Driver: 1 jeton si accepté |
| **Commande** | Rider → Restaurant | Prix FIXE | Restaurant: 5 jetons si accepte |
| **Livraison** | Restaurant ↔ Driver | **Prix livraison** | Driver: 1 jeton si accepté |

---

## ✅ Avantages du Système

### Pour Riders / Restaurants / Marchands

```
✅ Voit TOUS les prix proposés
✅ Compare facilement
✅ Choisit selon priorité
✅ Peut négocier si besoin
✅ Pas de prix imposé
✅ Comprend différences de prix
```

### Pour Drivers

```
✅ Fixe prix selon contexte réel
✅ Connaissance locale valorisée
✅ Pas d'algorithme qui sous-paie
✅ Peut refuser offres non rentables
✅ Jeton dépensé SEULEMENT si accord
✅ Autonomie préservée
```

### Pour la Plateforme

```
✅ Simple (pas d'algo complexe)
✅ Adapté culture locale
✅ Marché s'autorégule
✅ Moins de contestations
✅ Confiance utilisateurs
✅ Transparent
```

---

## 🎨 Messages UI Clés

### Écran Demande (Rider/Restaurant)

```
💡 "Les chauffeurs/livreurs vous proposeront
    leurs prix. Vous pourrez comparer et négocier."
```

### Écran Proposition (Driver)

```
💡 "Proposez un prix juste tenant compte de:
    • Votre temps de trajet
    • L'état du trafic
    • Les conditions météo
    • Vos frais

⚠️ 1 jeton sera dépensé SEULEMENT si accord final."
```

### Écran Négociation

```
💡 "Vous pouvez accepter le prix ou faire une
    contre-proposition. L'autre partie peut
    accepter ou refuser."
```

---

## 🚫 Ce Qu'on N'Affiche JAMAIS

```
❌ "Prix estimé: X-Y F"
❌ "Distance: X km"
❌ "Durée: ~X min"
❌ Calculs automatiques
❌ Prix "recommandé"
❌ "Prix optimal"
❌ Barre de progression prix
```

---

## 🎯 Règle d'Or

> **PAS d'estimation = PAS de déception**
>
> Les acteurs proposent LEURS prix basés sur LF CFA connaissance.
> La négociation est libre, transparente, et adaptée au contexte local.
> Le jeton n'est dépensé que si l'accord est trouvé.

---

**Document généré:** 2025-11-29
**Version:** 1.0 FINAL
**Statut:** ✅ Production Ready

**Message final:**
> Simple. Transparent. Africain. 🌍
