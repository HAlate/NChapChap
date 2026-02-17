# 📋 Analyse Complète du Flux de Négociation

## 🔍 Problème Identifié

Le driver ne reçoit **PAS** les logs de subscription du channel Realtime :

```
[DRIVER_DEBUG] watchOffer: Channel subscription status: RealtimeSubscribeStatus.subscribed
```

Ce log **devrait apparaître** immédiatement après :

```
[DRIVER_DEBUG] watchOffer: Setting up Realtime channel for offer xxx
```

## 📂 Fichiers Impliqués

### 1. **mobile_driver/lib/services/driver_offer_service.dart**

#### Méthode `watchOffer()` (lignes 443-545)

- ✅ Crée un `StreamController`
- ✅ Configure le channel Realtime sur la **table** `trip_offers` (pas la vue)
- ✅ Filtre par `id = offerId`
- ✅ Callback `.subscribe((status, [error]) { print(...) })`
- ❌ **PROBLÈME** : Le callback de `.subscribe()` ne s'exécute jamais

### 2. **mobile_driver/lib/features/negotiation/presentation/screens/driver_negotiation_screen.dart**

#### Provider (lignes 9-13)

```dart
final offerStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, offerId) {
  final tripOfferService = DriverOfferService();
  return tripOfferService.watchOffer(offerId);
});
```

- ✅ Utilise `autoDispose` (se nettoie automatiquement)
- ✅ Appelle `watchOffer()` du service
- ⚠️ **PROBLÈME POTENTIEL** : Crée une **nouvelle instance** de `DriverOfferService()` à chaque fois

#### Listener (lignes 46-85)

- ✅ Écoute les changements de statut
- ✅ Redirige vers `/driver-navigation` quand `status == 'accepted'`
- ✅ Recharge les données complètes du trip

### 3. **mobile_rider/lib/services/rider_offer_service.dart**

#### Méthode `sendCounterOffer()` (lignes 49-80)

```dart
final updates = <String, dynamic>{
  'status': 'selected',
  'counter_price': counterPrice,
};

final response = await _supabase
    .from('trip_offers')
    .update(updates)
    .match({'id': offerId})
    .select()
    .single();
```

- ✅ Update la **table** `trip_offers` (pas la vue)
- ✅ Met à jour `counter_price` et `status`
- ✅ Logs de debug présents

#### Méthode `watchOffer()` (lignes 246-310)

- ✅ Structure identique au driver
- ✅ Utilise un `StreamController`
- ✅ Écoute la **table** `trip_offers`
- ⚠️ **DIFFÉRENCE** : Nom du channel différent (`public:trip_offers:id=eq.$offerId` vs `driver-offer-and-trip-watcher-for-offer-$offerId`)

### 4. **mobile_rider/lib/features/trip/presentation/screens/negotiation_detail_screen.dart**

#### Provider (lignes 17-19)

```dart
final offerStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, offerId) {
  return ref.watch(riderOfferServiceProvider).watchOffer(offerId);
});
```

- ✅ Utilise un **provider** singleton (`riderOfferServiceProvider`)
- ✅ Meilleure pratique que créer une nouvelle instance

## 🐛 Bugs Identifiés

### Bug #1 : Instance Service Non Partagée (Driver)

```dart
// ❌ PROBLÈME dans driver_negotiation_screen.dart ligne 11
final tripOfferService = DriverOfferService();
```

**Conséquence** : Chaque fois que le provider est reconstruit, une **nouvelle instance** est créée, ce qui peut :

- Créer plusieurs channels Realtime pour le même offerId
- Ne pas nettoyer correctement les anciens channels
- Empêcher le callback `.subscribe()` de s'exécuter

### Bug #2 : Callback Subscribe Silencieux

Le callback `.subscribe((status, [error]) { ... })` ne s'exécute jamais.

**Hypothèses** :

1. **Channel non créé** : Le channel n'arrive pas à se créer à cause d'une erreur silencieuse
2. **Multiple instances** : Plusieurs instances de DriverOfferService créent des conflits
3. **RLS bloque toujours** : Même avec les nouvelles policies, il y a un problème de permissions

### Bug #3 : Noms de Channels Différents

- **Driver** : `'driver-offer-and-trip-watcher-for-offer-$offerId'`
- **Rider** : `'public:trip_offers:id=eq.$offerId'`

Supabase recommande des noms de channels **uniques** pour éviter les conflits. Les deux formats sont valides, mais il vaut mieux être cohérent.

## 🔧 Solutions Proposées

### Solution #1 : Créer un Provider Singleton (Driver)

Comme fait côté rider, créer un `driverOfferServiceProvider` :

```dart
// À ajouter dans un fichier providers.dart ou dans driver_offer_service.dart
final driverOfferServiceProvider = Provider<DriverOfferService>((ref) {
  return DriverOfferService();
});

// Dans driver_negotiation_screen.dart
final offerStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, offerId) {
  return ref.watch(driverOfferServiceProvider).watchOffer(offerId);
});
```

### Solution #2 : Ajouter Plus de Logs de Debug

Dans `watchOffer()`, ajouter des logs **avant** le `.subscribe()` :

```dart
print('[DRIVER_DEBUG] watchOffer: About to call .subscribe() on channel');
channel
    .onPostgresChanges(...)
    .onPostgresChanges(...)
    .subscribe((status, [error]) {
      print('[DRIVER_DEBUG] watchOffer: Subscribe callback called!');
      print('[DRIVER_DEBUG] watchOffer: Channel subscription status: $status');
      if (error != null) {
        print('[DRIVER_DEBUG] watchOffer: Channel subscription error: $error');
      }
    });
print('[DRIVER_DEBUG] watchOffer: .subscribe() has been called');
```

### Solution #3 : Vérifier les Policies UPDATE

Les policies RLS actuelles permettent-elles au **driver** de voir les UPDATE du **rider** ?

**Policy actuelle driver** :

```sql
CREATE POLICY "Drivers can view their offers"
ON trip_offers FOR SELECT
USING (auth.uid() = driver_id);
```

**CRITICAL** : Cette policy fonctionne pour les requêtes SELECT, mais **Realtime** doit aussi vérifier si le driver peut "voir" les changements faits par le rider.

Quand le **rider** (rider_id) update `counter_price`, Realtime doit vérifier :

1. ✅ Le rider peut UPDATE ? → Oui (policy "Riders can update offers")
2. ✅ Le driver peut SELECT cette row ? → Oui (policy "Drivers can view their offers")
3. ❓ Realtime peut-il NOTIFIER le driver ? → **À vérifier**

## 📊 Diagnostic Suivant

Pour identifier la cause exacte, il faut :

1. **Ajouter les logs manquants** (Solution #2)
2. **Créer le provider singleton** (Solution #1)
3. **Tester avec un channel simple** sans les `.onPostgresChanges()` multiples
4. **Vérifier les permissions Realtime** dans le dashboard Supabase

## 🎯 Action Immédiate

Je vais créer un fix qui combine les 3 solutions.
