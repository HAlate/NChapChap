# TripScreen - Améliorations de la Logique de Navigation

## Problèmes Corrigés

### 1. ❌ ANCIEN: Navigation vers négociation sans destination
**Problème**: On pouvait accéder à la page de négociation sans destination, ce qui empêche le driver de faire une proposition de prix.

✅ **SOLUTION**: Validation stricte - Le bouton "Continuer" est désactivé si aucune destination n'est sélectionnée.

### 2. ❌ ANCIEN: Confusion sur les boutons rapides
**Problème**:
- "46QP+CH" était fixe (pas dynamique)
- "Localisation actuelle" toujours visible
- "Continuer sans destination" naviguait directement

✅ **SOLUTION**:
- **"Historique" (icône 🕐)**: Affiche la dernière destination utilisée (sauvegardée localement)
- **"Localisation actuelle" (icône 📍)**: Visible UNIQUEMENT si "Autre" est sélectionné dans le dropdown
- **"Choisir destination" (icône 🔍)**: Ouvre le modal de recherche

## Nouveau Flux de Navigation

### Étape 1: Sur TripScreen

**Écran affiche:**
- 🗺️ Carte Google Maps (position actuelle)
- 📍 Adresse de départ (modifiable)
- 🎯 Adresse de destination (TextField cliquable)
- 🔘 Dropdown "Moi même" / "Autre"
- 🔘 Bouton "Continuer vers négociation" (gris/désactivé par défaut)

**Raccourcis disponibles:**
1. **"Choisir destination"** → Ouvre modal de recherche
2. **"[Dernière destination]"** → Remplit le champ avec l'historique (si existe)
3. **"Localisation actuelle"** → Remplit avec position (SEULEMENT si "Autre" sélectionné)

### Étape 2: Sélection de Destination

**Option A - Clic sur "+" ou TextField:**
→ Modal s'ouvre avec:
  - 🔍 Barre de recherche (filtre en temps réel)
  - 📋 Liste des destinations suggérées
  - ❌ Message "Aucune destination trouvée" si recherche vide

→ Sélection d'une destination:
  - ✅ Modal se ferme
  - ✅ TextField se remplit
  - ✅ Bouton "Continuer" devient actif (orange)

**Option B - Clic sur un raccourci:**
→ Remplit directement le TextField
→ Bouton "Continuer" devient actif

### Étape 3: Validation et Navigation

**Bouton "Continuer vers négociation":**

| État | Apparence | Action |
|------|-----------|--------|
| Pas de destination | Gris, désactivé<br>"Sélectionnez une destination" | Rien (bouton non cliquable) |
| Destination sélectionnée | Orange, actif<br>"Continuer vers négociation" | 1. Sauvegarde la destination<br>2. Navigation vers négociation |

**Données transmises à la page négociation:**
```dart
{
  'departure': 'Ma position actuelle',
  'destination': 'Hôtel Sarakawa',
  'vehicleType': 'taxi'
}
```

## Comportement du Dropdown "Commande pour"

### "Moi même" (par défaut)
- ✅ Départ = "Ma position actuelle"
- ✅ Raccourci "Localisation actuelle" **MASQUÉ**
- ✅ Cas d'usage: Je veux aller quelque part

### "Autre"
- ✅ Départ = "Ma position actuelle" (modifiable)
- ✅ Raccourci "Localisation actuelle" **VISIBLE**
- ✅ Cas d'usage: Je commande pour quelqu'un d'autre qui est à un autre endroit

## Stockage Local

### Dernière Destination
**Clé**: `last_destination`
**Service**: `StorageService` (flutter_secure_storage)
**Sauvegarde**: À chaque navigation vers négociation
**Chargement**: Au `initState` du TripScreen

**Exemple:**
```dart
// Sauvegarde
await StorageService.write('last_destination', 'Hôtel Sarakawa');

// Chargement
final lastDest = await StorageService.read('last_destination');
// → "Hôtel Sarakawa"
```

## Validation Stricte

### ⛔ IMPOSSIBLE d'accéder à la page négociation sans destination

**Raisons:**
1. Le driver a besoin de la destination pour calculer le prix
2. Pas de destination = pas de négociation possible
3. Meilleure UX: validation claire en amont

**Mise en œuvre:**
- Bouton désactivé si `_destinationController.text.trim().isEmpty`
- Message visuel: "Sélectionnez une destination"
- Couleur grise pour indiquer l'état désactivé

## Modal de Recherche - Améliorations

### Fonctionnalités
✅ **Barre de recherche**: Filtre en temps réel les suggestions
✅ **Liste dynamique**: Affiche uniquement les résultats correspondants
✅ **État vide**: Message "Aucune destination trouvée" avec icône
✅ **Design cohérent**: Support thème clair/sombre
✅ **Accessibilité**: Semantics labels sur tous les éléments
✅ **Icônes**:
  - 📍 Location_on pour chaque destination
  - ➡️ Arrow_forward_ios pour indiquer la sélection

### Comportement
1. Utilisateur tape dans la recherche
2. Liste se filtre automatiquement (case-insensitive)
3. Clic sur une destination
4. Modal se ferme
5. TextField se remplit
6. Utilisateur peut continuer

## Tests Recommandés

### Scénario 1: Flux Normal
1. ✅ Ouvrir TripScreen
2. ✅ Vérifier que bouton est désactivé
3. ✅ Cliquer sur "Choisir destination"
4. ✅ Sélectionner "Hôtel Sarakawa"
5. ✅ Vérifier que bouton est actif
6. ✅ Cliquer sur "Continuer"
7. ✅ Vérifier navigation vers négociation

### Scénario 2: Historique
1. ✅ Avoir déjà fait une course
2. ✅ Revenir sur TripScreen
3. ✅ Vérifier que raccourci historique s'affiche
4. ✅ Cliquer dessus
5. ✅ Vérifier que destination se remplit

### Scénario 3: "Autre" Mode
1. ✅ Sélectionner "Autre" dans dropdown
2. ✅ Vérifier que "Localisation actuelle" apparaît
3. ✅ Cliquer dessus
4. ✅ Vérifier texte "Position actuelle (Autre personne)"

### Scénario 4: Validation
1. ✅ Essayer de cliquer sur bouton désactivé
2. ✅ Vérifier qu'il ne se passe rien
3. ✅ Vérifier le texte "Sélectionnez une destination"

## Notes Techniques

### Gestion de l'État
- `_destinationController`: TextEditingController pour le champ
- `_lastDestination`: String? pour l'historique
- `_commandePour`: String pour le dropdown
- Utilisation de `setState()` pour refresh UI

### Navigation
- Utilise `GoRouter` avec `context.goNamed('negotiation')`
- Passage de paramètres via `extra`
- Vérification `context.mounted` avant navigation

### Performance
- Chargement asynchrone de l'historique
- Sauvegarde async lors de la navigation
- Filtre de recherche optimisé (pas de rebuild excessif)

## Prochaines Étapes (Optionnel)

### Migration vers Supabase
Au lieu du stockage local, on pourrait:
1. Créer une table `user_trip_history`
2. Sauvegarder toutes les destinations
3. Afficher les 5 dernières destinations
4. Ajouter des statistiques (destinations fréquentes)

### Intégration Google Places API
1. Autocomplete dans le modal de recherche
2. Validation d'adresses en temps réel
3. Affichage sur la carte avant confirmation

### Géolocalisation Temps Réel
1. Mettre à jour "Ma position actuelle" en temps réel
2. Afficher le marqueur de position sur la carte
3. Centrer la carte automatiquement
