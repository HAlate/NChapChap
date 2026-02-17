# 🚀 Intégration NJIA Token → CHAP-CHAP

## Vue d'ensemble

Système de paiement hybride permettant aux utilisateurs de recharger leurs tokens CHAP-CHAP via :
1. **Mobile Money** (validation manuelle admin)
2. **NJIA Token** (crypto, validation automatique blockchain)

---

## 📊 Architecture

```
UTILISATF CFA MOBILE
    │
    ├─ Option 1: Mobile Money
    │  └─ Dashboard Admin → Validation manuelle
    │
    └─ Option 2: NJIA Token
       ├─ Achète NJIA sur https://njiatoken.com
       ├─ Envoie NJIA vers wallet
       ├─ Colle hash transaction
       └─ Tokens CHAP-CHAP crédités automatiquement (2-5 sec)
```

---

## 🔧 Backend (Node.js/Express)

### Fichiers créés

#### `backend/src/crypto.ts`
Service blockchain Polygon avec ethers.js :
- `getNJIABalance(address)` - Solde NJIA
- `verifyTransaction(txHash)` - Vérification blockchain
- `creditTokensFromNJIA(userId, txHash)` - Crédit automatique
- `calculateChapChapTokensFromNJIA(njiaAmount)` - Conversions

#### `backend/src/cryptoRoutes.ts`
API REST pour les apps mobiles :
- `GET /api/crypto/config` - Configuration système
- `GET /api/crypto/balance/:address` - Solde NJIA
- `GET /api/crypto/verify/:txHash` - Vérifier transaction
- `POST /api/crypto/deposit` - Créditer tokens
- `GET /api/crypto/calculate` - Conversions

### Configuration `.env`

```env
# Polygon Blockchain
POLYGON_RPC_URL=https://polygon-rpc.com
NJIA_TOKEN_ADDRESS=0x38511b83942C4b467761E8d690605244A26AC9e0

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Mode (development = testnet, production = mainnet)
NODE_ENV=development
```

### Démarrage

```bash
cd backend
npm install
npm run dev
```

---

## 📱 Mobile (Flutter)

### Fichiers créés

#### `lib/services/crypto_service.dart`
Service Flutter pour interaction avec le backend :
- `getConfig()` - Configuration système
- `getBalance(walletAddress)` - Solde NJIA
- `verifyTransaction(txHash)` - Vérifier transaction
- `depositNJIA(userId, txHash, walletAddress)` - Déposer et créditer
- `calculateTokensFromNJIA(njiaAmount)` - Conversions

#### `lib/widgets/crypto_buy_widget.dart`
Widget UI pour achat crypto :
- Affichage solde NJIA
- Input adresse wallet (sauvegarde locale)
- Input hash de transaction
- Bouton "Acheter NJIA" (ouvre njiatoken.com)
- Validation automatique blockchain

#### `lib/screens/buy_tokens_screen.dart`
Écran avec onglets Mobile Money / NJIA :
- TabBar avec 2 options
- Réutilise `BuyTokensWidget` existant
- Nouveau `CryptoBuyWidget` pour crypto

### Configuration

Aucune configuration supplémentaire requise. Le widget détecte automatiquement :
- L'URL du backend (localhost en dev, API en prod)
- Le wallet sauvegardé via `SharedPreferences`

### Utilisation

```dart
// Naviguer vers l'écran d'achat
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const BuyTokensScreen(),
  ),
);
```

---

## 💰 Économie du système

### Taux de conversion

- **1 NJIA = 65.5957 FCFA** (ancré sur 1 F CFAC = 10 NJIA)
- **1 Token CHAP-CHAP = 20 FCFA**
- **1 NJIA = 3.28 Tokens CHAP-CHAP**

### Exemples

| NJIA envoyé | Tokens CHAP-CHAP reçus | Équivalent FCFA |
|-------------|------------------------|-----------------|
| 1 NJIA      | 3 tokens              | 65.6 F          |
| 10 NJIA     | 32 tokens             | 656 F           |
| 50 NJIA     | 164 tokens            | 3,280 F         |
| 100 NJIA    | 328 tokens            | 6,560 F         |

---

## 🔐 Sécurité

### Backend
- ✅ Vérification blockchain obligatoire (3+ confirmations)
- ✅ Hash de transaction unique (pas de double crédit)
- ✅ Enregistrement dans `token_purchases` avec `transaction_reference`
- ✅ Validation côté serveur (pas de confiance client)

### Mobile
- ✅ Wallet address stocké en local (SharedPreferences)
- ⚠️ **Clé privée NON stockée** (utilisateur gère son wallet externe)
- ✅ Communication HTTPS avec backend
- ✅ User ID vérifié via headers

