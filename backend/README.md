
# Urban Mobility Backend

## Description
Backend Node.js/Express (TypeScript) pour la super app de mobilité urbaine. Gère les utilisateurs, trajets, paiements, notifications, et intègre PostgreSQL/Redis.

## Structure du projet

- `src/` : code source TypeScript
  - `index.ts` : point d’entrée principal
  - `user.ts` : routes utilisateurs (inscription, login, profil)
  - `trip.ts` : routes trajets
  - `payment.ts` : routes paiements
- `schema.sql` : schéma de la base PostgreSQL
- `.env` : variables d’environnement (à créer)

## Installation & démarrage

1. Placez-vous dans le dossier backend :
   ```sh
   cd backend
   ```
2. Installez les dépendances :
   ```sh
   npm install
   ```
3. Créez un fichier `.env` avec :
   ```env
   PORT=3001
   DATABASE_URL=postgresql://postgres:postgres@localhost:5433/urbanmobility
   REDIS_URL=redis://localhost:6379
   JWT_SECRET=secret
   ```
4. Créez la base PostgreSQL et appliquez le schéma :
   ```sh
   psql -U postgres -p 5433 -c "CREATE DATABASE urbanmobility;"
   psql -U postgres -p 5433 -d urbanmobility -f schema.sql
   ```
5. Lancez Redis (`redis-server` doit tourner sur le port 6379)
6. Démarrez le serveur :
   ```sh
   npm run dev
   ```

## Endpoints principaux & exemples

### Authentification & Utilisateur

- **Inscription**
  - `POST /api/users/register`
  - Body : `{ "phone": "0600000000", "password": "monmdp" }`
  - Réponse : `{ "success": true }`

- **Connexion**
  - `POST /api/users/login`
  - Body : `{ "phone": "0600000000", "password": "monmdp" }`
  - Réponse : `{ "token": "..." }`

- **Profil utilisateur** (à sécuriser)
  - `GET /api/users/me`
  - Header : `Authorization: Bearer <token>`
  - Réponse : `{ ... }`

### Trajets

- **Créer un trajet**
  - `POST /api/trips/`
  - Body : `{ "user_id": 1, "origin": "A", "destination": "B", "vehicle_type": "taxi" }`
  - Réponse : `{ ... }`

- **Lister les trajets d’un utilisateur**
  - `GET /api/trips/user/1`
  - Réponse : `[ ... ]`

### Paiements

- **Effectuer un paiement (simulation)**
  - `POST /api/payments/`
  - Body : `{ "user_id": 1, "trip_id": 1, "amount": 1000, "method": "mobile_money" }`
  - Réponse : `{ "success": true }`

## Variables d’environnement

- `PORT` : port d’écoute du serveur (ex : 3001)
- `DATABASE_URL` : URL de connexion PostgreSQL (adapter le port si besoin)
- `REDIS_URL` : URL de connexion Redis
- `JWT_SECRET` : clé secrète pour JWT

## Technologies
- Node.js, Express, TypeScript
- PostgreSQL, Redis
- JWT, bcryptjs


## Plan détaillé de l’application mobile côté driver

### 1. Authentification conducteur
- Écran de connexion/inscription spécifique driver (ou rôle dans la table users)
- Gestion de session et sécurité (JWT)

### 2. Accueil conducteur
- Statut du conducteur (disponible/occupé/hors ligne)
- Bouton pour activer/désactiver la prise de courses

### 3. Réception de trajets
- Affichage en temps réel des nouvelles demandes de trajets (push ou polling)
- Détail du trajet proposé (point de départ, destination, type de course, prix estimé)
- Boutons Accepter / Refuser

### 4. Suivi de trajet accepté
- Carte avec itinéraire et position du passager
- Bouton “Arrivé au point de départ” puis “Démarrer la course” puis “Terminer la course”
- Affichage dynamique de la position du véhicule (mise à jour GPS)

### 5. Historique et statistiques
- Liste des courses effectuées (date, montant, statut)
- Statistiques (revenus, nombre de trajets, notes)

### 6. Profil et paramètres
- Informations personnelles, véhicule, documents
- Gestion des disponibilités, préférences

#### Backend à prévoir :
- Rôle utilisateur (driver/rider)
- Endpoints pour :
  - Authentification driver
  - Récupération des trajets à accepter
  - Acceptation/refus de trajet
  - Suivi de statut de course
  - Historique/statistiques driver

#### Mobile à prévoir :
- Nouveau module ou navigation dédiée “Driver”
- Gestion de la géolocalisation en temps réel
- Notifications (nouvelle course, annulation, etc.)

---

---

Pour toute question ou évolution, voir le code source ou contacter l’équipe technique.
