# Guide Rapide - Tests Audio WebRTC

## Option 1: Test Immédiat (Même WiFi) ⚡

### Prérequis

- Les 2 appareils (rider et driver) sur le **même réseau WiFi**
- Configuration actuelle suffit (serveurs STUN déjà en place)

### Étapes

1. **Connectez les 2 appareils au même WiFi**

2. **Hot restart les 2 apps:**

   ```bash
   # Dans les terminaux Flutter
   Shift + R
   ```

3. **Lancez un appel:**
   - Rider initie un appel vers le driver
   - Driver accepte
   - **L'audio devrait fonctionner!** 🎉

### Pourquoi ça marche?

Sur le même réseau local, les appareils peuvent se connecter directement via leurs adresses locales. Les serveurs STUN (déjà configurés) permettent de découvrir ces adresses sans besoin de TURN.

### Vérification

Si l'audio fonctionne, vous verrez dans les logs:

```
[WebRTC] ICE connection state: RTCIceConnectionStateConnected
[CallScreen] Connection state changed: RTCPeerConnectionStateConnected
```

Si l'audio ne fonctionne toujours pas:

- Vérifiez les permissions microphone
- Vérifiez que les appareils sont bien sur le même WiFi (pas 5GHz vs 2.4GHz)
- Regardez les logs ICE candidates - vous devriez voir des candidates de type "host"

---

## Option 2: Production (Serveur TURN) 🚀

Pour les appels à travers Internet (appareils sur réseaux différents), vous avez besoin d'un serveur TURN.

### Déploiement Express (15 minutes)

#### 1. Préparer un VPS

**Fournisseurs recommandés:**

- **DigitalOcean** - 6$/mois (droplet Basic)
- **OVH** - 3.50F/mois (VPS Starter)
- **Hetzner** - 4.15F/mois (CX11)

**Spécifications minimales:**

- Ubuntu 22.04 LTS
- 1 vCPU
- 1 GB RAM
- 25 GB SSD

#### 2. Installation Automatique

Connectez-vous au VPS:

```bash
ssh root@VOTRE_IP_VPS
```

Téléchargez et exécutez le script d'installation:

```bash
# Télécharger le script
curl -o install-turn-server.sh https://raw.githubusercontent.com/votrecompte/UUMO/main/install-turn-server.sh

# Rendre exécutable
chmod +x install-turn-server.sh

# Exécuter
./install-turn-server.sh
```

Le script vous demandera:

1. Le domaine ou utilisera l'IP par défaut
2. Si vous voulez configurer SSL (recommandé si domaine disponible)

**Temps d'installation:** ~5 minutes

#### 3. Configuration du Firewall Provider

⚠️ **Important:** Configurez le firewall de votre provider VPS!

**DigitalOcean:**

1. Allez dans Networking → Firewalls
2. Créez un firewall
3. Règles entrantes:
   - SSH (22/tcp)
   - Custom (3478/tcp)
   - Custom (3478/udp)
   - Custom (5349/tcp)
   - Custom (5349/udp)
   - Custom (49152-65535/udp)

**OVH/Hetzner:**

1. Accédez au panneau de firewall
2. Autorisez les mêmes ports

#### 4. Tester le Serveur

Générez des credentials de test:

```bash
generate-turn-credentials
```

Testez sur: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

Collez:

- URI: `turn:VOTRE_IP:3478`
- Username: (copié depuis generate-turn-credentials)
- Password: (copié depuis generate-turn-credentials)

Cliquez "Gather candidates" → Vous devriez voir des candidates de type "relay"

#### 5. Configuration Flutter (Tests)

**Méthode rapide (pour tests uniquement):**

Créez un fichier de config dans les deux apps:

```dart
// lib/config/turn_config.dart
class TurnConfig {
  static const String server = 'VOTRE_IP_OU_DOMAINE';
  static const String secret = 'VOTRE_SECRET'; // Depuis le script d'installation

  static bool useCustomTurn = true; // Mettez false pour revenir aux serveurs gratuits
}
```

