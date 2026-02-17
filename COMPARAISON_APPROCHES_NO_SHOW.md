# 🔄 Comparaison Approches - Gestion No Show & Token Deduction

**Date**: 8 janvier 2026  
**Contexte**: Correction du système de déduction des jetons pour UUMO

---

## 📋 Besoin Initial

> **Problème actuel** : Jetons déduits à l'acceptation de l'offre (`trip_offers.status = 'accepted'`)  
> **Besoin exprimé** : "Jeton déduit uniquement en fin de course, et déduit d'office si c'est le chauffeur qui est No Show"

**Raison** : Éviter la perte de jeton si le passager ne se présente pas (Rider No Show)

---

## 🎯 Approche 1 : Système APPZEDGO (Déduction au Démarrage)

### Description

Implémenter la logique APPZEDGO telle quelle :

- **Déduction au DÉMARRAGE** : Jeton déduit quand `trips.status = 'started'` (pas à l'acceptation)
- Tables `no_show_reports` et `user_penalties` pour historique
- Backend API `/api/no-show/*` pour gestion signalements
- Services Flutter driver/rider

> **💡 Clé APPZEDGO** : Le jeton est déduit quand le driver DÉMARRE la course (clique "Aller vers destination"), pas à l'acceptation.  
> **Workflow** : Acceptation → Driver arrive → Récupère passager → Clique "Démarrer" → ⚡ Jeton déduit  
> **Si Rider No Show** : Driver ne clique JAMAIS "Démarrer" → Pas de déduction → Jeton intact ✅  
> Voir `backend/src/trip.ts` ligne 23-42 : _"Le jeton ne sera déduit que lorsque le driver démarre la course. Cela évite de perdre un jeton en cas de no show du passager"_

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ FLUX NORMAL                                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction (jeton intact)                       │
│ 3. Driver arrive au point de départ                        │
│ 4. Driver récupère le passager physiquement                │
│ 5. Driver clique "Aller vers destination" → status = 'started' │
│ 6. ⚡ TRIGGER/API: Déduit 1 jeton À CE MOMENT               │
│ 7. Course en cours...                                      │
│ 8. Course terminée → status = 'completed'                  │
│ ✅ Jeton dépensé uniquement si passager monté à bord        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CAS RIDER NO SHOW (avant démarrage)                        │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction                                      │
│ 3. Driver arrive au point de départ                        │
│ 4. Rider ne se présente pas (attend 3+ minutes)            │
│ 5. ❌ Driver NE CLIQUE PAS "Démarrer"                       │
│ 6. Driver clique "Signaler No Show" (optionnel)            │
│ 7. 📞 API Call: POST /api/no-show/report (optionnel)       │
│    {                                                        │
│      reported_user: rider_id,                              │
│      user_type: 'rider',                                   │
│      trip_id: xxx                                          │
│    }                                                        │
│ 8. Backend (optionnel):                                    │
│    - Rider reçoit warning/restriction progressive          │
│    - Trip cancelled                                        │
│ ✅ Driver ne perd AUCUN jeton (bouton "Démarrer" jamais cliqué) │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CAS DRIVER NO SHOW                                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction                                      │
│ 3. Driver ne se présente pas / n'arrive jamais             │
│ 4. Rider clique "Signaler No Show"                         │
│ 5. 📞 API Call: POST /api/no-show/report                   │
│    {                                                        │
│      reported_user: driver_id,                             │
│      user_type: 'driver',                                  │
│      trip_id: xxx                                          │
│    }                                                        │
│ 6. Backend:                                                │
│    - Driver perd 1 jeton (pénalité No Show)                │
│    - Trip cancelled avec reason 'driver_no_show'           │
│ ❌ Driver perd 1 jeton (pénalité unique)                     │
└─────────────────────────────────────────────────────────────┘
```

### Fichiers à Créer/Modifier

#### 1. Migration SQL

```sql
-- supabase/migrations/20260108_create_no_show_system.sql
-- Tables: no_show_reports, user_penalties
-- Colonnes users: no_show_count, is_restricted, restriction_until
-- Triggers: auto-expiration restrictions
-- RLS policies
```

#### 2. Backend (Node.js) - Démarrage de course

```typescript
// backend/src/trip.ts
router.post("/start", async (req, res) => {
  const { trip_id, driver_id } = req.body;

  // Vérifier que le driver a au moins 1 jeton
  const userRes = await pgPool.query(
    "SELECT balance FROM token_balances WHERE user_id = $1 AND token_type = 'course'",
    [driver_id]
  );

  if (!userRes.rows.length || userRes.rows[0].balance < 1) {
    return res.status(403).json({ error: "Pas assez de jetons" });
  }

  // ⚡ DÉDUIRE LE JETON AU DÉMARRAGE
  await pgPool.query(
    "UPDATE token_balances SET balance = balance - 1 WHERE user_id = $1 AND token_type = 'course'",
    [driver_id]
  );

  // Mettre à jour le statut du trajet à 'started'
  await pgPool.query(
    "UPDATE trips SET status = 'started', started_at = NOW() WHERE id = $1",
    [trip_id]
  );

  res.json({ success: true });
});
```

#### 3. Backend (Node.js) - Gestion No Show

```typescript
// backend/src/noShow.ts
router.post("/report", async (req, res) => {
  const { trip_id, reported_user_id, user_type, reason } = req.body;

  // ... validation

  if (user_type === "rider") {
    // Rider No Show: Système progressif warnings/restrictions
    // ✅ Driver n'a jamais perdu de jeton (pas encore démarré)

    const riderCheck = await pgPool.query(
      "SELECT no_show_count FROM users WHERE id = $1",
      [reported_user_id]
    );

    const newCount = (riderCheck.rows[0]?.no_show_count || 0) + 1;
    let restrictionDays = 0;

    if (newCount === 1) restrictionDays = 0; // Warning
    else if (newCount === 2) restrictionDays = 1; // 24h
    else if (newCount === 3) restrictionDays = 7; // 7 jours
    else restrictionDays = 30; // 30 jours

    const restrictionUntil =
      restrictionDays > 0
        ? new Date(Date.now() + restrictionDays * 24 * 60 * 60 * 1000)
        : null;

    await pgPool.query(
      "UPDATE users SET no_show_count = no_show_count + 1, is_restricted = $1, restriction_until = $2 WHERE id = $3",
      [restrictionDays > 0, restrictionUntil, reported_user_id]
    );
  } else if (user_type === "driver") {
    // Driver No Show: Pénalité -1 jeton
    await pgPool.query(
      "UPDATE token_balances SET balance = GREATEST(0, balance - 1) WHERE user_id = $1 AND token_type = 'course'",
      [reported_user_id]
    );

    await pgPool.query(
      "INSERT INTO user_penalties (user_id, penalty_type, severity, reason, trip_id, tokens_deducted, is_active) VALUES ($1, 'no_show', 1, $2, $3, 1, TRUE)",
      [reported_user_id, "No Show signalé - 1 jeton déduit", trip_id]
    );
  }

  // Annuler trip
  await pgPool.query("UPDATE trips SET status = 'cancelled' WHERE id = $1", [
    trip_id,
  ]);

  res.json({ success: true, message: "No Show signalé avec succès" });
});
```

#### 4. Services Flutter

```dart
// mobile_driver/lib/services/no_show_service.dart
// mobile_rider/lib/services/no_show_service.dart
class NoShowService {
  static Future<Map<String, dynamic>> reportNoShow({
    required String tripId,
    required String reportedUser,
    required String userType,
    String? reason,
  });

  static Future<Map<String, dynamic>> checkRestriction(String userId);
  static Future<List<dynamic>> getMyReports(String userId);
}
```

#### 4. Services Flutter

```dart
// mobile_driver/lib/services/no_show_service.dart
// mobile_rider/lib/services/no_show_service.dart
class NoShowService {
  static Future<Map<String, dynamic>> reportNoShow({
    required String tripId,
    required String reportedUser,
    required String userType,
    String? reason,
  });

  static Future<Map<String, dynamic>> checkRestriction(String userId);
  static Future<List<dynamic>> getMyReports(String userId);
}
```

#### 5. UI Flutter

```dart
// mobile_driver/lib/features/tracking/presentation/screens/driver_navigation_screen.dart
// Ajouter bouton "Démarrer Course" qui appelle POST /api/trip/start
// Ajouter bouton "Signaler No Show" si rider absent après 3 minutes d'attente

// mobile_rider/lib/features/order/presentation/screens/rider_tracking_screen.dart
// Ajouter bouton "Signaler No Show" si driver ne se présente pas
```

### ✅ Avantages

1. ✅ **Système complet et testé** (utilisé dans APPZEDGO production)
2. ✅ **Protection Rider No Show** : Driver ne clique pas "Démarrer" → jeton intact
3. ✅ **Historique des No Shows** et pénalités structuré
4. ✅ **Protection rider** : restrictions progressives contre récidivistes
5. ✅ **Pénalité juste** : Driver No Show perd 1 jeton
6. ✅ **UX claire** : boutons explicites pour signaler No Show
7. ✅ **Interface admin** pour gérer les signalements

### ❌ Inconvénients

1. ⚠️ **Complexité** : Beaucoup de code à ajouter (backend + Flutter)
2. ⚠️ **Dépendance backend** : Nécessite backend Node.js fonctionnel
3. ⚠️ **Migration importante** : Ajout tables + colonnes + backend API
4. ⚠️ **Déduction PENDANT trajet** : Jeton déduit dès que passager monte à bord
   - Si problème technique/accident APRÈS démarrage → jeton perdu même si non terminé
   - Si passager descend avant destination → jeton perdu
   - Si annulation mutuelle en cours de route → jeton perdu
5. ⚠️ **Bouton démarrage requis** : Driver doit cliquer "Démarrer" après récupération passager
6. ⚠️ **Risque d'oubli** : Driver peut oublier de cliquer → navigation fonctionne mais jeton pas déduit

### ❌ Inconvénients

1. ⚠️ **Complexité** : Beaucoup de code à ajouter (backend + Flutter)
2. ⚠️ **Dépendance backend** : Nécessite backend Node.js fonctionnel
3. ⚠️ **Migration importante** : Ajout tables + colonnes + backend API
4. ⚠️ **Déduction AVANT complétion** : Jeton déduit à 'started', pas 'completed'
   - Si problème technique après démarrage → jeton perdu même si course non terminée
5. ⚠️ **Bouton démarrage requis** : Driver doit cliquer "Démarrer" (étape supplémentaire)

### 📊 Effort d'Implémentation

- **Backend** : 4-6 heures (API routes + logique)
- **Migration SQL** : 1 heure
- **Services Flutter** : 2-3 heures
- **UI Flutter** : 3-4 heures (2 apps)
- **Tests** : 2-3 heures
- **TOTAL** : ~12-17 heures

---

## 🎯 Approche 2 : Déduction à la Complétion (Sur-Mesure UUMO)

### Description

Solution personnalisée sans backend API :

- Désactiver trigger actuel
- Créer nouveau trigger sur `trips.status = 'completed'`
- Ajouter colonne `cancellation_reason` ENUM
- Logique conditionnelle pure SQL/Triggers

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ FLUX NORMAL                                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction (jeton intact)                       │
│ 3. Driver démarre course → status = 'started'              │
│ 4. Course terminée → status = 'completed'                  │
│ 5. ⚡ TRIGGER: Déduit 1 jeton à CE MOMENT                   │
│ ✅ Jeton dépensé uniquement si course complétée             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CAS RIDER NO SHOW (Annulation)                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction                                      │
│ 3. Driver arrive, attend                                   │
│ 4. Driver annule avec raison 'rider_no_show'              │
│ 5. UPDATE trips SET                                        │
│      status = 'cancelled',                                 │
│      cancellation_reason = 'rider_no_show'                 │
│ 6. ⚡ TRIGGER sur cancelled:                                │
│    IF cancellation_reason = 'rider_no_show' THEN           │
│      -- PAS de déduction (jeton intact)                    │
│    END IF                                                  │
│ ✅ Driver ne perd AUCUN jeton                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CAS DRIVER NO SHOW (Annulation)                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction                                      │
│ 3. Driver ne se présente pas                               │
│ 4. Rider annule avec raison 'driver_no_show'              │
│ 5. UPDATE trips SET                                        │
│      status = 'cancelled',                                 │
│      cancellation_reason = 'driver_no_show'                │
│ 6. ⚡ TRIGGER sur cancelled:                                │
│    IF cancellation_reason = 'driver_no_show' THEN          │
│      -- Déduit 1 jeton IMMÉDIATEMENT                       │
│      UPDATE token_balances SET balance = balance - 1       │
│    END IF                                                  │
│ ❌ Driver perd 1 jeton                                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CAS ANNULATION NORMALE                                     │
├─────────────────────────────────────────────────────────────┤
│ 1. Rider accepte offre → status = 'accepted'               │
│ 2. ✅ PAS de déduction                                      │
│ 3. Rider ou Driver annule (autre raison)                  │
│ 4. UPDATE trips SET                                        │
│      status = 'cancelled',                                 │
│      cancellation_reason = 'mutual' / 'rider_cancel' / etc │
│ 5. ⚡ TRIGGER sur cancelled:                                │
│    IF cancellation_reason NOT IN ('driver_no_show') THEN   │
│      -- PAS de déduction (jeton intact)                    │
│    END IF                                                  │
│ ✅ Aucune perte de jeton                                    │
└─────────────────────────────────────────────────────────────┘
```

### Fichiers à Créer/Modifier

#### 1. Migration SQL - Ajout colonne

```sql
-- supabase/migrations/20260108_add_cancellation_reason.sql
CREATE TYPE cancellation_reason_type AS ENUM (
  'rider_cancel',
  'driver_cancel',
  'rider_no_show',
  'driver_no_show',
  'mutual',
  'other'
);

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS cancellation_reason cancellation_reason_type;

COMMENT ON COLUMN trips.cancellation_reason IS
'Raison de l''annulation: driver_no_show déclenche déduction jeton';
```

#### 2. Migration SQL - Nouveau trigger

```sql
-- supabase/migrations/20260108_token_deduction_on_completion.sql

-- 1. DÉSACTIVER ancien trigger
DROP TRIGGER IF EXISTS trigger_spend_token_on_trip_offer_acceptance ON trip_offers;

-- 2. CRÉER nouvelle fonction
CREATE OR REPLACE FUNCTION spend_token_on_trip_completion_or_driver_no_show()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_id uuid;
  v_offer_id uuid;
  v_current_balance int;
BEGIN
  -- Récupérer driver_id et offer_id
  SELECT driver_id INTO v_driver_id FROM trips WHERE id = NEW.id;
  SELECT id INTO v_offer_id
  FROM trip_offers
  WHERE trip_id = NEW.id AND status = 'accepted'
  LIMIT 1;

  -- CAS 1: Course complétée → Déduit jeton
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN

    -- Vérifier solde
    SELECT balance INTO v_current_balance
    FROM token_balances
    WHERE user_id = v_driver_id AND token_type = 'course';

    IF v_current_balance < 1 THEN
      RAISE WARNING 'Driver % has insufficient tokens', v_driver_id;
      RETURN NEW;
    END IF;

    -- Déduire jeton
    UPDATE token_balances
    SET balance = balance - 1,
        total_spent = total_spent + 1,
        updated_at = NOW()
    WHERE user_id = v_driver_id AND token_type = 'course';

    -- Marquer offre comme dépensée
    UPDATE trip_offers
    SET token_spent = true
    WHERE id = v_offer_id;

    -- Logger transaction
    INSERT INTO token_transactions (
      user_id,
      token_type,
      amount,
      reason,
      related_id,
      created_at
    ) VALUES (
      v_driver_id,
      'course',
      -1,
      'trip_completed',
      NEW.id,
      NOW()
    );

  -- CAS 2: Driver No Show → Déduit jeton
  ELSIF NEW.status = 'cancelled'
    AND OLD.status != 'cancelled'
    AND NEW.cancellation_reason = 'driver_no_show' THEN

    -- Vérifier solde
    SELECT balance INTO v_current_balance
    FROM token_balances
    WHERE user_id = v_driver_id AND token_type = 'course';

    IF v_current_balance < 1 THEN
      RAISE WARNING 'Driver % has insufficient tokens', v_driver_id;
      RETURN NEW;
    END IF;

    -- Déduire jeton (pénalité)
    UPDATE token_balances
    SET balance = balance - 1,
        total_spent = total_spent + 1,
        updated_at = NOW()
    WHERE user_id = v_driver_id AND token_type = 'course';

    -- Marquer offre comme dépensée
    UPDATE trip_offers
    SET token_spent = true
    WHERE id = v_offer_id;

    -- Logger transaction
    INSERT INTO token_transactions (
      user_id,
      token_type,
      amount,
      reason,
      related_id,
      created_at
    ) VALUES (
      v_driver_id,
      'course',
      -1,
      'driver_no_show_penalty',
      NEW.id,
      NOW()
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CRÉER trigger sur trips
CREATE TRIGGER trigger_spend_token_on_completion_or_no_show
  AFTER UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION spend_token_on_trip_completion_or_driver_no_show();
```

#### 3. UI Flutter - Annulation avec raison

```dart
// mobile_driver/lib/features/tracking/presentation/screens/driver_navigation_screen.dart

Future<void> _cancelTripWithReason(String reason) async {
  await _supabase.from('trips').update({
    'status': 'cancelled',
    'cancellation_reason': reason,
    'cancelled_at': DateTime.now().toIso8601String(),
  }).eq('id', widget.tripId);
}

// Bouton "Signaler Passager Absent"
ElevatedButton(
  onPressed: () async {
    await _cancelTripWithReason('rider_no_show');
    context.go('/home');
  },
  child: Text('Passager ne s\'est pas présenté'),
);
```

```dart
// mobile_rider/lib/features/order/presentation/screens/rider_tracking_screen.dart

// Bouton "Signaler Chauffeur Absent"
ElevatedButton(
  onPressed: () async {
    await _supabase.from('trips').update({
      'status': 'cancelled',
      'cancellation_reason': 'driver_no_show',
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.tripId);
    context.go('/home');
  },
  child: Text('Chauffeur ne s\'est pas présenté'),
);
```

### ✅ Avantages

1. ✅ **Simplicité** : Logique pure SQL/Triggers, pas de backend API
2. ✅ **Cohérence parfaite** avec besoin : "Jeton déduit en fin de course"
3. ✅ **Pas de déduction temporaire** : Solde toujours exact
4. ✅ **Équitable** : Driver ne perd jeton QUE si No Show de sa part
5. ✅ **Moins de code** : Pas de backend API à créer
6. ✅ **Performance** : Trigger SQL ultra-rapide
7. ✅ **Pas de dépendance** backend Node.js

### ❌ Inconvénients

1. ⚠️ **Pas d'historique No Show** structuré (pas de table dédiée)
2. ⚠️ **Pas de restrictions automatiques** pour récidivistes
3. ⚠️ **Risque d'abus** : Rien n'empêche faux signalements répétés
4. ⚠️ **UX moins guidée** : Simple annulation avec dropdown raison
5. ⚠️ **Pas de tableau de bord admin** pour gérer No Shows
6. ⚠️ **Migration existant** : Modifier trigger actif en production

### 📊 Effort d'Implémentation

- **Migration SQL** : 2-3 heures (désactiver ancien + créer nouveau)
- **UI Flutter** : 2-3 heures (boutons annulation avec raison)
- **Tests** : 1-2 heures
- **TOTAL** : ~5-8 heures

---

## 📊 Tableau Comparatif

| Critère                   | Approche 1 (APPZEDGO)               | Approche 2 (Sur-Mesure)           |
| ------------------------- | ----------------------------------- | --------------------------------- |
| **Moment déduction**      | ⚡ Au démarrage ('started')         | ⚡ À la complétion ('completed')  |
| **Rider No Show**         | ✅ Driver ne perd rien              | ✅ Driver ne perd rien            |
| **Driver No Show**        | ❌ Pénalité -1 jeton via API        | ❌ Pénalité -1 jeton via trigger  |
| **Complexité**            | ⚠️ Élevée (Backend + SQL + Flutter) | ✅ Faible (SQL + Flutter)         |
| **Backend requis**        | ⚠️ Oui (Node.js API)                | ✅ Non (SQL only)                 |
| **Historique No Show**    | ✅ Table dédiée + pénalités         | ❌ Seulement logs basiques        |
| **Protection abus**       | ✅ Restrictions progressives rider  | ❌ Aucune protection              |
| **Effort implémentation** | ⚠️ 12-17h                           | ✅ 5-8h                           |
| **Maintenance**           | ⚠️ Backend + SQL + Flutter          | ✅ SQL + Flutter                  |
| **Équité driver**         | ✅ 1 jeton perdu si No Show         | ✅ 1 jeton perdu si No Show       |
| **Équité rider**          | ✅ Warnings progressifs             | ⚠️ Aucune protection              |
| **UX utilisateur**        | ✅ Boutons explicites + historique  | ⚠️ Dropdown raison simple         |
| **Évolutivité**           | ✅ Admin panel + analytics          | ⚠️ Limitée                        |
| **Testabilité**           | ⚠️ Complexe (backend + DB)          | ✅ Simple (SQL only)              |
| **Risque perte jeton**    | ⚠️ Si crash APRÈS démarrage         | ✅ Seulement si vraiment complété |

---

## 🎯 Recommandation Finale

### 🥇 **Approche 2** - Recommandée pour UUMO

**Pourquoi Approche 2 > Approche 1 pour votre cas :**

| Aspect              | APPZEDGO (Approche 1)               | UUMO besoin (Approche 2)           |
| ------------------- | ----------------------------------- | ---------------------------------- |
| **Déduction**       | Au démarrage                        | À la complétion ✅                 |
| **Sécurité driver** | Perd jeton si crash après démarrage | Ne perd que si vraiment terminé ✅ |
| **Complexité**      | Backend API requis                  | Pure SQL/Triggers ✅               |
| **Effort**          | ~15h                                | ~6h ✅                             |

**Approche 2 est PLUS conservatrice qu'APPZEDGO** :

- APPZEDGO : Jeton déduit à 'started' → risque si problème technique
- UUMO : Jeton déduit à 'completed' → **maximum de sécurité**

### Court Terme (maintenant) : **Approche 2**

✅ **Rapidité** : Production en 1 semaine  
✅ **Simplicité** : Moins de bugs potentiels  
✅ **Sécurité** : Plus conservateur qu'APPZEDGO  
✅ **Cohérence** : Répond EXACTEMENT au besoin exprimé

### Moyen/Long Terme (3-6 mois) : **Ajouter features Approche 1**

Si besoin après feedback utilisateurs :

- ✅ Historique structuré No Shows
- ✅ Restrictions progressives riders
- ✅ Admin panel gestion signalements

**Mais garder déduction à 'completed'** (plus sûr qu'APPZEDGO)

---

## 🚀 Plan d'Action Recommandé

### Phase 1 : Implémentation Approche 2 (Semaine 1) ⭐

```
Jour 1-2 : Migration SQL + Tests DB
  - Créer ENUM cancellation_reason
  - Désactiver trigger actuel sur trip_offers
  - Créer nouveau trigger sur trips (completed + driver_no_show)
  - Tests unitaires SQL

Jour 3-4 : UI Flutter (Driver + Rider)
  - Ajouter dropdown cancellation_reason
  - Boutons "Passager absent" / "Chauffeur absent"
  - Tests UI

Jour 5   : Tests end-to-end
  - Scénarios complets
  - Vérification soldes jetons

Jour 6-7 : Buffer & déploiement
  - Documentation
  - Déploiement production
```

### Phase 2 : Évolution future (Optionnel - Mois 3-6)

**Seulement si abus constatés ou besoin admin :**

```
Semaine 1 : Table historique No Shows
Semaine 2 : Backend API simple (optionnel)
Semaine 3 : Admin panel basique
Semaine 4 : Tests & déploiement

MAIS GARDER déduction à 'completed' (plus sûr)
```

### Avantages de cette stratégie

1. ✅ **Solution immédiate** pour problème critique actuel
2. ✅ **Plus conservateur qu'APPZEDGO** (déduction à completed vs started)
3. ✅ **Feedback utilisateurs** avant investir dans features complexes
4. ✅ **Pas de dépendance backend** Node.js
5. ✅ **Simple à tester et maintenir**

---

## ❓ Questions pour Décision Finale

1. **Urgence** : Besoin de déployer dans combien de temps ?
2. **Ressources** : Backend Node.js déjà en place et maintenu ?
3. **Budget** : Préférence pour solution rapide ou complète ?
4. **Abus** : Avez-vous constaté des abus de No Show actuellement ?
5. **Admin** : Besoin d'un panel admin pour gérer les signalements ?

---

## 💡 Hybride Possible

**Approche 3** : Déduction à complétion + Table historique simple

```sql
-- Garde Approche 2 (déduction à complétion)
-- + Ajoute table simple pour historique

CREATE TABLE no_show_log (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid REFERENCES trips(id),
  reported_by uuid REFERENCES users(id),
  reported_user uuid REFERENCES users(id),
  user_type text, -- 'rider' ou 'driver'
  reason text,
  created_at timestamptz DEFAULT NOW()
);

-- Insérer dans table lors d'annulation No Show
-- via trigger ou manuellement dans UI
```

**Avantages** :

- ✅ Simplicité Approche 2
- ✅ Historique basique pour audit
- ✅ Base pour future Approche 1

**Effort** : +1-2 heures sur Approche 2

---

## 📞 Prochaine Étape - Décision Immédiate

### ✅ Ma Recommandation Forte : **Approche 2**

**Pourquoi :**

1. ✅ UUMO sera **plus sûr qu'APPZEDGO** (déduction à completed vs started)
2. ✅ Répond EXACTEMENT à votre besoin : _"jeton déduit en fin de course"_
3. ✅ Implémentation rapide : **5-8h au lieu de 15h**
4. ✅ Pas de dépendance backend complexe
5. ✅ Facile à tester et maintenir

**Correction de mon erreur initiale :**

- ❌ J'avais dit "Approche 1 = remboursement" → **FAUX**
- ✅ **VRAI** : APPZEDGO déduit au démarrage, pas à l'acceptation
- ✅ Approche 2 va **PLUS LOIN** qu'APPZEDGO en sécurité

### 🚀 Je commence maintenant ?

**Dites juste "oui" et je démarre l'implémentation Approche 2 :**

1. Migration SQL (désactiver trigger actuel + créer nouveau)
2. UI Flutter (boutons annulation avec raison)
3. Tests complets
4. Documentation

**Livraison estimée : 1 semaine** 📦

---

## 📚 Résumé Comparaison

|                    | APPZEDGO          | UUMO Actuel          | UUMO Approche 2      |
| ------------------ | ----------------- | -------------------- | -------------------- |
| **Déduction**      | À 'started'       | À 'accepted' ❌      | À 'completed' ✅     |
| **Rider No Show**  | Driver protégé    | Driver perd jeton ❌ | Driver protégé ✅    |
| **Driver No Show** | -1 jeton pénalité | Pas géré ❌          | -1 jeton pénalité ✅ |
| **Sécurité max**   | Moyenne           | Faible ❌            | **Maximum** ✅       |

**Approche 2 = Meilleure protection driver possible !** 🛡️
