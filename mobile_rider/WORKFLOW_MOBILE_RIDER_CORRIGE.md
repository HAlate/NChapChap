# Workflow Mobile Rider (Version corrigée)

Ce document liste uniquement les écrans réellement présents dans le code du projet mobile_rider, avec leur rôle principal.

## 1. Authentification
- **LoginScreen** (`login_screen.dart`) : Connexion du rider.
- **RegisterScreen** (`register_screen.dart`) : Création de compte rider.

## 2. Accueil & Navigation
- **HomeShell** (`home_shell.dart`) : Shell de navigation principale (avec bottom navigation).
- **HomeScreenNew** (`home_screen_new.dart`) : Accueil principal.

## 3. Création & gestion de course
- **TripScreen** (`trip_screen.dart`) : Création d'une nouvelle course.
- **TripScreenNew** (`trip_screen_new.dart`) : Variante/évolution du formulaire de création de course.
- **MyTripsScreen** (`my_trips_screen.dart`) : Liste et gestion des courses du rider.

## 4. Attente & propositions
- **WaitingOffersScreen** (`waiting_offers_screen.dart`) : Attente des offres après création d'une course.
- **WaitingOffersInitialScreen** (`waiting_offers_initial_screen.dart`) : Écran d'attente initial juste après la création.
- **PropositionsScreen** (`propositions_screen.dart`) : Liste des offres reçues pour les courses en attente.

## 5. Négociation
- **NegotiationDetailScreen** (`negotiation_detail_screen.dart`) : Détail et négociation d'une offre.
- **NegotiationScreen** (`negotiation_screen.dart`) : Écran de négociation (autre contexte ou historique).

## 6. Suivi de course
- **TrackingScreen** (`tracking_screen.dart`) : Suivi en temps réel de la course acceptée.

## 7. Profil
- **ProfileScreen** (`profile_screen.dart`) : Gestion du profil utilisateur.

---

**Remarques :**
- Les écrans de paiement, support, notifications, paramètres, historique détaillé, etc. ne sont pas présents dans le code actuel.
- Ce workflow reflète l'état réel du projet mobile_rider au 5 décembre 2025.
- Pour chaque évolution, il est conseillé de mettre à jour ce document en fonction des ajouts/suppressions d'écrans.