Mettez à jour `webrtc_service.dart`:

```dart
Future<void> initialize() async {
  Map<String, dynamic> configuration;

  if (TurnConfig.useCustomTurn) {
    // Utiliser votre serveur TURN
    final username = _generateTurnUsername();
    final password = _generateTurnPassword(username);

    configuration = {
      'iceServers': [
        {'urls': ['stun:stun.l.google.com:19302']},
        {
          'urls': [
            'turn:${TurnConfig.server}:3478',
            'turn:${TurnConfig.server}:3478?transport=tcp',
          ],
          'username': username,
          'credential': password,
        },
      ],
      'sdpSemantics': 'unified-plan',
    };
  } else {
    // Configuration existante (serveurs gratuits)
    configuration = _configuration;
  }

  _peerConnection = await createPeerConnection(configuration);
  // ... reste du code
}

String _generateTurnUsername() {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor() + 86400;
  return '$timestamp:user';
}

String _generateTurnPassword(String username) {
  final key = utf8.encode(TurnConfig.secret);
  final message = utf8.encode(username);
  final hmac = Hmac(sha1, key);
  final digest = hmac.convert(message);
  return base64.encode(digest.bytes);
}
```

Ajoutez la dépendance crypto dans `pubspec.yaml`:

```yaml
dependencies:
  crypto: ^3.0.3
```

#### 6. Tester les Appels

1. **Hot restart les apps** (Shift+R)
2. **Connectez les appareils sur réseaux DIFFÉRENTS:**
   - Rider: WiFi de la maison
   - Driver: 4G/5G mobile
3. **Lancez un appel**
4. **L'audio devrait fonctionner maintenant!** 🎉

Vérifiez dans les logs:

```
[WebRTC] 🧊 ICE candidate de type: relay
[WebRTC] ICE connection state: RTCIceConnectionStateConnected
```

---

## Option 3: Production Sécurisée (Recommandé) 🔒

Pour la production, **ne stockez JAMAIS le secret côté client**.

### Créer une Edge Function Supabase

1. **Installez Supabase CLI:**

   ```bash
   npm install -g supabase
   ```

2. **Créez la fonction:**

   ```bash
   supabase functions new get-turn-credentials
   ```

3. **Éditez `supabase/functions/get-turn-credentials/index.ts`:**

   ```typescript
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
   import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

   const TURN_SECRET = Deno.env.get("TURN_SECRET")!;
   const TURN_SERVER = Deno.env.get("TURN_SERVER")!;

   serve(async (req) => {
     const supabaseClient = createClient(
       Deno.env.get("SUPABASE_URL") ?? "",
       Deno.env.get("SUPABASE_ANON_KEY") ?? ""
     );

     const authHeader = req.headers.get("Authorization")!;
     const {
       data: { user },
     } = await supabaseClient.auth.getUser(authHeader.replace("Bearer ", ""));

     if (!user) {
       return new Response(JSON.stringify({ error: "Unauthorized" }), {
         status: 401,
         headers: { "Content-Type": "application/json" },
       });
     }

     const timestamp = Math.floor(Date.now() / 1000) + 86400;
     const username = `${timestamp}:${user.id}`;

     const encoder = new TextEncoder();
     const key = await crypto.subtle.importKey(
       "raw",
       encoder.encode(TURN_SECRET),
       { name: "HMAC", hash: "SHA-1" },
       false,
       ["sign"]
     );
     const signature = await crypto.subtle.sign(
       "HMAC",
       key,
       encoder.encode(username)
     );
     const credential = btoa(String.fromCharCode(...new Uint8Array(signature)));

     return new Response(
       JSON.stringify({
         username,
         credential,
         ttl: 86400,
         uris: [
           `turn:${TURN_SERVER}:3478`,
           `turn:${TURN_SERVER}:3478?transport=tcp`,
           `turns:${TURN_SERVER}:5349`,
         ],
       }),
       {
         headers: { "Content-Type": "application/json" },
       }
     );
   });
   ```

