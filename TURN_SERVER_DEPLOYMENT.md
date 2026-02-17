# Guide de Déploiement d'un Serveur TURN avec Coturn

Ce guide explique comment déployer votre propre serveur TURN pour la production avec coturn sur un VPS.

## Prérequis

- Un VPS avec Ubuntu 20.04/22.04 (DigitalOcean, AWS, OVH, etc.)
- Minimum 1 GB RAM, 1 CPU
- Nom de domaine (optionnel mais recommandé pour SSL)
- Ports ouverts: 3478 (TCP/UDP), 5349 (TLS), 49152-65535 (UDP pour média)

## Étape 1: Préparation du VPS

Connectez-vous à votre VPS via SSH:

```bash
ssh root@VOTRE_IP_VPS
```

Mettez à jour le système:

```bash
apt update && apt upgrade -y
```

## Étape 2: Installation de Coturn

Installez coturn:

```bash
apt install coturn -y
```

Activez le service:

```bash
# Éditez /etc/default/coturn
nano /etc/default/coturn

# Décommentez cette ligne:
TURNSERVER_ENABLED=1
```

## Étape 3: Configuration de Coturn

Sauvegardez la config par défaut:

```bash
cp /etc/turnserver.conf /etc/turnserver.conf.backup
```

Créez une nouvelle configuration:

```bash
nano /etc/turnserver.conf
```

Ajoutez cette configuration (remplacez les valeurs):

```conf
# Listening IP (mettez l'IP publique de votre VPS)
listening-ip=0.0.0.0
relay-ip=VOTRE_IP_PUBLIQUE

# Ports
listening-port=3478
tls-listening-port=5349

# Plage de ports pour le média
min-port=49152
max-port=65535

# Authentification
# Option 1: Long-term credentials (recommandé)
lt-cred-mech
use-auth-secret
static-auth-secret=VOTRE_SECRET_GENERE_ICI

# Realm (domaine de votre service)
realm=turn.votredomaine.com

# Logs
verbose
log-file=/var/log/turnserver.log

# Sécurité
no-multicast-peers
no-cli
no-loopback-peers

# Performance
total-quota=100
stale-nonce=600
max-bps=3000000

# Certificats SSL (optionnel, pour TLS)
# cert=/etc/letsencrypt/live/turn.votredomaine.com/fullchain.pem
# pkey=/etc/letsencrypt/live/turn.votredomaine.com/privkey.pem

# Options supplémentaires
no-stun-backward-compatibility
response-origin-only-with-rfc5780
```

### Génération du secret

Générez un secret fort:

```bash
openssl rand -hex 32
```

Copiez le résultat dans `static-auth-secret` dans la configuration ci-dessus.

## Étape 4: Configuration du Firewall

Ouvrez les ports nécessaires:

```bash
# Si vous utilisez UFW
ufw allow 3478/tcp
ufw allow 3478/udp
ufw allow 5349/tcp
ufw allow 5349/udp
ufw allow 49152:65535/udp
ufw enable

# Ou avec iptables
iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
iptables -A INPUT -p udp --dport 3478 -j ACCEPT
iptables -A INPUT -p tcp --dport 5349 -j ACCEPT
iptables -A INPUT -p udp --dport 5349 -j ACCEPT
iptables -A INPUT -p udp --dport 49152:65535 -j ACCEPT
```

**Important:** Configurez aussi le firewall de votre fournisseur VPS (Security Groups sur AWS, Firewall sur DigitalOcean, etc.)

## Étape 5: Démarrage du Service

```bash
# Démarrer coturn
systemctl start coturn

# Activer au démarrage
systemctl enable coturn

# Vérifier le statut
systemctl status coturn

# Voir les logs
tail -f /var/log/turnserver.log
```

## Étape 6: Test du Serveur TURN

### Test 1: Vérifier l'écoute des ports

```bash
netstat -tulpn | grep turnserver
```

Vous devriez voir:

