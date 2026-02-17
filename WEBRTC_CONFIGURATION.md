# Configuration WebRTC pour UUMO

## Configuration Android

### 1. Permissions dans AndroidManifest.xml

Ajouter dans `mobile_rider/android/app/src/main/AndroidManifest.xml` et `mobile_driver/android/app/src/main/AndroidManifest.xml` :

```xml
<manifest>
    <!-- Permissions WebRTC -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- Permissions optionnelles mais recommandées -->
    <uses-feature android:name="android.hardware.audio.low_latency" android:required="false" />

    <application>
        ...
    </application>
</manifest>
```

### 2. ProGuard Rules (si minification activée)

Ajouter dans `android/app/proguard-rules.pro` :

```proguard
# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
```

## Configuration iOS

### 1. Permissions dans Info.plist

Ajouter dans `mobile_rider/ios/Runner/Info.plist` et `mobile_driver/ios/Runner/Info.plist` :

```xml
<dict>
    ...
    <!-- Permission microphone -->
    <key>NSMicrophoneUsageDescription</key>
    <string>UUMO a besoin d'accéder au microphone pour les appels vocaux entre passagers et chauffeurs</string>

    <!-- Permission Bluetooth (optionnel, pour casques) -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>UUMO a besoin d'accéder au Bluetooth pour utiliser vos écouteurs pendant les appels</string>

    <!-- Background modes (pour appels en arrière-plan) -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>voip</string>
    </array>
</dict>
```

### 2. Podfile (si nécessaire)

Dans `ios/Podfile`, vérifier que la version minimum est au moins 12.0 :

```ruby
platform :ios, '12.0'
```

## Configuration Supabase

### 1. Exécuter le script SQL

```bash
# Via psql
psql -h [SUPABASE_HOST] -U postgres -d postgres -f create_call_messaging_tables.sql

# Ou via Supabase Dashboard > SQL Editor
# Copier-coller le contenu de create_call_messaging_tables.sql
```

### 2. Vérifier les politiques RLS

Les politiques RLS sont automatiquement créées par le script. Vérifier dans :

- Supabase Dashboard > Database > Policies

### 3. Activer Realtime sur les tables

Dans Supabase Dashboard > Database > Replication :

- Activer `call_sessions`
- Activer `call_signaling`
- Activer `trip_messages`
- Activer `notifications`

## Configuration TURN Servers (Production)

Pour la production, remplacer les serveurs TURN publics par vos propres serveurs :

### Option 1: Coturn (Open Source)

1. Installer Coturn sur un VPS
2. Configurer dans `webrtc_service.dart` :

```dart
{
  'urls': 'turn:your-turn-server.com:3478',
  'credential': 'your-secret',
  'username': 'your-username'
}
```

### Option 2: Services Cloud

**Twilio TURN**

```dart
{
  'urls': 'turn:global.turn.twilio.com:3478?transport=udp',
  'credential': 'YOUR_TWILIO_CREDENTIAL',
  'username': 'YOUR_TWILIO_USERNAME'
}
```

**Xirsys**

```dart
{
  'urls': 'turn:YOUR_DOMAIN.xirsys.com:3478',
  'credential': 'YOUR_XIRSYS_CREDENTIAL',
  'username': 'YOUR_XIRSYS_USERNAME'
}
```

## Test de Connexion

### 1. Test local

```bash
# Terminal 1 - Rider app
cd mobile_rider
flutter run

# Terminal 2 - Driver app
cd mobile_driver
flutter run
```

### 2. Vérifier les logs

Rechercher dans les logs :

```
[WebRTC] Initializing peer connection...
[WebRTC] Local stream obtained
[WebRTC] Creating offer...
[WebRTC] Connection state: connected
```

### 3. Test des fonctionnalités

- ✅ Initier un appel depuis rider
- ✅ Recevoir l'appel sur driver
- ✅ Accepter/rejeter l'appel
- ✅ Audio bidirectionnel
- ✅ Boutons muet/haut-parleur
- ✅ Terminer l'appel
- ✅ Durée d'appel enregistrée

## Troubleshooting

### Erreur: "Permission denied"

- Vérifier que les permissions sont bien dans AndroidManifest.xml/Info.plist
- Demander les permissions au runtime avec permission_handler

### Erreur: "ICE connection failed"

- Vérifier la configuration TURN/STUN
- Tester avec différents réseaux (WiFi, 4G)
- Vérifier les firewalls

### Pas d'audio

- Vérifier que le microphone fonctionne
- Tester avec `flutter_webrtc` en debug
- Vérifier les contraintes audio dans `webrtc_service.dart`

### Signalisation ne fonctionne pas

- Vérifier que Realtime est activé sur Supabase
- Vérifier les politiques RLS
- Vérifier les logs Supabase

## Performance et Optimisation

### 1. Réduire la latence

- Utiliser des serveurs TURN proches géographiquement
- Activer le codec Opus pour l'audio
- Désactiver l'echo cancellation si pas nécessaire

### 2. Gestion de la batterie

- Terminer proprement les connexions WebRTC
- Utiliser des timers pour détecter les appels abandonnés
- Implémenter un timeout pour les appels non répondus

### 3. Monitoring

- Logger les durées d'appels
- Tracker les échecs de connexion
- Monitorer la qualité audio (via stats WebRTC)

## Sécurité

### 1. Authentification

- ✅ Tous les appels requièrent l'authentification Supabase
- ✅ RLS empêche l'accès non autorisé aux sessions

### 2. Chiffrement

- ✅ WebRTC utilise DTLS/SRTP pour chiffrer l'audio
- ✅ Signalisation chiffrée via HTTPS/WSS

### 3. Privacy

- ✅ Numéros de téléphone jamais exposés
- ✅ Appels liés uniquement au trajet
- ✅ Historique automatiquement nettoyé après 24h

## Support

Pour tout problème, vérifier :

1. Les logs Flutter/WebRTC
2. Les logs Supabase
3. La configuration réseau
4. Les permissions système
