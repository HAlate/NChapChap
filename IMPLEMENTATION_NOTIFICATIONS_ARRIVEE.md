# Implémentation des notifications d'arrivée et gestion d'annulation

## Fonctionnalités implémentées

### 1. Notification d'arrivée du chauffeur ✅

#### Côté Chauffeur (mobile_driver)
- **Bouton modifié** : Le bouton existant "Je suis arrivé" dans `driver_tracking_screen.dart` effectue maintenant deux actions :
  1. Met à jour le statut du trip à 'arrived'
  2. Envoie une notification au passager en mettant à jour le champ `driver_arrived_notification`

#### Côté Passager (mobile_rider)
- **Réception de la notification** : L'écran `rider_tracking_screen.dart` écoute les changements du trip
- **Son "ding ding"** : Joue deux fois le son système d'alerte (intervalle de 300ms)
- **Notification visuelle** : Affiche un dialogue AlertDialog avec :
  - Icône de notification orange
  - Message : "Votre chauffeur est arrivé !"
  - Nom du chauffeur : "{nom} vous attend au point de départ."

### 2. Gestion de l'annulation côté chauffeur ✅

Quand un passager annule une course :
- **Détection automatique** : Le chauffeur reçoit une mise à jour du statut 'cancelled'
- **Notification visuelle** : SnackBar rouge avec le message "La course a été annulée par le passager."
- **Redirection automatique** : Après 1 seconde, redirection vers la page d'accueil du chauffeur (`/driver-home`)

## Fichiers modifiés

### 1. Backend - Service de tracking
**Fichier** : `mobile_driver/lib/services/tracking_service.dart`

Nouvelle méthode ajoutée :
```dart
/// Notifie le passager que le chauffeur est arrivé (notification manuelle).
Future<void> notifyRiderDriverArrived(String tripId) async {
  await _supabase.from('trips').update({
    'driver_arrived_notification': DateTime.now().toIso8601String(),
  }).eq('id', tripId);
}
```

### 2. Mobile Driver - Écran de tracking
**Fichier** : `mobile_driver/lib/features/tracking/presentation/screens/driver_tracking_screen.dart`

**Modification du bouton "Je suis arrivé"** (lignes ~550-580) :
```dart
onPressed: () async {
  try {
    // Mettre à jour le statut
    await ref.read(trackingServiceProvider).updateTripStatus(
      widget.tripData['tripId'], 'arrived',
    );
    // Envoyer la notification au passager
    await ref.read(trackingServiceProvider).notifyRiderDriverArrived(
      widget.tripData['tripId']
    );
  } catch (e) {
    // Gestion d'erreur
  }
}
```

**Gestion de l'annulation** (lignes ~230-250) :
```dart
ref.listen<AsyncValue<Map<String, dynamic>>>(
  tripStreamProvider(widget.tripData['tripId']), (prev, next) {
    final status = next.value?['status'] as String?;
    
    // Vérifier si la course a été annulée
    if (status == 'cancelled' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La course a été annulée par le passager.'),
          backgroundColor: Colors.red,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.go('/driver-home');
      });
      return;
    }
    // ...
  }
);
```

### 3. Mobile Rider - Écran de tracking
**Fichier** : `mobile_rider/lib/features/order/presentation/screens/rider_tracking_screen.dart`

**Import ajouté** :
```dart
import 'package:flutter/services.dart'; // Pour SystemSound
```

**Variable d'état ajoutée** :
```dart
String? _lastNotificationTime; // Pour éviter les notifications dupliquées
```

