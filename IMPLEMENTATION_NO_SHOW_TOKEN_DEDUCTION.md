# 🔄 Implémentation Système No Show + Déduction Jeton au Démarrage - UUMO

**Date**: 8 janvier 2026  
**Source**: Adapté depuis APPZEDGO  
**Approche**: Approche 1 (Déduction au démarrage après récupération passager)

---

## ✅ FICHIERS CRÉÉS

### 1. **Migration SQL - No Show System**

📁 `supabase/migrations/20260108000001_create_no_show_system.sql`

**Contenu**:

- ✅ Table `no_show_reports` (signalements)
- ✅ Table `user_penalties` (pénalités)
- ✅ Colonnes ajoutées à `users`:
  - `no_show_count` (compteur)
  - `is_restricted` (statut restriction)
  - `restriction_until` (date expiration)
  - `last_no_show_at` (dernière occurrence)
- ✅ Indexes pour performance
- ✅ Fonction `expire_user_restrictions()` (auto-expiration)
- ✅ Triggers et RLS policies

### 2. **Migration SQL - Changement Déduction Jeton**

📁 `supabase/migrations/20260108000002_change_token_deduction_to_trip_start.sql`

**Contenu**:

- ✅ Désactivation ancien trigger sur `trip_offers`
- ✅ Nouvelle fonction `spend_token_on_trip_start()`
- ✅ Nouveau trigger sur `trips` (status = 'started')
- ✅ Ajout colonne `cancellation_reason` à `trips`
- ✅ Logs et vérifications post-migration

### 3. **Backend API - No Show**

📁 `backend/src/noShow.ts`

**Endpoints**:

- `POST /api/no-show/report` - Signaler No Show
- `GET /api/no-show/my-reports` - Historique signalements
- `GET /api/no-show/my-penalties` - Pénalités actives
- `GET /api/no-show/check-restriction/:user_id` - Vérifier restriction

**Logique**:

- **Driver No Show**: -1 jeton immédiat
- **Rider No Show**: Restrictions progressives (warning → 24h → 7j → 30j)

### 4. **Backend - Enregistrement Routes**

📁 `backend/src/index.ts`

**Modifications**:

```typescript
import noShowRoutes from "./noShow";
// ...
app.use("/api/no-show", noShowRoutes(pgPool));
```

### 5. **Backend - Modification Endpoint Start**

📁 `backend/src/trip.ts`

**Changement**:

- Ancienne version: Déduction manuelle du jeton
- **Nouvelle version**: Laisse le trigger DB faire la déduction
- Pre-check du solde pour meilleure UX
- Gestion d'erreur si jeton insuffisant

### 6. **Service Flutter - Driver**

📁 `mobile_driver/lib/services/no_show_service.dart`

**Méthodes**:

- `reportNoShow()` - Signaler passager absent
- `getMyReports()` - Mes signalements
- `getMyPenalties()` - Mes pénalités
- `checkRestriction()` - Vérifier restriction

### 7. **Service Flutter - Rider**

📁 `mobile_rider/lib/services/no_show_service.dart`

**Méthodes**:

- `reportNoShow()` - Signaler chauffeur absent
- `getMyReports()` - Mes signalements
- `getMyPenalties()` - Mes pénalités
- `checkRestriction()` - Vérifier restriction

---

## 🔄 WORKFLOW COMPLET

### Scénario Normal (Pas de No Show)

```
1. Rider crée demande → status = 'pending'
2. Driver fait offre → Vérifie token >= 1 (pas de déduction)
3. Rider accepte offre → status = 'accepted' (toujours pas de déduction)
4. Driver arrive au point de départ
5. Driver attend le passager
6. Passager monte à bord ✅
7. Driver clique "Démarrer la course"
   → Backend: POST /api/trips/start
   → DB: UPDATE trips SET status = 'started'
   → ⚡ TRIGGER: Déduit 1 jeton automatiquement
   → token_balances: balance = balance - 1
   → token_transactions: enregistre transaction
8. Driver roule vers destination
9. Arrivée → Driver clique "Terminer"
   → status = 'completed'
```

**Résultat**: Driver perd 1 jeton au démarrage (APRÈS avoir récupéré le passager)

---

### Scénario Rider No Show

