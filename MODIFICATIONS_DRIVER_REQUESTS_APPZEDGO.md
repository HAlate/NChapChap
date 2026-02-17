# 🔄 Modifications Driver Requests & Make Offer - Basé sur APPZEDGO

## 📋 Vue d'ensemble

**Architecture APPZEDGO** : Le popup pour faire une offre a été supprimé et remplacé par un écran dédié `make_offer_screen.dart` qui affiche une carte Google Maps avec les marqueurs (départ, destination, position chauffeur) et un formulaire pour entrer le prix et l'ETA.

**Architecture UUMO** : Identique à APPZEDGO. Le fichier `make_offer_screen.dart` existe déjà et fonctionne de la même manière. Ce document décrit les améliorations mineures inspirées d'APPZEDGO.

---

## ✅ Déjà implémenté dans UUMO

### 1. Affichage du solde de jetons

- ✅ Badge dans l'AppBar avec icône et nombre
- ✅ Gestion des états (loading, error, data)
- ✅ Tap pour afficher détails du solde
- ✅ Provider `tokenBalanceProvider` pour récupérer le solde

### 2. Vérification lors de la création d'offre

- ✅ `createOffer` dans `DriverOfferService` vérifie le solde
- ✅ Exception levée si jetons insuffisants
- ✅ Message d'erreur affiché à l'utilisateur

---

## 🆕 Améliorations suggérées (inspirées d'APPZEDGO)

### Amélioration 1: Vérification préventive avant navigation

**Contexte**: Dans APPZEDGO, le solde est vérifié **avant** d'ouvrir `make_offer_screen`. Cela évite à l'utilisateur de remplir le formulaire pour rien.

**Fichier**: `driver_requests_screen.dart`

**Ligne à modifier**: Méthode `_navigateToMakeOffer` dans `_TripRequestCard`

**Code actuel** (ligne ~308):

```dart
void _navigateToMakeOffer(BuildContext context) {
  // Navigation vers l'écran de création d'offre avec la carte
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => MakeOfferScreen(
        trip: trip,
        driverPosition: driverPosition,
      ),
    ),
  );
}
```

**Code suggéré** (APPZEDGO-style):

```dart
void _navigateToMakeOffer(BuildContext context, WidgetRef ref) {
  // Vérifier le solde AVANT de naviguer
  final balanceAsync = ref.read(tokenBalanceProvider);

  balanceAsync.whenOrNull(
    data: (balance) {
      if (balance.tokensAvailable < 1) {
        // Afficher dialog pour acheter des jetons
        _showBuyTokensDialog(context);
      } else {
        // Navigation normale
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MakeOfferScreen(
              trip: trip,
              driverPosition: driverPosition,
            ),
          ),
        );
      }
    },
    error: (error, stack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de vérifier votre solde. Réessayez.'),
          backgroundColor: Colors.orange,
        ),
      );
    },
  );
}

void _showBuyTokensDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Text('Jetons insuffisants'),
        ],
      ),
      content: Text(
        'Vous devez avoir au moins 1 jeton pour faire une offre.\n\n'
        'Les jetons permettent de répondre aux demandes de courses.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Navigation vers l'écran d'achat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BuyTokensScreen(),
              ),
            );
          },
          icon: Icon(Icons.shopping_cart),
          label: Text('Acheter des jetons'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
          ),
        ),
      ],
    ),
  );
}
```

**Modification du bouton "Faire une offre"**:

```dart
// Ligne ~408
child: ElevatedButton(
  onPressed: () => _navigateToMakeOffer(context, ref), // Ajouter ref
  // ... reste du code
)
```

**Note**: `_TripRequestCard` est déjà un `ConsumerWidget`, donc `ref` est accessible via le paramètre `build`.

---

### Amélioration 2: Message plus informatif lors de l'échec

**Fichier**: `make_offer_screen.dart`

**Ligne**: ~203 (bloc catch de `_submitOffer`)

**Code actuel**:

