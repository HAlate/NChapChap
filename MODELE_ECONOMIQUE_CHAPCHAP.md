# 💰 Modèle Économique CHAPCHAP

**Date** : 17 janvier 2026  
**Version** : 1.0

---

## 🎯 Principe de Base

CHAPCHAP fonctionne sur un **modèle de jetons prépayés** pour les chauffeurs.  
**CHAPCHAP ne prend AUCUNE commission sur le prix des courses.**

---

## 💳 Flux de Paiement

### Pour le Driver (Chauffeur)

1. **Achat de jetons** 📱
   - Le driver achète des jetons via **Mobile Money IN-APP**
   - Paiement à CHAPCHAP (MTN Money, Moov Money, Togocom, etc.)
   - **Pack Standard** : 200 F CFA = 10 jetons (20 F/jeton)
   - **Pack Premium** : 1000 F CFA = 60 jetons (50 + 10 bonus) (16,67 F/jeton) ⭐
2. **Utilisation des jetons** 🎟️
   - **1 jeton = 1 course acceptée**
   - Le jeton est déduit quand le driver clique "Aller vers la destination" (status='started')
   - Pas de remboursement si le rider ne se présente pas (système No Show)

3. **Revenus de la course** 💰
   - Le driver reçoit **100% du prix négocié** avec le rider
   - Paiement DIRECT du rider au driver (hors app)
   - Cash, Mobile Money direct, ou autre méthode convenue

### Pour le Rider (Passager)

1. **Négociation du prix** 🤝
   - Le rider négocie le prix avec le driver dans l'app
   - Prix final = accord mutuel entre rider et driver

2. **Paiement de la course** 💵
   - Le rider paie le driver **DIRECTEMENT** (hors app)
   - Méthodes : Cash, Mobile Money en face-à-face, autre
   - **Aucun paiement via l'app CHAPCHAP**

3. **Pas de frais pour le rider** ✅
   - Le rider ne paie que le prix négocié
   - Aucun frais de service CHAPCHAP
   - Aucun jeton à acheter

---

## 💵 Revenus CHAPCHAP

### Source unique : Vente de jetons

- **Prix des jetons** : Défini par CHAPCHAP
- **Packages disponibles** :
  - **Standard** : 200 F CFA = 10 jetons (20 F/jeton)
  - **Premium** : 1000 F CFA = 60 jetons (50 + 10 bonus) (16,67 F/jeton) ⭐

- **Marge CHAPCHAP** : 100% sur la vente de jetons
- **Pas de commission** : 0% sur le prix des courses

### Objectif 3 mois 🎯

- **5000 chauffeurs** actifs
- **10 courses/jour** par chauffeur
- **50 000 courses/jour** total
- **Revenus** : 50 000 × 20 F = **1 000 000 F CFA/jour**
- **30 000 000 F CFA/mois** 💰
- **90 000 000 F CFA sur 3 mois** 🚀

### Potentiel marché 📊

- **1 million de courses/jour** dans la ville du premier déploiement
- Objectif CHAPCHAP = 5% du marché (50 000 courses/jour)
- Déploiement possible : **Toute l'Afrique de l'Ouest**
- Prérequis : Numéro de téléphone local pour encaissements Mobile Money

### Avantages du modèle

✅ **Pour CHAPCHAP** :

- Revenus prévisibles et garantis (jetons vendus)
- Pas de gestion des paiements entre rider/driver
- Pas de litiges sur les commissions
- Scalable facilement

✅ **Pour le Driver** :

- Garde 100% du prix de la course
- Prévisibilité des coûts (prix du jeton connu)
- Liberté totale sur les prix
- Pas de surprise (pas de commission variable)

✅ **Pour le Rider** :

- Prix transparent (pas de frais cachés)
- Négociation libre avec le driver
- Paiement direct et simple

---

## 🔄 Exemple de Transaction Complète

### Scénario : Course de 10 000 F CFA

### Scénario : Course de 10 000 F CFA

1. **Driver achète 10 jetons** : 200 F CFA (Pack Standard) à CHAPCHAP
   - Balance : 10 jetons disponibles

2. **Driver fait une offre** au rider : 10 000 F CFA
   - Rider accepte
   - Status = 'accepted'

3. **Driver clique "Aller vers la destination"**
   - Status = 'started'
   - **1 jeton déduit automatiquement**
   - Balance : 9 jetons restants