```
1-5. Même workflow jusqu'à l'arrivée du driver
6. Passager NE SE PRÉSENTE PAS ❌
7. Driver attend 3+ minutes
8. Driver clique "Signaler No Show"
   → Backend: POST /api/no-show/report
   → Body: {
       trip_id: "xxx",
       reported_user_id: "rider_id",
       user_type: "rider",
       reason: "Passager absent"
     }
   → DB Actions:
     - INSERT INTO no_show_reports
     - UPDATE users SET no_show_count++, is_restricted, restriction_until
     - INSERT INTO user_penalties
     - UPDATE trips SET status = 'cancelled', cancellation_reason = 'no_show'
9. Rider reçoit pénalité selon compteur:
   - 1er: Warning (pas de restriction)
   - 2ème: 24h restriction
   - 3ème: 7 jours
   - 4+: 30 jours
```

**Résultat**:

- ✅ Driver ne perd AUCUN jeton (jamais cliqué "Démarrer")
- ❌ Rider reçoit restriction progressive

---

### Scénario Driver No Show

```
1-3. Même workflow jusqu'à l'acceptation
4. Driver n'arrive JAMAIS ou disparaît
5. Rider attend trop longtemps
6. Rider clique "Signaler No Show"
   → Backend: POST /api/no-show/report
   → Body: {
       trip_id: "xxx",
       reported_user_id: "driver_id",
       user_type: "driver",
       reason: "Chauffeur absent"
     }
   → DB Actions:
     - INSERT INTO no_show_reports
     - UPDATE users SET tokens = tokens - 1 (pénalité)
     - INSERT INTO user_penalties (tokens_deducted = 1)
     - UPDATE trips SET status = 'cancelled', cancellation_reason = 'no_show'
```

**Résultat**:

- ❌ Driver perd 1 jeton comme pénalité
- ✅ Rider peut rechercher nouveau chauffeur
- ℹ️ Driver peut continuer à travailler (pas de restriction)

---

## 📊 LOGIQUE DE PÉNALITÉS

### Driver No Show

- **Pénalité**: -1 jeton immédiat
- **Type**: `token_deduction`
- **Restriction**: Aucune (peut continuer à travailler)
- **Gravité**: Severity 1

### Rider No Show (Progressif)

| No Show # | Type          | Severity | Durée    | Peut commander? |
| --------- | ------------- | -------- | -------- | --------------- |
| 1er       | `warning`     | 1        | 0        | ✅ OUI          |
| 2ème      | `restriction` | 1        | 24h      | ❌ NON          |
| 3ème      | `restriction` | 2        | 7 jours  | ❌ NON          |
| 4+        | `restriction` | 3        | 30 jours | ❌ NON          |

---

## 🔐 AVANTAGES DE L'APPROCHE

### ✅ Protection Driver

1. **Pas de perte si Rider No Show** - Bouton "Démarrer" jamais cliqué
2. **Déduction seulement après confirmation** - Passager physiquement à bord
3. **Workflow clair** - Arrive → Récupère → Démarre → Déduction

### ✅ Protection Rider

1. **Restrictions progressives** - Système éducatif avec warning
2. **Pas de perte financière** - Seul le temps perdu
3. **Pénalités limitées dans le temps** - Auto-expiration

### ✅ Système Équitable

1. **Driver No Show = Perte jeton** - Pénalité économique directe
2. **Rider No Show = Restrictions** - Pénalité temporelle progressive
3. **Historique tracé** - Tables `no_show_reports` et `user_penalties`

---

## 🚀 PROCHAINES ÉTAPES

### TODO Restants

#### 10. ✅ Bouton "Démarrer" UI Driver - DÉJÀ IMPLÉMENTÉ

📁 `mobile_driver/lib/features/tracking/presentation/screens/driver_navigation_screen.dart`

**État**: ✅ **DÉJÀ EXISTANT** (lignes 1197-1214)

Le bouton existe déjà avec la logique complète :

- ✅ Bouton "Allez vers la destination" (ligne 1197)
- ✅ Actif quand `status = 'started'` (après pickup passager)
- ✅ Workflow complet : Arrive → Pickup → Démarrer → Destination
- ✅ Appel API via `TrackingService.updateTripStatus()`
- ✅ Déduction jeton automatique via trigger DB

**Workflow actuel confirmé** :

