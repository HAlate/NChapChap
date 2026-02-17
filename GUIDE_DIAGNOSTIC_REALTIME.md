# 🔍 Guide de Diagnostic - Realtime Non Fonctionnel

## Problème

Les offres ne s'affichent pas en temps réel sur `mobile_rider` - le rider doit rafraîchir manuellement pour voir les nouvelles offres des drivers.

## Architecture Realtime (Comparaison avec APPZEDGO)

### ✅ Ce qui fonctionne dans APPZEDGO

**Code Flutter (identique dans UUMO)**:

```dart
Stream<List<TripOffer>> watchOffersForTrip(String tripId) {
  final controller = StreamController<List<TripOffer>>();

  Future<void> fetchAndPushOffers() async {
    final offers = await getOffersForTrip(tripId);
    if (!controller.isClosed) {
      controller.add(offers);
    }
  }

  fetchAndPushOffers(); // Chargement initial

  final channel = _supabase.channel('trip-offers-for-trip-$tripId');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'trip_offers',
    callback: (payload) {
      if (payload.newRecord['trip_id'] == tripId) {
        fetchAndPushOffers(); // Recharge à chaque changement
      }
    },
  ).subscribe();

  return controller.stream;
}
```

**Utilisation dans l'écran**:

```dart
StreamBuilder<List<TripOffer>>(
  stream: _offersService.watchOffersForTrip(widget.tripId),
  builder: (context, snapshot) {
    final offers = snapshot.data ?? [];
    return _buildOffersScreen(offers);
  },
)
```

## 🔧 Checklist de Diagnostic

### 1. Vérifier REPLICA IDENTITY ✅

**Exécuter**: `check_and_enable_realtime.sql`

Cette commande configure la table pour capturer tous les changements:

```sql
ALTER TABLE public.trip_offers REPLICA IDENTITY FULL;
```

**Résultat attendu**:

```
replica_identity = 'FULL'
```

### 2. Activer Realtime dans Supabase Dashboard 🔴 CRITIQUE

**IMPORTANT**: Cette étape est OBLIGATOIRE et NE PEUT PAS être faite via SQL.

**Étapes**:

1. Ouvrir https://supabase.com/dashboard
2. Sélectionner votre projet UUMO
3. Aller dans **Database** → **Replication**
4. Chercher la table `trip_offers` dans la liste
5. **Cocher la case** à côté de `trip_offers`
6. Cliquer sur **Save** en bas de page
7. Attendre la confirmation (peut prendre 5-10 secondes)

**Signes que ce n'est PAS activé**:

- Les logs Flutter montrent `DEBUG Realtime: Subscription status: SUBSCRIBED` mais aucun événement n'arrive
- Aucun message `DEBUG Realtime: Received payload: INSERT` dans les logs
- Les offres apparaissent seulement après un hot reload ou navigation

### 3. Vérifier les Logs Flutter

**Redémarrer l'app mobile_rider** avec:

```bash
cd mobile_rider
flutter run
```

**Logs attendus** (quand un driver fait une offre):

```
DEBUG: Fetching offers for trip_id: xxx-xxx-xxx
DEBUG Realtime: Subscription status: SUBSCRIBED
DEBUG Realtime: Received payload: INSERT
DEBUG Realtime: INSERT detected for our trip. Refetching all offers.
DEBUG: Fetching offers for trip_id: xxx-xxx-xxx
DEBUG: Total offers found: 1
DEBUG WaitingOffers: Received 1 offers
```

**Si vous voyez**:

```
DEBUG Realtime: Subscription status: SUBSCRIBED
```

...mais jamais de `Received payload`, alors le Realtime n'est **PAS activé dans le Dashboard**.

### 4. Vérifier les RLS Policies

Exécuter depuis SQL Editor:

```sql
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'trip_offers'
ORDER BY policyname;
```

**Policies requises**:

- `Riders can view offers for their trips` (SELECT)
- `Drivers can view their own offers` (SELECT)
- `Drivers can insert offers` (INSERT)
- `Riders can update offer status` (UPDATE)
- `Drivers can update their own offers` (UPDATE)

Si une policy manque, exécuter: `fix_trip_offers_rls_policies.sql`

### 5. Test End-to-End

#### Scénario de Test:

1. **Rider**: Créer une demande de course depuis mobile_rider

   - Noter le `trip_id` dans les logs
   - Arriver sur `WaitingOffersScreen`
   - Laisser l'écran ouvert

2. **Driver**: Ouvrir mobile_driver

   - Voir la demande dans la liste
   - Faire une offre
   - Observer les logs mobile_driver

3. **Rider**: Observer l'écran mobile_rider
   - L'offre doit apparaître **automatiquement** (sans toucher l'écran)
   - Délai normal: 100-500ms
   - Vérifier les logs pour `DEBUG Realtime: Received payload: INSERT`

#### Résultats Attendus:

**✅ SUCCESS**:

- L'offre apparaît en moins de 1 seconde
- Logs montrent `INSERT detected for our trip. Refetching all offers.`
- Le nombre d'offres s'incrémente automatiquement

**❌ ÉCHEC** (Realtime non activé):