```dart
} catch (e) {
  if (mounted) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Erreur: ${e.toString()}"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

**Code suggéré**:

```dart
} catch (e) {
  if (mounted) {
    setState(() {
      _isLoading = false;
    });

    // Vérifier si c'est une erreur de jetons insuffisants
    final errorMessage = e.toString();
    final isTokenError = errorMessage.contains('token') ||
                         errorMessage.contains('Insufficient');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTokenError
              ? "⚠️ Jetons insuffisants. Achetez des jetons pour continuer."
              : "Erreur: $errorMessage",
        ),
        backgroundColor: isTokenError ? Colors.orange : Colors.red,
        action: isTokenError
            ? SnackBarAction(
                label: 'Acheter',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BuyTokensScreen(),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}
```

---

## 📊 Comparaison APPZEDGO vs UUMO

| Fonctionnalité                                       | APPZEDGO | UUMO (actuel) | Suggestion      |
| ---------------------------------------------------- | -------- | ------------- | --------------- |
| **Écran dédié make_offer_screen**                    | ✅       | ✅            | Aucune          |
| **Carte avec marqueurs (départ/destination/driver)** | ✅       | ✅            | Aucune          |
| **Formulaire prix + ETA**                            | ✅       | ✅            | Aucune          |
| Affichage solde dans AppBar                          | ✅       | ✅            | Aucune          |
| Vérification lors création offre                     | ✅       | ✅            | Aucune          |
| **Vérification préventive**                          | ✅       | ❌            | **À ajouter**   |
| Message d'erreur informatif                          | ✅       | ⚠️ Basique    | **À améliorer** |
| Dialog "Acheter des jetons"                          | ✅       | ❌            | **À ajouter**   |

---

## 🎯 Impact des modifications

### Avant (UUMO actuel):

1. Utilisateur voit une demande de course
2. Clique sur "Faire une offre"
3. ✅ **Navigation vers écran `make_offer_screen`** (avec carte)
4. **Remplit le formulaire** (prix, ETA)
5. Clique sur "Soumettre"
6. ❌ Erreur: "Insufficient tokens"
7. Frustration ⚠️

### Après (avec modifications APPZEDGO):

1. Utilisateur voit une demande de course
2. Clique sur "Faire une offre"
3. ✅ **Vérification immédiate du solde**
4. Si insuffisant → Dialog avec bouton "Acheter des jetons"
5. Si suffisant → Navigation vers `make_offer_screen`
6. UX améliorée ✨

---

## 🚀 Implémentation

### Étape 1: Modifier `_TripRequestCard`

Ajouter les deux méthodes:

- `_navigateToMakeOffer(context, ref)` (version améliorée)
- `_showBuyTokensDialog(context)` (nouvelle)

### Étape 2: Modifier le bouton "Faire une offre"

Passer `ref` en paramètre:

```dart
onPressed: () => _navigateToMakeOffer(context, ref)
```

### Étape 3: Améliorer le catch dans `make_offer_screen.dart`

Détecter les erreurs de jetons et afficher un message + action appropriés.

---

## 📝 Notes importantes

1. **Architecture**: APPZEDGO a remplacé le popup d'offre par un écran dédié `make_offer_screen.dart` qui affiche :

   - Une carte Google Maps (40% de l'écran) avec marqueurs pour départ, destination et position chauffeur
   - Un formulaire (60% de l'écran) pour saisir le prix et l'ETA
   - UUMO utilise déjà cette même architecture ✅

2. **Import manquant**: Ajouter `import 'package:mobile_driver/features/tokens/presentation/screens/buy_tokens_screen.dart';` si nécessaire

3. **Provider déjà disponible**: `tokenBalanceProvider` existe déjà dans UUMO (défini dans `driver_offer_service.dart`)

4. **ConsumerWidget**: `_TripRequestCard` est déjà un `ConsumerWidget`, donc `ref` est accessible

5. **Cohérence**: Ces modifications s'alignent avec le système de jetons déjà en place dans UUMO

---

## ✅ Checklist d'implémentation

- [ ] Modifier `_navigateToMakeOffer` pour vérifier le solde avant navigation
- [ ] Ajouter `_showBuyTokensDialog` pour afficher l'alerte
- [ ] Passer `ref` au bouton "Faire une offre"
- [ ] Améliorer le catch dans `_submitOffer` (make_offer_screen)
- [ ] Tester le flux complet: jetons > 0, jetons = 0, erreur
- [ ] Vérifier que le dialog "Acheter des jetons" navigue correctement

---

## 🔗 Références

- APPZEDGO: `mobile_driver/lib/features/requests/presentation/screens/driver_requests_screen.dart` (lignes 282-323)
- APPZEDGO: `mobile_driver/lib/features/requests/presentation/screens/make_offer_screen.dart` (lignes 129-227)
- Système de jetons UUMO: `INDEX_DOCUMENTATION_JETONS.md`

---

**Date**: 2026-01-08  
**Source**: Comparaison APPZEDGO/UUMO  
**Priorité**: Moyenne (amélioration UX)