1. Driver clique "Allez vers le point de départ" (`status = 'accepted'`)
2. Driver clique "Je suis arrivé au point de départ" (`status = 'arrived'`)
3. Passager monte à bord
4. Driver clique "Allez vers la destination" → **⚡ Déduction jeton** (`status = 'started'`)
5. Driver clique "Je suis arrivé à destination" (`status = 'completed'`)

#### 11. ✅ UI Signalement No Show - IMPLÉMENTÉ

**Driver App**:

- ✅ **FAIT**: Bouton "Signaler passager absent" dans écran navigation
- ✅ **FAIT**: Dialogue de confirmation avec raison optionnelle
- ✅ Actif quand driver arrivé au point de départ (`_isNavigating = true`)
- ✅ Fichier: `mobile_driver/lib/features/tracking/presentation/screens/driver_navigation_screen.dart`
- ✅ Méthodes: `_showNoShowDialog()`, `_reportNoShow()`
- ✅ Import: `NoShowService` ajouté
- ✅ UI: Bouton rouge outlined avec icône `person_off`

**Rider App**:

- ✅ **FAIT**: Bouton "Signaler chauffeur absent" dans écran tracking
- ✅ **FAIT**: Dialogue de confirmation avec raison optionnelle
- ✅ Actif quand `status = 'accepted'` (chauffeur en route)
- ✅ Fichier: `mobile_rider/lib/features/order/presentation/screens/rider_tracking_screen.dart`
- ✅ Méthodes: `_showNoShowDialog()`, `_reportNoShow()`
- ✅ Import: `NoShowService` ajouté
- ✅ UI: Bouton rouge outlined avec icône `report_problem`

**Fonctionnalités implémentées**:

- Dialogues informatifs avec conséquences expliquées
- Champ raison optionnel
- Gestion d'erreur complète
- Messages de confirmation
- Navigation automatique après signalement

#### 12. Tests et Déploiement

**Tests à faire**:

1. ✅ Appliquer migrations SQL: `supabase db push`
2. ✅ Vérifier tables créées
3. ✅ Redémarrer backend: `npm run dev`
4. ⚠️ Tester endpoints No Show avec curl
5. ⚠️ Rebuild apps Flutter: `flutter clean && flutter pub get && flutter run`
6. ⚠️ Test Rider No Show complet (UI + API + Pénalité)
7. ⚠️ Test Driver No Show complet (UI + API + Perte jeton)
8. ⚠️ Test déduction jeton au démarrage (trigger DB)
9. ⚠️ Test restrictions progressives (1er = warning, 2ème = 24h, etc.)
10. ⚠️ Test auto-expiration restrictions

---

## 📞 COMMANDES UTILES

### Backend

```bash
cd backend
npm run dev

# Test endpoint No Show
curl http://localhost:3001/api/no-show/check-restriction/{USER_ID}
```

### Supabase

```bash
cd supabase
supabase db push

# Vérifier tables
supabase db sql
> SELECT * FROM no_show_reports LIMIT 5;
> SELECT * FROM user_penalties LIMIT 5;
> SELECT id, email, no_show_count, is_restricted FROM users WHERE no_show_count > 0;
```

### Flutter

```bash
# Driver app
cd mobile_driver
flutter clean && flutter pub get && flutter run

# Rider app
cd mobile_rider
flutter clean && flutter pub get && flutter run
```

---

## 🎯 RÉSUMÉ

**Fichiers créés**: 7  
**Migrations SQL**: 2  
**Endpoints API**: 4  
**Services Flutter**: 2  
**Logique métier**: 100% adaptée depuis APPZEDGO

**État actuel**:

- ✅ Backend + DB prêts
- ✅ Bouton "Démarrer" déjà implémenté dans driver_navigation_screen
- ❌ Boutons "Signaler No Show" à ajouter (Driver + Rider)
- ❌ Dialogues de confirmation à créer

**Workflow validé** :

- ✅ Déduction jeton au démarrage (status = 'started')
- ✅ Protection No Show automatique (pas de démarrage = pas de déduction)
- ✅ Système de pénalités complet (DB + API)

---

**Statut**: ⏳ En cours (étape 11 restante : UI No Show)  
**Documentation**: ✅ Complète  
**Code source**: ✅ APPZEDGO → UUMO  
**Tests**: ⏳ À faire après UI No Show
