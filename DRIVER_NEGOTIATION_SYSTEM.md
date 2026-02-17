# 🚗 Système de Négociation Driver - Mobile_driver

## Vue d'Ensemble

Le chauffeur peut voir les demandes disponibles, proposer un prix, et démarrer la négociation avec le client. **Un jeton est requis pour envoyer une offre.**

## Flux de Négociation Driver

### Étape 1: Voir les Demandes

**Écran**: `DriverRequestsScreen`

Le driver voit une liste de demandes disponibles avec:
- 👤 **Nom du client** + ⭐ Note
- 📍 **Trajet**: Départ → Destination
- 📏 **Distance**: km
- 🚕 **Type de véhicule**: moto-taxi, taxi, etc.
- ⏱️ **Il y a**: temps depuis la demande

**En haut**: Badge affichant le nombre de jetons disponibles

```
┌─────────────────────────────────┐
│ Demandes          🪙 5 jetons  │
├─────────────────────────────────┤
│                                 │
│ 👤 Kofi Mensah • ⭐ 4.8        │
│ ⏱️ Il y a 5min    [moto-taxi]  │
│                                 │
│ 🟢 Lomé Centre                 │
│  |                              │
│ 🔴 Aéroport Gnassingbé         │
│                                 │
│ 📏 8.5 km   [Faire une offre]  │
│                                 │
└─────────────────────────────────┘
```

### Étape 2: Faire une Offre (Modal)

Le driver clique sur "Faire une offre" → Modal s'ouvre

**Modal contient:**

1. **Badge Jetons** (en haut)
   - 🪙 Jetons disponibles: 5
   - ✓ Disponible (si >= 1)

2. **Informations du trajet**
   - Départ → Destination
   - Distance

3. **Formulaire**
   - 💰 **Prix proposé (FCFA)*** : champ numérique
   - ⏱️ **Temps d'arrivée (minutes)*** : champ numérique (défaut: 5)

4. **Bouton d'envoi**
   - Si jetons >= 1: "Envoyer l'offre (1 jeton)" - Orange, actif
   - Si jetons < 1: "Jetons insuffisants" - Gris, désactivé

5. **Avertissement** (si jetons < 1)
   - ⚠️ "Vous n'avez plus de jetons. Rechargez pour envoyer des offres."

### Étape 3: Validation et Envoi

**Validation:**
- ❌ Si prix vide → Erreur: "Veuillez entrer un prix"
- ❌ Si prix <= 0 → Erreur: "Prix invalide"
- ✅ Si valide → Envoi de la proposition

**Après envoi:**
1. **PAS de déduction immédiate** - Le jeton est vérifié mais PAS dépensé
2. **Fermeture du modal**
3. **Notification de succès**:
   ```
   ✓ Proposition envoyée!
   1500 FCFA • Arrivée: 5min
   Jeton dépensé si acceptée
   ```

**IMPORTANT**: Le jeton sera déduit **SEULEMENT** quand les deux parties acceptent la course (accord final).

## Logique des Jetons

### Règle Fondamentale
**Pour envoyer une proposition, le driver DOIT avoir au moins 1 jeton disponible.**

**Moment de la dépense:**
- ❌ PAS lors de l'envoi de la proposition
- ✅ SEULEMENT lors de l'accord final (rider + driver acceptent)

**Raison**: Éviter la gestion de remboursements complexes.

### Comportement

| Jetons | État du Bouton | Action |
|--------|----------------|--------|
| 0 | ❌ Désactivé (gris) | Impossible d'envoyer |
| 1+ | ✅ Actif (orange) | Peut envoyer (jeton vérifié, pas dépensé) |

### Affichage des Jetons

**En-tête de liste:**
```dart
Container(
  child: Row(
    children: [
      Icon(Icons.token, color: orange),
      Text('5 jetons'),
    ],
  ),
)
```

**Dans le modal:**
```dart
// Badge info
Container(
  decoration: BoxDecoration(
    color: blue.withOpacity(0.1),
    border: Border.all(color: blue),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, color: blue),
      Text('Vérification: Jeton requis (5 disponibles)'),
    ],
  ),
)

// Note importante
Container(
  decoration: BoxDecoration(
    color: orange.withOpacity(0.05),
    border: Border.all(color: orange),
  ),
  child: Row(
    children: [
      Icon(Icons.token, color: orange),
      Text('Jeton dépensé SEULEMENT si accord final'),
    ],
  ),
)
```

## Messages d'État

### Succès (Vert)
```
✓ Proposition envoyée!
[Prix] FCFA • Arrivée: [ETA]min
Jeton dépensé si acceptée
```

### Avertissement (Orange)
```
⚠️ Veuillez entrer un prix
```

### Erreur (Rouge)
```
⚠️ Prix invalide
```

### Info (Rouge - Pas de jetons)
```
⚠️ Vous n'avez plus de jetons. Rechargez pour envoyer des offres.
```

## Code Clé

### Gestion de l'État
```dart
class _DriverRequestsScreenState extends ConsumerState<DriverRequestsScreen> {
  int _driverTokens = 5; // Nombre de jetons du driver

  void _showOfferDialog(BuildContext context, Map<String, dynamic> request) {
    // Modal pour faire une offre
  }
}
```

