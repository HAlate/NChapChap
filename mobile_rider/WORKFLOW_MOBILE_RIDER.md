# Workflow Mobile Rider

Ce document récapitule le workflow de l'application mobile_rider et liste tous les écrans opérationnels avec leur rôle principal.

## 1. Authentification
- **SplashScreen** : Chargement initial, redirection selon l'état de connexion.
- **LoginScreen** : Connexion de l'utilisateur (rider).
- **RegisterScreen** : Création de compte rider.
- **ForgotPasswordScreen** : Réinitialisation du mot de passe.

## 2. Accueil & Navigation
- **HomeScreen** : Tableau de bord principal avec accès rapide aux fonctionnalités.
- **BottomNavigationBar** : Navigation entre les sections principales (Accueil, Courses, Propositions, Profil, etc).

## 3. Création de course
- **TripScreen** : Formulaire de création d'une nouvelle course (départ, destination, options).
- **TripScreenNew** : Version améliorée du formulaire de création de course.
- **TripSummaryScreen** : Récapitulatif de la course avant validation.

## 4. Attente et propositions
- **WaitingOffersInitialScreen** : Affiché juste après la création d'une course, indique l'attente des offres de chauffeurs.
- **PropositionsScreen** : Liste toutes les offres reçues pour les courses en attente. Actions : sélectionner, supprimer, négocier.

## 5. Détail et négociation d'offre
- **NegotiationDetailScreen** : Détail d'une offre, possibilité de négocier le prix avec le chauffeur.

## 6. Suivi de course
- **TripTrackingScreen** : Suivi en temps réel de la course acceptée (carte, position du chauffeur, étapes).
- **TripStatusScreen** : Affiche l'état actuel de la course (en attente, en cours, terminée).

## 7. Paiement
- **PaymentScreen** : Paiement de la course (mobile money, jetons, etc).
- **PaymentConfirmationScreen** : Confirmation du paiement.

## 8. Historique & Profil
- **TripsHistoryScreen** : Historique des courses passées.
- **ProfileScreen** : Gestion du profil utilisateur.
- **SettingsScreen** : Paramètres de l'application.

## 9. Divers
- **SupportScreen** : Accès à l'aide et au support.
- **NotificationsScreen** : Liste des notifications reçues.

---

**Remarques :**
- Tous les écrans listés sont opérationnels ou en production dans le projet mobile_rider.
- Le workflow type :
  1. Connexion
  2. Création d'une course
  3. Attente des offres
  4. Sélection ou négociation d'une offre
  5. Suivi de la course
  6. Paiement
  7. Historique et gestion du profil

Pour plus de détails, se référer à la documentation technique ou au code source de chaque écran.
