# ✅ Tests de Navigation - Mobile Rider

## Test 1: Création de Trajet → Attente Offres

**Étapes:**
1. Ouvrir app mobile_rider
2. Se connecter
3. Sélectionner type véhicule (taxi/moto/etc.)
4. Entrer destination
5. Cliquer "Rechercher des chauffeurs"

**Résultat attendu:**
✅ Navigation vers `/waiting-offers/:tripId`
✅ Affichage "En attente de propositions"

---

## Test 2: Voir Offres → Négociation

**Étapes:**
1. Dans WaitingOffersScreen avec offres
2. Cliquer sur une offre
3. Modal de confirmation s'ouvre
4. Cliquer "Contre-proposer"

**Résultat attendu:**
✅ Navigation vers `/negotiation/:offerId`
✅ Affichage écran négociation avec infos driver
✅ Prix proposé affiché correctement

---

## Test 3: Négociation → Contre-offre

**Étapes:**
1. Dans NegotiationDetailScreen
2. Entrer un prix inférieur
3. Ajouter message optionnel
4. Cliquer "Envoyer contre-offre"

**Résultat attendu:**
✅ Message "Contre-offre envoyée!"
✅ Retour à WaitingOffersScreen
✅ Status offre mis à jour en DB

---

## Test 4: Négociation → Acceptation

**Étapes:**
1. Dans NegotiationDetailScreen
2. Cliquer "Accepter X FCFA"

**Résultat attendu:**
✅ Message "Course confirmée!"
✅ Navigation vers `/tracking/:tripId`
✅ Status trip = "accepted" en DB

---

## Test 5: Retour depuis Négociation

**Étapes:**
1. Dans NegotiationDetailScreen
2. Cliquer bouton "Annuler"

**Résultat attendu:**
✅ Retour à WaitingOffersScreen
✅ Liste des offres toujours visible

---

## Checklist Correction

- [x] Changé `context.push()` en `context.go()` (ligne 90)
- [x] Paramètres `extra` correctement passés
- [x] Route `/negotiation/:offerId` configurée dans router
- [x] NegotiationDetailScreen reçoit les bonnes props
- [x] Documentation créée

---

**Date**: 2025-11-30
**Statut**: ✅ Prêt pour tests
