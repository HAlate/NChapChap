#!/bin/bash

# Script d'installation automatique de Coturn pour serveur TURN
# Compatible Ubuntu 20.04/22.04

set -e  # Arrêter en cas d'erreur

echo "================================================"
echo "Installation du serveur TURN avec Coturn"
echo "================================================"
echo ""

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le script est exécuté en root
if [ "$EUID" -ne 0 ]; then 
    error "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

# Obtenir l'IP publique
info "Détection de l'IP publique..."
PUBLIC_IP=$(curl -s ifconfig.me)
info "IP publique détectée: $PUBLIC_IP"
echo ""

# Demander les informations nécessaires
read -p "Domaine pour le serveur TURN (ex: turn.exemple.com) ou appuyez sur Enter pour utiliser l'IP: " TURN_DOMAIN
if [ -z "$TURN_DOMAIN" ]; then
    TURN_DOMAIN=$PUBLIC_IP
    info "Utilisation de l'IP: $TURN_DOMAIN"
else
    info "Utilisation du domaine: $TURN_DOMAIN"
fi
echo ""

read -p "Voulez-vous configurer SSL/TLS avec Let's Encrypt? (y/n): " SETUP_SSL
echo ""

# Génération du secret
info "Génération du secret d'authentification..."
TURN_SECRET=$(openssl rand -hex 32)
info "Secret généré: $TURN_SECRET"
echo ""
warning "⚠️  IMPORTANT: Sauvegardez ce secret! Vous en aurez besoin pour configurer vos apps."
echo ""
read -p "Appuyez sur Enter pour continuer..."
echo ""

# Mise à jour du système
info "Mise à jour du système..."
apt update && apt upgrade -y

# Installation de Coturn
info "Installation de Coturn..."
apt install coturn -y

# Activation du service
info "Activation du service Coturn..."
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Backup de la config par défaut
info "Sauvegarde de la configuration par défaut..."
cp /etc/turnserver.conf /etc/turnserver.conf.backup

# Création de la nouvelle configuration
info "Création de la configuration Coturn..."
cat > /etc/turnserver.conf <<EOF
# Configuration Coturn générée automatiquement
# Date: $(date)

# Listening IP
listening-ip=0.0.0.0
relay-ip=$PUBLIC_IP

# Ports
listening-port=3478
tls-listening-port=5349

# Plage de ports pour le média
min-port=49152
max-port=65535

# Authentification
lt-cred-mech
use-auth-secret
static-auth-secret=$TURN_SECRET

# Realm
realm=$TURN_DOMAIN

# Logs
verbose
log-file=/var/log/turnserver.log

# Sécurité
no-multicast-peers
no-cli
no-loopback-peers
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255

# Performance
total-quota=100
stale-nonce=600
max-bps=3000000
bps-capacity=0

# Options
no-stun-backward-compatibility
response-origin-only-with-rfc5780
EOF

# Configuration SSL si demandé
if [[ "$SETUP_SSL" =~ ^[Yy]$ ]] && [ "$TURN_DOMAIN" != "$PUBLIC_IP" ]; then
    info "Installation de Certbot pour Let's Encrypt..."
    apt install certbot -y
    
    info "Arrêt temporaire de Coturn pour libérer le port 80..."
    systemctl stop coturn
    
    info "Génération du certificat SSL..."
    certbot certonly --standalone -d $TURN_DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
    
    if [ $? -eq 0 ]; then
        info "Certificat SSL généré avec succès!"
        
        # Ajout des chemins SSL dans la config
        echo "" >> /etc/turnserver.conf
        echo "# Certificats SSL" >> /etc/turnserver.conf
        echo "cert=/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem" >> /etc/turnserver.conf
        echo "pkey=/etc/letsencrypt/live/$TURN_DOMAIN/privkey.pem" >> /etc/turnserver.conf
        
        # Créer le hook de renouvellement
        mkdir -p /etc/letsencrypt/renewal-hooks/deploy
        cat > /etc/letsencrypt/renewal-hooks/deploy/coturn-reload.sh <<'EOL'
#!/bin/bash
systemctl reload coturn
EOL
        chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn-reload.sh
        
        info "Hook de renouvellement SSL configuré"
    else
        warning "Échec de la génération du certificat SSL. Le serveur fonctionnera sans TLS."
    fi
fi