### Production
- 🔒 Implémenter authentification JWT sur `/api/crypto/deposit`
- 🔒 Rate limiting sur endpoints sensibles
- 🔒 Logs complets des transactions
- 🔒 Monitoring alertes transactions suspectes

---

## 🚀 Workflow utilisateur

### Étape 1 : Acheter NJIA
1. Utilisateur ouvre l'app CHAP-CHAP
2. Va dans "Acheter des tokens"
3. Sélectionne onglet "NJIA Token"
4. Clique "Acheter des NJIA"
5. Redirigé vers https://njiatoken.com
6. Achète NJIA via Mobile Money ou Carte bancaire

### Étape 2 : Créditer tokens
1. Copie son adresse wallet Polygon
2. Envoie NJIA depuis njiatoken.com vers son wallet
3. Copie le hash de transaction (0x...)
4. Retourne dans l'app CHAP-CHAP
5. Colle son adresse wallet
6. Colle le hash de transaction
7. Clique "CRÉDITER MES TOKENS"

### Étape 3 : Validation automatique
1. Backend vérifie transaction sur Polygon
2. Attend 3 confirmations (~5-10 secondes)
3. Crédite automatiquement les tokens
4. Utilisateur reçoit notification de succès

**Temps total : 1-2 minutes** ⚡

---

## 📈 Avantages vs Mobile Money

| Critère | Mobile Money | NJIA Token |
|---------|--------------|------------|
| Validation | Manuelle (admin) | Automatique (blockchain) |
| Délai | 1-24 heures | 2-5 secondes |
| Plafond | 2M FCFA/jour | Illimité |
| Frais | 2.5% | ~0.001 MATIC (0.0001$) |
| Scalabilité | 100 transactions/jour | Millions/jour |
| Traçabilité | Base de données | Blockchain publique |

---

## 🧪 Tests

### Backend

```bash
cd backend

# Test configuration
curl http://localhost:3001/api/crypto/config

# Test solde (adresse testnet)
curl http://localhost:3001/api/crypto/balance/0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb

# Test conversion
curl http://localhost:3001/api/crypto/calculate?njia=10
```

### Mobile

1. Lancer émulateur Android/iOS
2. Compiler l'app :
```bash
cd mobile_driver
flutter run
```
3. Naviguer vers "Acheter tokens" → onglet "NJIA Token"
4. Tester avec adresse testnet Polygon Amoy
5. Utiliser hash de transaction testnet

---

## 🔄 Migration données

Aucune migration nécessaire. Le système crypto :
- Réutilise la table `token_purchases` existante
- Ajoute `transaction_reference` pour le hash blockchain
- Compatible avec le système Mobile Money actuel

---

## 📊 Monitoring recommandé

### Métriques clés
- Nombre de dépôts NJIA/jour
- Volume NJIA → Tokens CHAP-CHAP
- Temps moyen de confirmation blockchain
- Taux d'échec transactions
- Ratio Mobile Money / Crypto

### Alertes
- Transaction > 1000 NJIA (vérification manuelle)
- Même hash utilisé 2 fois (tentative fraude)
- Délai confirmation > 5 minutes (problème RPC)

---

## 🚧 Roadmap

### Phase 1 (Actuelle) ✅
- [x] Backend API crypto
- [x] Widget Flutter NJIA
- [x] Validation automatique blockchain
- [x] Système hybride Mobile Money + Crypto

### Phase 2 (2 semaines)
- [ ] Déploiement mainnet Polygon
- [ ] Interface admin dashboard crypto
- [ ] Historique transactions NJIA
- [ ] Notifications push crédit tokens

### Phase 3 (1 mois)
- [ ] Achat NJIA in-app (intégration njiatoken.com API)
- [ ] Wallet intégré (WalletConnect)
- [ ] Conversion automatique NJIA ↔ FCFA
- [ ] Programme fidélité (bonus crypto)

---

## 🆘 Support

**Backend :**
- Logs : `backend/logs/crypto.log`
- Health check : `GET /api/crypto/health`

**Mobile :**
- Logs Flutter : `flutter logs`
- Effacer wallet : `SharedPreferences.remove('njia_wallet_address')`

**Blockchain :**
- Explorer Polygon : https://polygonscan.com
- Testnet : https://amoy.polygonscan.com
- Contrat NJIA : `0x38511b83942C4b467761E8d690605244A26AC9e0`

---

## 📞 Contact

**Questions techniques :**
- Backend crypto : `backend/src/crypto.ts`
- Mobile crypto : `lib/services/crypto_service.dart`
- Documentation API : http://localhost:3001/api/crypto/config

**Ressources :**
- Site NJIA : https://njiatoken.com
- Polygon docs : https://docs.polygon.technology
- Ethers.js : https://docs.ethers.org/v6