### Envoi de la Proposition
```dart
ElevatedButton.icon(
  onPressed: _driverTokens < 1
      ? null  // Désactivé si pas de jetons
      : () {
          // Validation du prix
          if (priceController.text.isEmpty) {
            // Erreur
            return;
          }

          final price = int.tryParse(priceController.text);

          if (price == null || price <= 0) {
            // Erreur
            return;
          }

          // ❌ PAS de déduction ici!
          // Le jeton sera déduit lors de l'accord final

          // Envoie la proposition
          Navigator.pop(context);

          // Notification de succès avec rappel
          ScaffoldMessenger.showSnackBar(
            SnackBar(
              content: Column(
                children: [
                  Text('Proposition envoyée!'),
                  Text('$price FCFA • Arrivée: ${eta}min'),
                  Text('Jeton dépensé si acceptée'),
                ],
              ),
            ),
          );
        },
  icon: Icon(Icons.send),
  label: Text(
    _driverTokens < 1
        ? 'Jetons insuffisants'
        : 'Envoyer la proposition',
  ),
)
```

## Design

### Couleurs
- **Orange** (`AppTheme.primaryOrange`): Jetons, véhicule, bouton principal
- **Vert** (`AppTheme.primaryGreen`): Succès, "Il y a X min"
- **Rouge**: Destination, erreurs
- **Ambre**: Étoiles de notation

### Animations
- **Liste**: `fadeIn` + `slideX` (stagger 100ms)
- **En-tête**: `fadeIn` + `slideY`
- **État vide**: `fadeIn` + `scale`

### Responsive
- **Modal**: `isScrollControlled: true` pour gérer le clavier
- **Padding**: Ajusté selon `MediaQuery.viewInsets.bottom`

## Intégration Supabase (À venir)

### Tables Utilisées
- `trips`: Demandes de trajet (status = 'pending')
- `trip_offers`: Offres des drivers
- `token_balances`: Jetons du driver (type = 'course')

### Politique RLS
Le driver peut créer une offre **SEULEMENT SI** `balance >= 1`:
```sql
CREATE POLICY "Drivers can create trip offers if tokens available"
  ON trip_offers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM token_balances
      WHERE user_id = auth.uid()
        AND token_type = 'course'
        AND balance >= 1
    )
  );
```

### API à Implémenter
```typescript
// GET /trips?status=pending&vehicle_type=moto-taxi
// Récupère les demandes disponibles

// POST /trip-offers
{
  "trip_id": "uuid",
  "offered_price": 1500,
  "eta_minutes": 5
}
// Crée une offre (déduit 1 jeton automatiquement)
```

## Prochaines Étapes

### Phase 1: Backend
1. ✅ Migration Supabase (déjà créée)
2. ⏳ API Backend pour:
   - Récupérer les demandes pending
   - Créer une offre (avec déduction de jeton)
   - Vérifier le solde de jetons

### Phase 2: Frontend
1. ✅ UI Mobile_driver (implémentée)
2. ⏳ Intégration API:
   - Provider pour les demandes
   - Provider pour les jetons
   - Service pour les offres

### Phase 3: Négociation
1. ⏳ Écran de négociation rider (voir les offres)
2. ⏳ Chat de négociation (contre-propositions)
3. ⏳ Acceptation finale

## Tests Recommandés

### Scénario 1: Offre Réussie
1. Driver a 5 jetons
2. Clique sur "Faire une offre"
3. Entre prix: 1500 FCFA
4. Entre ETA: 5 min
5. Clique "Envoyer l'offre"
6. ✅ Jetons: 5 → 4
7. ✅ Notification de succès

### Scénario 2: Validation Prix
1. Driver clique "Faire une offre"
2. Laisse le prix vide
3. Clique "Envoyer"
4. ✅ Erreur: "Veuillez entrer un prix"

### Scénario 3: Jetons Insuffisants
1. Driver a 0 jetons
2. Clique sur "Faire une offre"
3. Badge: "🪙 Jetons disponibles: 0"
4. Bouton est gris et désactivé
5. Message d'avertissement affiché
6. ✅ Impossible d'envoyer

### Scénario 4: Affichage Liste
1. 3 demandes disponibles
2. Chaque carte affiche:
   - Infos du client
   - Trajet
   - Distance
   - Badge "Il y a Xmin"
   - Bouton "Faire une offre"
3. ✅ Animations stagger

## Résumé

L'écran **DriverRequestsScreen** permet au chauffeur de:
1. ✅ Voir les demandes disponibles
2. ✅ Vérifier son solde de jetons (vérifié à l'envoi)
3. ✅ Proposer un prix pour une course
4. ✅ Envoyer sa proposition (si jetons >= 1)

**Règle clé**:
- ✅ **Jeton vérifié** lors de l'envoi de la proposition
- ❌ **Jeton PAS dépensé** lors de l'envoi
- ✅ **Jeton dépensé SEULEMENT** lors de l'accord final (acceptation des deux parties)

**Raison**: Éviter les remboursements complexes si négociation échoue ou client annule.

La négociation entre driver et rider/restaurant/marchand peut maintenant démarrer! 🚀

---

## Flux Complet avec Jetons

```
1. Driver voit demande → Vérifie jetons >= 1
   ↓
2. Driver propose prix → Envoie proposition (jeton vérifié, pas dépensé)
   ↓
3. Rider voit proposition → Sélectionne driver
   ↓
4. Négociation optionnelle → Accord sur prix
   ↓
5. Les DEUX acceptent → ✅ JETON DÉPENSÉ + Course démarre
```

**Alternative:**
```
4. Négociation optionnelle → Désaccord
   ↓
5. Rider choisit autre driver → ❌ Jeton PAS dépensé
```