# Configuration du firewall
info "Configuration du firewall UFW..."
if command -v ufw &> /dev/null; then
    ufw allow 3478/tcp
    ufw allow 3478/udp
    ufw allow 5349/tcp
    ufw allow 5349/udp
    ufw allow 49152:65535/udp
    ufw allow 22/tcp  # Garder SSH ouvert!
    echo "y" | ufw enable
    info "Firewall UFW configuré"
else
    warning "UFW non installé. Configurez manuellement votre firewall!"
    warning "Ports requis: 3478 (TCP/UDP), 5349 (TCP/UDP), 49152-65535 (UDP)"
fi

# Création du script de génération de credentials
info "Création du script de génération de credentials..."
cat > /usr/local/bin/generate-turn-credentials <<EOF
#!/bin/bash

SECRET="$TURN_SECRET"
TIMESTAMP=\$((\\$(date +%s) + 86400))  # Valide 24h
USERNAME="\${TIMESTAMP}:user"

PASSWORD=\\$(echo -n "\${USERNAME}" | openssl dgst -binary -sha1 -hmac "\${SECRET}" | openssl base64)

echo "======================================"
echo "Credentials TURN (valides 24h)"
echo "======================================"
echo "Server: $TURN_DOMAIN"
echo "Username: \${USERNAME}"
echo "Password: \${PASSWORD}"
echo "======================================"
echo ""
echo "Configuration Flutter:"
echo "-------------------------------------"
echo "'urls': 'turn:$TURN_DOMAIN:3478',"
echo "'username': '\${USERNAME}',"
echo "'credential': '\${PASSWORD}',"
echo "-------------------------------------"
EOF

chmod +x /usr/local/bin/generate-turn-credentials

# Démarrage du service
info "Démarrage du service Coturn..."
systemctl enable coturn
systemctl start coturn

# Vérification du statut
sleep 2
if systemctl is-active --quiet coturn; then
    info "✅ Service Coturn démarré avec succès!"
else
    error "❌ Échec du démarrage de Coturn"
    error "Vérifiez les logs avec: journalctl -u coturn -n 50"
    exit 1
fi

# Affichage du résumé
echo ""
echo "================================================"
echo -e "${GREEN}✅ Installation terminée avec succès!${NC}"
echo "================================================"
echo ""
echo "📋 Informations du serveur:"
echo "   - Serveur: $TURN_DOMAIN"
echo "   - IP: $PUBLIC_IP"
echo "   - Port TURN: 3478"
echo "   - Port TURNS (TLS): 5349"
echo "   - Secret: $TURN_SECRET"
echo ""
echo "🔧 Commandes utiles:"
echo "   - Status: systemctl status coturn"
echo "   - Logs: tail -f /var/log/turnserver.log"
echo "   - Redémarrer: systemctl restart coturn"
echo "   - Credentials: generate-turn-credentials"
echo ""
echo "🧪 Test du serveur:"
echo "   1. Allez sur https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
echo "   2. Générez des credentials: generate-turn-credentials"
echo "   3. Testez avec les credentials affichés"
echo ""
echo "📱 Configuration Flutter:"
echo "   1. Utilisez le fichier turn_credentials_helper.dart"
echo "   2. Mettez à jour turnSecret avec: $TURN_SECRET"
echo "   3. Mettez à jour turnServer avec: $TURN_DOMAIN"
echo ""
warning "⚠️  N'oubliez pas de configurer le firewall de votre provider VPS!"
warning "⚠️  Ports requis: 3478, 5349, 49152-65535"
echo ""
echo "================================================"

# Sauvegarder les infos dans un fichier
cat > /root/turn-server-info.txt <<EOF
===========================================
Configuration du serveur TURN
Date d'installation: $(date)
===========================================

Serveur: $TURN_DOMAIN
IP publique: $PUBLIC_IP
Secret: $TURN_SECRET

URLs:
- turn:$TURN_DOMAIN:3478
- turn:$TURN_DOMAIN:3478?transport=tcp
- turns:$TURN_DOMAIN:5349 (si SSL configuré)

Commandes:
- générer credentials: generate-turn-credentials
- voir logs: tail -f /var/log/turnserver.log
- status: systemctl status coturn

Configuration sauvegardée dans: /etc/turnserver.conf
Backup original: /etc/turnserver.conf.backup
===========================================
EOF

info "📄 Informations sauvegardées dans /root/turn-server-info.txt"