4. **Déployez:**

   ```bash
   supabase functions deploy get-turn-credentials --no-verify-jwt
   ```

5. **Configurez les secrets:**

   ```bash
   supabase secrets set TURN_SECRET=votre_secret_ici
   supabase secrets set TURN_SERVER=votre_ip_ou_domaine
   ```

6. **Mettez à jour Flutter:**
   ```dart
   Future<void> initialize() async {
     try {
       final response = await _supabase.functions.invoke('get-turn-credentials');

       if (response.status == 200) {
         final turnData = response.data as Map<String, dynamic>;

         _configuration = {
           'iceServers': [
             {'urls': ['stun:stun.l.google.com:19302']},
             {
               'urls': turnData['uris'],
               'username': turnData['username'],
               'credential': turnData['credential'],
             },
           ],
           'sdpSemantics': 'unified-plan',
         };
       }
     } catch (e) {
       print('[WebRTC] Erreur TURN: $e');
       // Fallback sur STUN seulement
     }

     _peerConnection = await createPeerConnection(_configuration);
   }
   ```

---

## Résumé des Options

| Option                | Cas d'usage           | Coût    | Complexité    | Audio?        |
| --------------------- | --------------------- | ------- | ------------- | ------------- |
| **1. Même WiFi**      | Tests locaux          | Gratuit | ⭐ Facile     | ✅ Oui        |
| **2. TURN (tests)**   | Validation production | 5F/mois | ⭐⭐ Moyen    | ✅ Oui        |
| **3. TURN (prod)**    | Production sécurisée  | 5F/mois | ⭐⭐⭐ Avancé | ✅ Oui        |
| **Serveurs gratuits** | Démo uniquement       | Gratuit | ⭐ Facile     | ❌ Non fiable |

---

## Monitoring Production

### Logs du serveur TURN

```bash
# Temps réel
tail -f /var/log/turnserver.log

# Sessions actives
grep "session" /var/log/turnserver.log | tail -20

# Statistiques
systemctl status coturn
```

### Métriques importantes

- **Sessions simultanées:** Max 100 (configurable)
- **Bande passante:** ~64 kbps par appel audio
- **Charge CPU:** ~5% par 10 appels simultanés
- **RAM:** ~10 MB par session

### Alertes recommandées

- Charge CPU > 80%
- RAM disponible < 200 MB
- Sessions > 80
- Erreurs dans les logs

---

## Dépannage Rapide

### Audio ne fonctionne pas (même WiFi)

1. ✅ Même WiFi (pas l'un en 5GHz, l'autre en 2.4GHz)
2. ✅ Permissions microphone accordées
3. ✅ Hot restart (pas juste hot reload)
4. ✅ Logs montrent "RTCIceConnectionStateConnected"

### Audio ne fonctionne pas (réseaux différents)

1. ✅ Serveur TURN installé et démarré
2. ✅ Firewall VPS configuré (ports 3478, 5349, 49152-65535)
3. ✅ Firewall provider configuré (Security Groups, etc.)
4. ✅ Test Trickle ICE réussi (candidates "relay" visibles)
5. ✅ Credentials TURN corrects dans Flutter
6. ✅ Logs montrent des candidates de type "relay"

### Serveur TURN ne répond pas

```bash
# Vérifier le statut
systemctl status coturn

# Vérifier les ports
netstat -tulpn | grep turnserver

# Tester depuis l'extérieur
telnet VOTRE_IP 3478

# Logs
journalctl -u coturn -n 50
```

---

## Support

- 📖 [Documentation complète](./TURN_SERVER_DEPLOYMENT.md)
- 💻 [Helper Flutter](./turn_credentials_helper.dart)
- 🔧 [Script installation](./install-turn-server.sh)

**Prochaines étapes:** Testez d'abord sur le même WiFi (Option 1), puis déployez TURN si besoin!