- L'offre n'apparaît PAS automatiquement
- Logs montrent `Subscription status: SUBSCRIBED` mais rien après
- Besoin de hot reload ou retour/navigation pour voir l'offre

### 6. Vérifier la Publication Postgres

Exécuter:

```sql
SELECT
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
    AND tablename = 'trip_offers';
```

**Si la requête ne retourne AUCUNE ligne**:
→ Le Realtime n'est PAS activé dans le Dashboard
→ Retourner à l'étape 2 et activer via Dashboard

**Si la requête retourne une ligne**:
→ Le Realtime est activé ✅

## 🔄 Comparaison APPZEDGO vs UUMO

| Aspect                             | APPZEDGO         | UUMO             | Status                  |
| ---------------------------------- | ---------------- | ---------------- | ----------------------- |
| Code Flutter `watchOffersForTrip`  | ✅ Implémenté    | ✅ Identique     | ✅ OK                   |
| Code Flutter `WaitingOffersScreen` | ✅ StreamBuilder | ✅ StreamBuilder | ✅ OK                   |
| View `trip_offers_with_driver`     | ✅ Existe        | ✅ Existe        | ✅ OK                   |
| REPLICA IDENTITY                   | ✅ FULL          | ⚠️ À vérifier    | ⏳ Exécuter script      |
| Realtime Dashboard                 | ✅ Activé        | ❓ À vérifier    | ⏳ Activer manuellement |
| RLS Policies                       | ✅ Configuré     | ✅ Scripts prêts | ✅ OK                   |

## 🚨 Erreurs Courantes

### Erreur 1: "Subscription successful but no events"

**Symptôme**:

```
DEBUG Realtime: Subscription status: SUBSCRIBED
[...plus aucun log...]
```

**Cause**: Realtime non activé dans Dashboard

**Solution**: Aller dans Dashboard → Database → Replication → Cocher `trip_offers`

### Erreur 2: "Channel already exists"

**Symptôme**:

```
Error: Channel trip-offers-for-trip-xxx already exists
```

**Cause**: Multiple instances du StreamBuilder ou hot reload sans cleanup

**Solution**:

- Hot restart (au lieu de hot reload)
- Vérifier que `controller.onCancel` appelle `channel.unsubscribe()`

### Erreur 3: "Permission denied for table trip_offers"

**Symptôme**:

```
PostgrestException: permission denied for table trip_offers
```

**Cause**: RLS policies manquantes ou incorrectes

**Solution**: Exécuter `fix_trip_offers_rls_policies.sql`

## 📋 Action Items

### Étape 1: Configuration Database ⏳

- [ ] Exécuter `check_and_enable_realtime.sql`
- [ ] Vérifier résultat: REPLICA IDENTITY = FULL

### Étape 2: Activation Dashboard 🔴 CRITIQUE

- [ ] Ouvrir Supabase Dashboard
- [ ] Database → Replication
- [ ] Cocher `trip_offers`
- [ ] Cliquer Save
- [ ] Attendre confirmation

### Étape 3: Vérification SQL ✅

- [ ] Exécuter requête `pg_publication_tables`
- [ ] Confirmer que `trip_offers` est dans la publication

### Étape 4: Test Flutter 🧪

- [ ] Hot restart mobile_rider
- [ ] Créer trip, aller sur WaitingOffers
- [ ] Observer logs pour `Subscription status: SUBSCRIBED`
- [ ] Faire offre depuis mobile_driver
- [ ] Confirmer que `INSERT detected` apparaît dans logs rider
- [ ] Confirmer que l'offre apparaît automatiquement

### Étape 5: Test Multi-Offres 🎯

- [ ] Créer un trip
- [ ] 2-3 drivers font des offres
- [ ] Confirmer que toutes apparaissent en temps réel
- [ ] Accepter une offre
- [ ] Confirmer que les autres passent à `not_selected`

## 💡 Notes Importantes

1. **REPLICA IDENTITY FULL est requis** pour que Supabase Realtime puisse capturer les UPDATE et DELETE avec toutes les colonnes.

2. **L'activation Dashboard est OBLIGATOIRE** - même avec REPLICA IDENTITY configuré, sans l'activation dans le Dashboard, aucun événement ne sera émis.

3. **Les logs sont essentiels** - sans les logs `DEBUG Realtime`, impossible de diagnostiquer.

4. **Hot restart > Hot reload** - Pour tester le Realtime, toujours faire un hot restart complet après des changements de configuration.

5. **La vue n'est PAS écoutée** - Le stream écoute la TABLE `trip_offers`, pas la vue `trip_offers_with_driver`. Quand un événement arrive, on recharge depuis la vue.

## 🎯 Prochaines Étapes

Une fois le Realtime fonctionnel:

1. Tester le scénario complet rider/driver
2. Tester la négociation en temps réel
3. Tester l'acceptation d'offre
4. Vérifier que le trigger de déduction de jeton fonctionne au démarrage du trip

## 📚 Références

- Documentation Supabase Realtime: https://supabase.com/docs/guides/realtime
- APPZEDGO Implementation: `mobile_rider/lib/services/rider_offer_service.dart`
- Flutter StreamBuilder: https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html