```
tcp        0      0 0.0.0.0:3478            0.0.0.0:*               LISTEN      1234/turnserver
udp        0      0 0.0.0.0:3478            0.0.0.0:*                           1234/turnserver
```

### Test 2: Test avec Trickle ICE

Allez sur: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

Ajoutez votre serveur TURN:

- **STUN or TURN URI:** `turn:VOTRE_IP:3478`
- **TURN username:** utilisez le générateur ci-dessous
- **TURN password:** utilisez le générateur ci-dessous

### Génération des credentials temporaires

Coturn utilise l'authentification avec secret partagé. Créez un script pour générer les credentials:

```bash
nano /usr/local/bin/generate-turn-credentials.sh
```

Contenu:

```bash
#!/bin/bash

SECRET="VOTRE_SECRET_ICI"  # Le même que dans turnserver.conf
USERNAME="user-$(date +%s)"
TIMESTAMP=$(($(date +%s) + 86400))  # Valide 24h

# Le mot de passe est un HMAC du timestamp avec le secret
PASSWORD=$(echo -n "${TIMESTAMP}:${USERNAME}" | openssl dgst -binary -sha1 -hmac "${SECRET}" | openssl base64)

echo "Username: ${USERNAME}"
echo "Password: ${PASSWORD}"
echo "Valide jusqu'à: $(date -d @${TIMESTAMP})"
```

Rendez-le exécutable:

```bash
chmod +x /usr/local/bin/generate-turn-credentials.sh
```

Testez:

```bash
/usr/local/bin/generate-turn-credentials.sh
```

## Étape 7: Configuration SSL/TLS (Optionnel mais Recommandé)

### Avec Let's Encrypt

Installez certbot:

```bash
apt install certbot -y
```

Générez un certificat (remplacez turn.votredomaine.com):

```bash
certbot certonly --standalone -d turn.votredomaine.com
```

Décommentez les lignes SSL dans `/etc/turnserver.conf`:

```conf
cert=/etc/letsencrypt/live/turn.votredomaine.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.votredomaine.com/privkey.pem
```

Redémarrez coturn:

```bash
systemctl restart coturn
```

### Auto-renouvellement des certificats

Créez un hook pour recharger coturn après renouvellement:

```bash
nano /etc/letsencrypt/renewal-hooks/deploy/coturn-reload.sh
```

Contenu:

```bash
#!/bin/bash
systemctl reload coturn
```

Rendez-le exécutable:

```bash
chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn-reload.sh
```

## Étape 8: Configuration dans les Apps Flutter

### Pour mobile_driver et mobile_rider

Mettez à jour `/lib/services/webrtc_service.dart` dans les deux apps:

```dart
final Map<String, dynamic> _configuration = {
  'iceServers': [
    // Serveurs STUN Google (backup)
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ]
    },
    // VOTRE serveur TURN
    {
      'urls': 'turn:VOTRE_IP_OU_DOMAINE:3478',
      'username': _generateTurnUsername(),
      'credential': _generateTurnPassword(),
    },
    // TURN sur TLS (si SSL configuré)
    {
      'urls': 'turns:VOTRE_DOMAINE:5349',
      'username': _generateTurnUsername(),
      'credential': _generateTurnPassword(),
    },
  ],
  'sdpSemantics': 'unified-plan',
};

// Génération des credentials côté client
String _generateTurnUsername() {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor() + 86400;
  return 'user-$timestamp';
}

String _generateTurnPassword() {
  final secret = 'VOTRE_SECRET_ICI'; // Le même que sur le serveur
  final username = _generateTurnUsername();

  // Calcul HMAC-SHA1
  final key = utf8.encode(secret);
  final message = utf8.encode(username);
  final hmac = Hmac(sha1, key);
  final digest = hmac.convert(message);

  return base64.encode(digest.bytes);
}
```

**IMPORTANT:** Ne mettez JAMAIS le secret en dur dans le code client pour la production!

### Solution Production: Backend génère les credentials

