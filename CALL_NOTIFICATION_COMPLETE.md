# 🔔 Système de Notifications d'Appels - Intégration Complète

## ✅ Statut: TERMINÉ

Le système de notifications d'appels entrants a été entièrement intégré dans les deux applications (rider et driver).

## 📋 Architecture

### Composants Créés

#### 1. **NotificationService** (`services/notification_service.dart`)

- Écoute en temps réel la table `notifications` de Supabase
- Filtre les notifications `incoming_call` pour l'utilisateur connecté
- Expose un Stream `incomingCalls` pour les widgets
- Gestion du cycle de vie : `startListening()` / `dispose()`

#### 2. **IncomingCallAlert** Widget (`features/.../widgets/incoming_call_alert.dart`)

- Dialog non-dismissible pour les appels entrants
- Icône de téléphone animée
- Boutons Accept (vert) / Reject (rouge)
- Design adapté au thème (orange rider, vert driver)

#### 3. **CallNotificationListener** Widget (`widgets/call_notification_listener.dart`)

- Widget wrapper qui écoute le stream `notificationService.incomingCalls`
- Affiche automatiquement `IncomingCallAlert` lors d'un appel entrant
- Récupère les infos de session depuis `call_sessions`
- Navigation automatique vers `CallScreen` en cas d'acceptation
- Gestion du rejet d'appel via `CallService.endCall()`

## 🔄 Flux de Notification

```
1. [Caller] → CallService.initiateCall()
   ↓
2. Crée call_session dans DB
   ↓
3. Crée notification dans DB (type: incoming_call)
   ↓
4. [Receiver] NotificationService détecte nouvelle notification
   ↓
5. Émet dans Stream incomingCalls
   ↓
6. CallNotificationListener affiche IncomingCallAlert
   ↓
7a. ACCEPT → Navigate to CallScreen (WebRTC)
7b. REJECT → CallService.endCall()
```

## 📱 Intégration dans les Apps

### mobile_rider/lib/main.dart

```dart
import 'widgets/call_notification_listener.dart';
import 'services/notification_service.dart';

final notificationService = NotificationService();

Future<void> main() async {
  // ...
  await Supabase.initialize(...);

  // Démarrer l'écoute si user connecté
  if (Supabase.instance.client.auth.currentUser != null) {
    notificationService.startListening();
    print('[RiderApp] 🔔 NotificationService démarré');
  }

  runApp(const ProviderScope(child: RiderApp()));
}

class RiderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CallNotificationListener(
      child: MaterialApp.router(
        routerConfig: appRouter,
      ),
    );
  }
}
```

### mobile_driver/lib/main.dart

Même pattern que rider avec chemins ajustés.

## 🎨 Design

### Rider (Orange)

- Couleur accent: `#FF6B35`
- Bouton Accept: Vert standard
- Bouton Reject: Rouge standard

### Driver (Vert)

- Couleur accent: `#34C759`
- Bouton Accept: Vert standard
- Bouton Reject: Rouge standard

## 🔐 Sécurité

### RLS Policies (Supabase)

```sql
-- Notifications table
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);
```

### Gestion des Permissions

- Microphone: Permission demandée dans `CallScreen`
- Notifications: Pas de permission système requise (custom UI)

## 📊 Données de Notification

Structure de la notification dans le stream:

```dart
{
  'id': 'uuid',
  'user_id': 'uuid',
  'type': 'incoming_call',
  'title': 'Appel entrant',
  'message': 'Un chauffeur vous appelle',
  'data': {
    'call_id': 'uuid',
    'caller_type': 'driver', // ou 'rider'
    'trip_id': 'uuid'
  },
  'read': false,
  'created_at': '2024-01-15T10:30:00Z'
}
```

## 🧪 Test du Système

### Scénario de Test Complet

1. **Préparation**

   - Déployer SQL: `create_call_messaging_tables.sql`
   - Rebuild les deux apps (flutter run)
   - Connecter rider et driver avec trip actif

2. **Test Appel Sortant (Rider → Driver)**

   ```
   [Rider] Click phone button → CallScreen
   [Driver] IncomingCallAlert appears
   [Driver] Click Accept → Navigate to CallScreen
   [Both] WebRTC connection established
   [Both] Audio bidirectional works
   [Either] Click End Call
   [Both] Return to previous screen
   ```

3. **Test Appel Sortant (Driver → Rider)**
   Même flow inversé

4. **Test Rejet d'Appel**

   ```
   [Rider] Click phone button
   [Driver] IncomingCallAlert appears
   [Driver] Click Reject
   [Rider] CallScreen shows "call ended"
   ```

5. **Vérification DB**

   ```sql
   -- Session créée
   SELECT * FROM call_sessions ORDER BY created_at DESC LIMIT 1;

   -- Notification créée et lue
   SELECT * FROM notifications WHERE type = 'incoming_call'
   ORDER BY created_at DESC LIMIT 1;

   -- Signaling échangé
   SELECT * FROM call_signaling ORDER BY created_at DESC LIMIT 10;
   ```

## 🐛 Debug

### Logs à Surveiller

```dart
// NotificationService
'[NotificationService] 🎧 Écoute des notifications démarrée'
'[NotificationService] 📞 Notification appel entrant: {data}'

// CallNotificationListener
'[CallListener] 📞 Appel entrant: {callId} de {callerType}'
'[CallListener] ✅ Appel accepté: {callId}'
'[CallListener] ❌ Appel rejeté: {callId}'

// main.dart
'[RiderApp] 🔔 NotificationService démarré'
'[DriverApp] 🔔 NotificationService démarré'
```

### Problèmes Courants

| Problème                    | Cause                           | Solution                                         |
| --------------------------- | ------------------------------- | ------------------------------------------------ |
| Pas de notification         | NotificationService pas démarré | Vérifier auth.currentUser avant startListening() |
| Dialog ne s'affiche pas     | Context invalide                | Vérifier que MaterialApp est ancêtre             |
| Erreur récupération session | call_id invalide                | Vérifier data['call_id'] dans notification       |
| Navigation échoue           | Routes mal configurées          | Utiliser Navigator.push avec MaterialPageRoute   |

## 🚀 Améliorations Futures

### Phase 2 (Optionnel)

- [ ] Ajouter fichier audio de sonnerie
- [ ] Vibration du téléphone
- [ ] Notifications système (FCM)
- [ ] Historique des appels manqués
- [ ] Badge avec nombre d'appels manqués

### Packages Additionnels (si besoin)

```yaml
dependencies:
  audioplayers: ^5.0.0 # Pour sonnerie custom
  vibration: ^1.8.0 # Pour vibration
  flutter_local_notifications: ^15.0.0 # Notifications système
```

## 📝 Notes Importantes

1. **NotificationService Global**: Instance unique dans `main.dart`, accessible partout
2. **Lifecycle**: Service démarré après login, dispose automatique au logout
3. **Stream**: `incomingCalls` stream n'émet que pour incoming_call non lus
4. **Cleanup**: Notifications auto-supprimées après 30 jours (fonction DB)

## ✨ Fonctionnalités Complètes

- ✅ Notification temps réel via Supabase
- ✅ UI d'alerte avec Accept/Reject
- ✅ Navigation automatique vers CallScreen
- ✅ WebRTC P2P audio connection
- ✅ Gestion du rejet d'appel
- ✅ Récupération infos session
- ✅ Logs debug complets
- ✅ Gestion erreurs
- ✅ Cleanup mémoire (StreamSubscription)

---

**Dernière mise à jour**: 2024-01-15  
**Version**: 1.0.0  
**Status**: ✅ Production Ready