4. **Course effectuée**
   - Status = 'completed'
   - Rider paie driver DIRECTEMENT : 10 000 F CFA (cash/mobile money)

5. **Résultat financier** :
   - **Driver** : +10 000 F CFA - 20 F (coût du jeton) = **+9 980 F CFA net**
   - **Rider** : -10 000 F CFA (prix négocié)
   - **CHAPCHAP** : +20 F CFA (prix du jeton vendu)

---

## 🎟️ Gestion des Jetons

### Achat de jetons

- **Méthode** : Mobile Money in-app uniquement
- **Délai** : Crédité sous 24h après vérification manuelle
- **Opérateurs supportés** : MTN Money, Moov Money, Togocom (Togo)
- **Pas de remboursement** : Les jetons ne sont pas remboursables

### Dépense de jetons

- **Timing** : Au moment où le driver démarre la course (status='started')
- **Pourquoi** : Évite les abus (offres spam sans intention réelle)
- **No Show** : Si le rider ne se présente pas, le jeton n'est pas remboursé
- **Annulation** : Si annulation avant 'started', pas de déduction

### Historique

- Tous les achats et dépenses sont enregistrés dans `token_transactions`
- Le driver peut consulter son historique in-app
- Colonne `notes` : Description de chaque transaction

---

## 📊 Comparaison avec Uber/Bolt

| Critère                   | CHAPCHAP                   | Uber/Bolt                    |
| ------------------------- | -------------------------- | ---------------------------- |
| **Commission**            | 0% (sur prix de la course) | 15-25%                       |
| **Coût pour driver**      | 20 F/course (fixe)         | 15-25% du prix (variable)    |
| **Prix course**           | 100% au driver             | 75-85% au driver             |
| **Négociation**           | Libre                      | Prix imposé par algorithme   |
| **Paiement rider→driver** | Direct (hors app)          | Via l'app                    |
| **Revenu CHAPCHAP**       | Vente de jetons            | Commission sur chaque course |
| **Revenu CHAPCHAP**       | Vente de jetons            | Commission sur chaque course |

---

## 🛡️ Sécurité et Confiance

### Pour éviter les abus

1. **Jetons non remboursables** : Évite les fraudes
2. **Déduction au démarrage** : Pas de spam d'offres sans intention
3. **Système No Show** : Protège le driver si le rider ne se présente pas
4. **Historique complet** : Traçabilité de toutes les transactions

### Paiement rider→driver

- **Responsabilité** : Entre le rider et le driver uniquement
- **CHAPCHAP non impliqué** : Pas de gestion des litiges de paiement
- **Liberté** : Cash, Mobile Money direct, chèque, autre

---

## 📈 Évolution Future (Optionnel)

### Fonctionnalités possibles

- **Packages entreprise** : Jetons en gros pour flottes
- **Abonnements mensuels** : X jetons/mois à tarif réduit
- **Programme de fidélité** : Bonus jetons après X courses
- **Jetons promotionnels** : Offerts par CHAPCHAP lors d'événements

### Paiement in-app (futur)

Si CHAPCHAP décide d'ajouter le paiement in-app plus tard :

- Le rider pourrait payer via l'app
- CHAPCHAP prendrait une commission (ex: 10%)
- Le driver recevrait le paiement via CHAPCHAP
- **Modèle hybride** : Jetons + Commission

---

## 🎯 Résumé

**Modèle actuel (100% jetons)** :

- ✅ Driver achète jetons via Mobile Money (in-app)
  - Pack Standard: 200 F = 10 jetons
  - Pack Premium: 1000 F = 60 jetons (50 + 10 bonus)
- ✅ 1 jeton = 20 F = 1 course acceptée
- ✅ Rider paie driver DIRECTEMENT (hors app)
- ✅ CHAPCHAP gagne sur la vente de jetons uniquement
- ✅ Driver garde 100% du prix de la course

**Objectif 3 mois : 30 M F CFA/mois** 🚀

- 5000 chauffeurs × 10 courses/jour = 50 000 courses/jour
- Marché potentiel : 1 million de courses/jour
- Déploiement : Toute l'Afrique de l'Ouest

**Simple, transparent, win-win-win pour tous !** 🎉

---

**Projet** : CHAPCHAP - Urban Mobility Platform  
**Contact** : [Informations de contact]