**Fonction de notification** (lignes ~150-200) :
```dart
void _notifyDriverArrived() {
  // Jouer "ding ding"
  SystemSound.play(SystemSoundType.alert);
  Future.delayed(const Duration(milliseconds: 300), () {
    SystemSound.play(SystemSoundType.alert);
  });

  // Afficher dialogue
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notifications_active, 
              color: AppTheme.primaryOrange, size: 32),
          const SizedBox(width: 12),
          const Text('Votre chauffeur est arrivé !'),
        ],
      ),
      content: Text('${widget.driver['full_name']} vous attend...'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

**Listener ajouté** (lignes ~320-330) :
```dart
ref.listen<AsyncValue<Map<String, dynamic>>>(
  tripStreamProvider(widget.tripId), (prev, next) {
    // ...
    
    // Détecter notification d'arrivée
    final notificationTime = next.value?['driver_arrived_notification'] as String?;
    if (notificationTime != null && 
        notificationTime != _lastNotificationTime &&
        mounted) {
      _lastNotificationTime = notificationTime;
      _notifyDriverArrived();
    }
  }
);
```

## Migration SQL requise ⚠️

**Fichier** : `supabase/migrations/20251216_add_driver_arrived_notification.sql`

Cette migration ajoute le champ nécessaire à la table `trips` :

```sql
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS driver_arrived_notification TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN trips.driver_arrived_notification IS 
'Timestamp de la dernière notification manuelle envoyée par le chauffeur';
```

### Comment appliquer la migration

**Option 1 - Via Supabase Dashboard (RECOMMANDÉ)** :
1. Connectez-vous à https://app.supabase.com
2. Allez dans **SQL Editor**
3. Copiez-collez le contenu du fichier de migration
4. Cliquez sur **Run**

**Option 2 - Via Supabase CLI** :
```bash
supabase db push
```

## Test du système

### Scénario 1 : Notification d'arrivée

1. **Passager** : Créez une course dans mobile_rider
2. **Chauffeur** : Faites une offre et acceptez la course
3. **Chauffeur** : Dans l'écran de tracking, cliquez sur "Je suis arrivé"
4. **Résultat attendu** :
   - Statut de la course passe à 'arrived'
   - Le passager entend deux "ding" (300ms d'intervalle)
   - Le passager voit un dialogue : "Votre chauffeur est arrivé !"
   - Le nom du chauffeur apparaît dans le message

### Scénario 2 : Annulation par le passager

1. **Passager** : Créez une course et acceptez une offre
2. **Chauffeur** : Vous êtes dans l'écran de tracking
3. **Passager** : Annulez la course dans mobile_rider
4. **Résultat attendu** :
   - Le chauffeur voit un SnackBar rouge : "La course a été annulée..."
   - Après 1 seconde, redirection automatique vers la home du chauffeur
   - Pas de crash, pas de blocage

## Notes techniques

### Son de notification
- Utilise `SystemSound.play(SystemSoundType.alert)` (natif Flutter)
- Joué deux fois pour effet "ding ding"
- Pas besoin de package audio supplémentaire
- Fonctionne sur iOS et Android

### Prévention des doublons
- La variable `_lastNotificationTime` mémorise le dernier timestamp
- Compare avec la nouvelle valeur avant d'afficher la notification
- Évite les notifications multiples si le stream se met à jour plusieurs fois

### Gestion des erreurs
- Try-catch autour de l'appel au service
- SnackBar rouge si erreur lors de l'envoi de la notification
- Le chauffeur peut réessayer si nécessaire

### Navigation sécurisée
- Vérifie `mounted` avant toute opération UI
- Utilise `Future.delayed` pour laisser le temps à la SnackBar de s'afficher
- Redirection via `context.go()` (GoRouter)

## Points d'attention

1. **Migration SQL obligatoire** : Le système ne fonctionnera pas sans le champ `driver_arrived_notification` dans la table `trips`

2. **Permissions son** : Sur certains appareils, les sons système peuvent être désactivés si le téléphone est en mode silencieux

3. **Real-time** : Supabase doit être configuré pour les mises à jour en temps réel sur la table `trips`

4. **Route driver-home** : Assurez-vous que la route `/driver-home` existe dans `app_router.dart`

## Améliorations futures possibles

- [ ] Vibration du téléphone en plus du son
- [ ] Son personnalisé (avec package audioplayers)
- [ ] Push notification native (avec Firebase Cloud Messaging)
- [ ] Historique des notifications dans l'interface
- [ ] Confirmation de lecture par le passager
