# Configuration Audio WebRTC - UUMO

Documentation complète pour configurer les appels audio WebRTC entre rider et driver.

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Test rapide (même WiFi)](#test-rapide-même-wifi)
3. [Déploiement production](#déploiement-production)
4. [Fichiers de configuration](#fichiers-de-configuration)
5. [FAQ](#faq)

---

## Vue d'ensemble

Le système d'appels audio UUMO utilise WebRTC avec:

- **STUN servers** pour découvrir les adresses publiques
- **TURN servers** pour relayer l'audio à travers les NAT/firewalls

### État Actuel

✅ **Fonctionnel:**

- Signalisation WebRTC complète (offer/answer/ICE)
- Notifications d'appel en temps réel
- Interface utilisateur d'appel
- Gestion du cycle de vie des appels
- Détection de fin d'appel distante

❌ **À configurer:**

- Audio sur réseaux différents (nécessite TURN)

---

## Test rapide (même WiFi)

**Temps:** 2 minutes ⚡

### Étapes

1. **Connectez les 2 appareils au même WiFi**

2. **Hot restart les apps:**

   ```bash
   # Terminal rider et driver
   Shift + R
   ```

3. **Testez un appel:**
   - Rider → Driver
   - Driver accepte
   - **L'audio devrait fonctionner!** 🎉

### Vérification

Logs à surveiller:

```
[WebRTC] ICE connection state: RTCIceConnectionStateConnected
[CallScreen] Connection state: RTCPeerConnectionStateConnected
```

Si ça marche → Passez au déploiement TURN pour la production
Si ça ne marche pas → Vérifiez les permissions micro + même WiFi

---

## Déploiement Production

Pour les appels à travers Internet, déployez un serveur TURN.

### Option A: Installation Automatique (Recommandé)

**Prérequis:**

- VPS Ubuntu 22.04 (DigitalOcean, OVH, Hetzner)
- Minimum: 1 GB RAM, 1 CPU
- Coût: ~5F/mois

**Installation (15 minutes):**

```bash
# 1. SSH dans le VPS
ssh root@VOTRE_IP_VPS

# 2. Télécharger le script
wget https://raw.githubusercontent.com/votrecompte/UUMO/main/install-turn-server.sh

# 3. Rendre exécutable
chmod +x install-turn-server.sh

# 4. Exécuter
./install-turn-server.sh
```

Le script:

1. Installe et configure Coturn
2. Génère un secret d'authentification
3. Configure le firewall
4. Démarre le service
5. Fournit les credentials de test

**⚠️ Important:** Configurez aussi le firewall de votre provider VPS (Security Groups, etc.)

### Option B: Installation Manuelle

Suivez le guide complet: [TURN_SERVER_DEPLOYMENT.md](./TURN_SERVER_DEPLOYMENT.md)

### Configuration Flutter

#### Tests (Quick & Dirty)

Créez `lib/config/turn_config.dart`:

```dart
class TurnConfig {
  static const String server = 'VOTRE_IP_OU_DOMAINE';
  static const String secret = 'VOTRE_SECRET_DEPUIS_INSTALLATION';
  static bool useCustomTurn = true;
}
```

Voir [turn_credentials_helper.dart](./turn_credentials_helper.dart) pour l'implémentation complète.

#### Production (Sécurisé)

Créez une Edge Function Supabase pour générer les credentials.

Voir guide complet: [TURN_SERVER_DEPLOYMENT.md](./TURN_SERVER_DEPLOYMENT.md#étape-8-configuration-dans-les-apps-flutter)

---

## Fichiers de Configuration

| Fichier                                                        | Description                | Utilisation         |
| -------------------------------------------------------------- | -------------------------- | ------------------- |
| [WEBRTC_AUDIO_QUICK_START.md](./WEBRTC_AUDIO_QUICK_START.md)   | Guide de démarrage rapide  | Tests et validation |
| [TURN_SERVER_DEPLOYMENT.md](./TURN_SERVER_DEPLOYMENT.md)       | Guide complet déploiement  | Production          |
| [install-turn-server.sh](./install-turn-server.sh)             | Script d'installation auto | VPS Ubuntu          |
| [turn_credentials_helper.dart](./turn_credentials_helper.dart) | Helper Flutter             | Tests + Production  |

---

## Architecture

```
┌─────────────┐                  ┌──────────────┐
│   Rider     │                  │    Driver    │
│   (WiFi)    │                  │    (4G)      │
└──────┬──────┘                  └──────┬───────┘
       │                                │
       │  1. Signaling via Supabase    │
       ├────────────────────────────────┤
       │  (offer/answer/ICE)            │
       │                                │
       │  2. Tentative connexion directe (P2P)
       │────X────────────────────────X──┤
       │    NAT/Firewall bloquent       │
       │                                │
       │  3. Relay via serveur TURN    │
       │                ┌───────┐       │
       └────────────────┤ TURN  ├───────┘
                        │Server │
                        └───────┘
                        (VPS)
```

### Flux d'appel

1. **Rider initie:** CallService.initiateCall()
2. **Notification:** Driver reçoit via Realtime
3. **Driver accepte:** Status → 'active'
4. **Rider détecte:** Via channel Realtime → Crée offer WebRTC
5. **Signaling:** Exchange offer/answer/ICE via Supabase
6. **Connexion:** WebRTC établit le canal audio
7. **Audio:** Flux direct (P2P) ou via TURN
8. **Fin:** Mise à jour du status → Déconnexion automatique

---

## Configuration des Serveurs

### Configuration Actuelle (Gratuite)

```dart
'iceServers': [
  {
    'urls': [
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
    ]
  },
  {
    'urls': 'turn:openrelay.metered.ca:80',
    'username': 'openrelayproject',
    'credential': 'openrelayproject',
  },
]
```

**Limites:**

- Serveurs publics surchargés
- Pas de garantie de disponibilité
- Performance variable

### Configuration Production (Votre TURN)

```dart
'iceServers': [
  {
    'urls': ['stun:stun.l.google.com:19302']
  },
  {
    'urls': [
      'turn:votre-serveur.com:3478',
      'turn:votre-serveur.com:3478?transport=tcp',
      'turns:votre-serveur.com:5349',  // TLS
    ],
    'username': 'généré_dynamiquement',
    'credential': 'généré_dynamiquement',
  },
]
```

**Avantages:**

- Contrôle total
- Performance garantie
- Sécurité renforcée
- Coût prévisible

---

## FAQ

### Q: L'audio fonctionne sur le même WiFi mais pas sur réseaux différents?

**R:** C'est normal. Vous avez besoin d'un serveur TURN pour traverser les NAT/firewalls. Déployez coturn avec le script fourni.

### Q: Quel VPS choisir?

**R:** Recommandations:

- **DigitalOcean** - Interface simple, fiable (6$/mois)
- **OVH** - Le moins cher (3.50F/mois)
- **Hetzner** - Bon rapport qualité/prix (4.15F/mois)

### Q: Combien d'appels simultanés mon serveur TURN peut gérer?

**R:** Avec 1 GB RAM:

- ~50 appels audio (64 kbps/appel)
- ~10 appels vidéo (2 Mbps/appel)

Pour plus de capacité, augmentez les ressources VPS.

### Q: Puis-je utiliser un serveur TURN commercial?

**R:** Oui! Alternatives:

- **Twilio TURN** - $0.0005/minute (~$0.03/heure)
- **Xirsys** - À partir de 10$/mois
- **Metered.ca** - Pay-as-you-go

### Q: Le secret TURN doit-il être gardé secret?

**R:** **OUI!** Ne le mettez jamais dans le code client en production. Utilisez une Edge Function Supabase pour générer les credentials côté serveur.

### Q: Comment monitorer mon serveur TURN?

**R:**

```bash
# Logs temps réel
tail -f /var/log/turnserver.log

# Statistiques
systemctl status coturn

# Sessions actives
grep "session" /var/log/turnserver.log | tail -20
```

### Q: Le serveur TURN consomme beaucoup de bande passante?

**R:** Pour l'audio:

- ~64 kbps par appel
- ~230 MB/heure par appel
- ~5.5 GB pour 100h d'appels

Les VPS offrent généralement 1-2 TB/mois, largement suffisant.

### Q: Dois-je avoir un nom de domaine?

**R:** Non, vous pouvez utiliser l'IP publique du VPS. Mais un domaine permet:

- Certificats SSL pour TLS (plus sécurisé)
- Plus facile à retenir
- Migration de serveur simplifiée

### Q: Comment tester que mon TURN fonctionne?

**R:**

1. Générez des credentials: `generate-turn-credentials`
2. Allez sur https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
3. Collez vos credentials
4. Cliquez "Gather candidates"
5. Vous devriez voir des candidates de type "relay"

### Q: L'installation est complexe?

**R:** Avec le script automatique: **15 minutes top chrono!**

1. Créer VPS (5 min)
2. Exécuter le script (5 min)
3. Configurer firewall provider (3 min)
4. Tester (2 min)

---

## Prochaines Étapes

### Phase 1: Validation (Maintenant)

1. ✅ Testez sur le même WiFi
2. ✅ Vérifiez que l'audio fonctionne
3. ✅ Testez la fin d'appel dans les 2 sens

### Phase 2: Production (Cette semaine)

1. 🔲 Déployez serveur TURN avec `install-turn-server.sh`
2. 🔲 Configurez le firewall VPS
3. 🔲 Testez avec Trickle ICE
4. 🔲 Mettez à jour Flutter (turn_config.dart)
5. 🔲 Testez sur réseaux différents

### Phase 3: Sécurisation (Avant lancement)

1. 🔲 Créez Edge Function Supabase pour credentials
2. 🔲 Retirez le secret du code client
3. 🔲 Activez SSL/TLS sur TURN
4. 🔲 Configurez monitoring
5. 🔲 Tests de charge

### Phase 4: Optimisation (Post-lancement)

1. 🔲 Ajoutez métriques WebRTC (qualité audio)
2. 🔲 Implémentez reconnexion automatique
3. 🔲 Ajoutez la vidéo (optionnel)
4. 🔲 Optimisez la bande passante

---

## Support & Ressources

- 📖 [WebRTC Documentation](https://webrtc.org/)
- 🔧 [Coturn GitHub](https://github.com/coturn/coturn)
- 💬 [Supabase Realtime Docs](https://supabase.com/docs/guides/realtime)
- 🎥 [WebRTC Samples](https://webrtc.github.io/samples/)

---

## Contribution

Pour améliorer cette documentation:

1. Testez les procédures
2. Signalez les problèmes
3. Proposez des améliorations
4. Partagez vos retours d'expérience

---

**Auteur:** Configuration WebRTC UUMO  
**Dernière mise à jour:** Janvier 2026  
**Version:** 1.0
