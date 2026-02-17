# Intégration du système de sonnerie pour appels WebRTC

## Problème résolu

Le système d'appels WebRTC fonctionnait, mais le destinataire ne recevait pas de sonnerie/notification visuelle pour les appels entrants.

## Solution implémentée

### 1. Service de notifications créé

- **Fichier**: `lib/services/notification_service.dart` (rider + driver)
- **Fonction**: Écoute en temps réel les notifications Supabase
- **Stream**: Expose un stream `incomingCalls` pour les appels entrants

### 2. Widget d'alerte créé

- **Fichier**: `lib/features/.../widgets/incoming_call_alert.dart`
- **Fonction**: Affiche un dialogue avec boutons Accepter/Rejeter
- **Design**: Style UUMO avec couleurs (Orange pour Rider, Vert pour Driver)

## Intégration dans votre application

### Étape 1: Initialiser le service dans main()

Ajouter dans `lib/main.dart` :

```dart
import 'package:mobile_rider/services/notification_service.dart';

// Variable globale pour le service
final notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... (initialisation Supabase existante)

  // Démarrer l'écoute des notifications après auth
  if (Supabase.instance.client.auth.currentUser != null) {
    notificationService.startListening();
  }

  runApp(const MyApp());
}
```

### Étape 2: Écouter les appels entrants

Dans l'écran principal (HomeScreen, MapScreen, etc.) :

```dart
import 'package:mobile_rider/services/notification_service.dart';
import 'package:mobile_rider/features/order/presentation/widgets/incoming_call_alert.dart';
import 'package:mobile_rider/features/order/presentation/screens/call_screen.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  // ...
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    _callSubscription = notificationService.incomingCalls.listen((notification) {
      final data = notification['data'] as Map<String, dynamic>;
      final callId = data['call_id'] as String;
      final callerType = data['caller_type'] as String;

      // Afficher l'alerte d'appel entrant
      IncomingCallAlert.show(
        context: context,
        callId: callId,
        tripId: '', // Récupérer depuis notification si nécessaire
        callerName: callerType == 'rider' ? 'Passager' : 'Chauffeur',
        callerType: callerType,
        onAccept: () {
          // Naviguer vers l'écran d'appel
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                callId: callId,
                tripId: '', // À récupérer
                receiverId: '', // ID du destinataire
                receiverName: callerType == 'rider' ? 'Passager' : 'Chauffeur',
                isIncoming: true,
              ),
            ),
          );
        },
        onReject: () {
          // Rejeter l'appel
          final callService = CallService();
          callService.endCall(callId);
        },
      );
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... votre UI existant
  }
}
```

### Étape 3: Gérer la déconnexion

Dans votre écran de déconnexion :

```dart
void logout() {
  notificationService.dispose();
  // ... reste de la déconnexion
}
```

## Améliorations possibles

### 1. Ajouter un son de sonnerie

```dart
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  final AudioPlayer _player = AudioPlayer();

  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;

    if (type == 'incoming_call') {
      // Jouer le son de sonnerie
      _player.play(AssetSource('sounds/ringtone.mp3'));

      _incomingCallController.add(notification);
      _markAsRead(notification['id'] as String);
    }
  }

  // Arrêter la sonnerie quand l'appel est accepté/rejeté
  void stopRingtone() {
    _player.stop();
  }
}
```

### 2. Vibration

Ajouter dans `pubspec.yaml` :

```yaml
dependencies:
  vibration: ^1.8.4
```

Puis dans `NotificationService` :

```dart
import 'package:vibration/vibration.dart';

void _handleNotification(Map<String, dynamic> notification) {
  if (type == 'incoming_call') {
    // Vibrer
    Vibration.vibrate(pattern: [0, 500, 500, 500], repeat: 0);

    // ... reste du code
  }
}
```

### 3. Notification système (Android/iOS)

Pour les notifications même quand l'app est en arrière-plan, utilisez `flutter_local_notifications`.

## Tests

1. **Rider initie un appel** → Driver doit voir l'alerte
2. **Driver initie un appel** → Rider doit voir l'alerte
3. **Accepter l'appel** → Navigation vers CallScreen
4. **Rejeter l'appel** → Call session marquée comme "rejected"

## Troubleshooting

### L'alerte ne s'affiche pas

- Vérifier que `notificationService.startListening()` est appelé après auth
- Vérifier les logs: `[NotificationService] 📞 Appel entrant reçu!`
- Vérifier que la table `notifications` reçoit bien les données dans Supabase

### L'appel se lance mais pas de donnée

- Vérifier que `initiateCall()` crée bien une notification
- Regarder les logs SQL dans Supabase Dashboard
- Vérifier les politiques RLS sur la table `notifications`

### BuildContext invalide

- Utiliser un GlobalKey pour le navigateur
- Ou passer le BuildContext via un Provider/Riverpod

## Exemple complet

Voir les fichiers:

- `mobile_rider/lib/services/notification_service.dart`
- `mobile_driver/lib/services/notification_service.dart`
- `mobile_rider/lib/features/order/presentation/widgets/incoming_call_alert.dart`
- `mobile_driver/lib/features/tracking/presentation/widgets/incoming_call_alert.dart`

## Résumé

✅ **Service créé** : `NotificationService` pour écouter les appels
✅ **Widget créé** : `IncomingCallAlert` pour l'UI de sonnerie
✅ **Integration guide** : Instructions complètes ci-dessus

Il suffit maintenant d'intégrer le service dans votre écran principal pour que les appels entrants déclenchent une sonnerie visuelle !