Créez une fonction Supabase Edge Function:

```typescript
// supabase/functions/get-turn-credentials/index.ts
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

  // Générer username avec timestamp (valide 24h)
  const timestamp = Math.floor(Date.now() / 1000) + 86400;
  const username = `${timestamp}:${user.id}`;

  // Calculer HMAC-SHA1
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

### Mise à jour du code Flutter pour utiliser l'Edge Function:

```dart
Future<void> initialize() async {
  // Récupérer les credentials TURN depuis le backend
  final response = await _supabase.functions.invoke('get-turn-credentials');
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

  _peerConnection = await createPeerConnection(_configuration);
  // ... reste du code
}
```

## Étape 9: Monitoring et Maintenance

### Logs

```bash
# Voir les logs en temps réel
tail -f /var/log/turnserver.log

# Statistiques d'utilisation
grep -i "session" /var/log/turnserver.log | tail -20
```

### Statistiques

Activez le CLI dans la config (temporairement pour debug):

```conf
cli-password=VOTRE_MOT_DE_PASSE
```

Puis connectez-vous:

```bash
telnet localhost 5766
# Entrez le mot de passe
# Commandes: help, ps, psf, u
```

### Performance

Surveillez la charge:

```bash
htop
iftop  # Trafic réseau
```

## Étape 10: Sécurité Production

### Limitation du trafic

Dans `/etc/turnserver.conf`:

```conf
# Limiter à 100 sessions simultanées
max-allocate-lifetime=3600
max-allocate-timeout=60

# Limiter la bande passante par utilisateur (3 Mbps)
max-bps=3000000

# Quota total de sessions
total-quota=100

# Bloquer les connexions locales
no-loopback-peers
```

### Rotation des secrets

Changez le secret régulièrement:

```bash
# Générer nouveau secret
NEW_SECRET=$(openssl rand -hex 32)

# Mettre à jour la config
nano /etc/turnserver.conf
# Remplacez static-auth-secret

# Redémarrer
systemctl restart coturn

# Mettre à jour les variables d'environnement Supabase
```

## Dépannage

### Le serveur ne démarre pas

```bash
# Vérifier les erreurs
journalctl -u coturn -n 50

# Tester la config
turnserver -c /etc/turnserver.conf --log-file=stdout
```

### Connexions refusées

1. Vérifiez le firewall VPS
2. Vérifiez le firewall du provider (AWS Security Groups, etc.)
3. Testez avec telnet:
   ```bash
   telnet VOTRE_IP 3478
   ```

### Performance faible

1. Augmentez les ressources VPS (RAM/CPU)
2. Activez le threading:
   ```conf
   # Dans turnserver.conf
   nr-of-threads=4
   ```

## Coûts Estimés

- **VPS:** 5-10F/mois (DigitalOcean, OVH, Hetzner)
- **Nom de domaine:** 10F/an (optionnel)
- **Bande passante:** Généralement illimitée sur VPS

## Alternatives Cloud

Si vous préférez une solution managée:

1. **Twilio TURN:** $0.0005/minute (recommandé)
2. **Xirsys:** À partir de 10$/mois
3. **Metered.ca:** Pay-as-you-go

## Prochaines Étapes

1. ✅ Déployez coturn sur un VPS test
2. ✅ Testez avec Trickle ICE
3. ✅ Configurez l'Edge Function Supabase
4. ✅ Mettez à jour les apps Flutter
5. ✅ Testez les appels en production
6. ✅ Activez le monitoring
7. ✅ Configurez SSL pour la production

## Support

- Documentation coturn: https://github.com/coturn/coturn/wiki
- WebRTC samples: https://webrtc.github.io/samples/
- Supabase Edge Functions: https://supabase.com/docs/guides/functions

---

**Note:** Pour des tests rapides sur le même WiFi, les serveurs STUN existants suffisent. Le serveur TURN n'est nécessaire que pour les connexions à travers des NAT/firewalls restrictifs en production.
