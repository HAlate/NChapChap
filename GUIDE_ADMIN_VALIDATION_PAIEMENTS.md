# Guide d'utilisation - Dashboard Admin (Phase 1)

## 📱 Accès au dashboard

### Depuis l'app mobile driver
1. Ouvrir **mobile_driver**
2. Écran d'accueil → Bouton **"Admin - Paiements"** (orange)
3. Dashboard des paiements en attente s'ouvre

> ⚠️ **Note** : En production, ajouter authentification admin (vérifier `user.role == 'admin'`)

---

## 🔄 Interface du dashboard

### Vue d'ensemble
```
┌─────────────────────────────────────────┐
│  Paiements en attente          [🔄]     │
├─────────────────────────────────────────┤
│  📊 Statistiques                        │
│  En attente: 3    Montant total: 38,250F│
├─────────────────────────────────────────┤
│  📋 Liste des paiements                 │
│                                         │
│  ┌───────────────────────────────┐     │
│  │ KJ  Koffi Jérôme              │ il y a 2 min
│  │     +228 90 12 34 56          │     │
│  │ ─────────────────────────────  │     │
│  │ 🪙 12 jetons  💰 12,750 F     │     │
│  │ 📱 MTN Mobile Money     [SMS]  │     │
│  │                                │     │
│  │ [❌ Refuser]  [✅ Valider]    │     │
│  └───────────────────────────────┘     │
│                                         │
│  (autres paiements...)                  │
└─────────────────────────────────────────┘
```

### Éléments affichés
- **Avatar** : Initiale du nom du chauffeur
- **Nom** : Nom complet du chauffeur
- **Téléphone** : Numéro du chauffeur
- **Timestamp** : Temps écoulé depuis la demande
- **Jetons** : Nombre total avec bonus
- **Montant** : Montant total avec frais
- **Opérateur** : Icône + nom (MTN, Moov, etc.)
- **Notifications** : Badges SMS/WhatsApp si cochés

---

## ✅ Valider un paiement

### Workflow
1. **Vérifier SMS Mobile Money** sur votre téléphone pro
   - Exemple MTN : "Vous avez reçu 12,750 FCFA de +228 90 12 34 56"
   - Vérifier : montant exact + numéro expéditeur

2. **Matcher avec la liste**
   - Chercher le montant : 12,750 F
   - Vérifier le timestamp (doit être récent)
   - Confirmer le numéro du chauffeur

3. **Cliquer "Valider"**
   - Dialog de confirmation apparaît
   - Vérifier les détails une dernière fois
   - Cliquer **"Valider le paiement"**

4. **Résultat**
   - ✅ SnackBar vert : "12 jetons crédités à Koffi Jérôme"
   - Paiement disparaît de la liste
   - Jetons crédités instantanément au chauffeur
   - Feedback haptique (vibration légère)

### Exemple de confirmation
```
┌──────────────────────────────┐
│ Confirmer la validation      │
├──────────────────────────────┤
│ Chauffeur: Koffi Jérôme      │
│ Montant: 12,750 FCFA         │
│ Jetons: 12                   │
│                              │
│ Avez-vous vérifié le         │
│ paiement Mobile Money ?      │
├──────────────────────────────┤
│ [Annuler] [Valider le paiement]
└──────────────────────────────┘
```

---

## ❌ Refuser un paiement

### Cas d'usage
- Paiement non reçu après 30 min
- Montant incorrect reçu
- Numéro expéditeur ne correspond pas
- Suspicion de fraude

### Workflow
1. **Cliquer "Refuser"**
2. **Saisir la raison** (obligatoire)
   - Ex : "Paiement non reçu après vérification"
   - Ex : "Montant incorrect : reçu 12,000 au lieu de 12,750"
   - Ex : "Numéro expéditeur différent"

3. **Confirmer le refus**
   - Bouton rouge "Refuser"
   - ⚠️ Action irréversible

4. **Résultat**
   - ❌ SnackBar orange : "Paiement de Koffi Jérôme refusé"
   - Statut → `cancelled` dans la DB
   - Chauffeur peut réessayer

### Dialog de refus
```
┌──────────────────────────────┐
│ Refuser le paiement          │
├──────────────────────────────┤
│ Chauffeur: Koffi Jérôme      │
│ Montant: 12,750 FCFA         │
│                              │
│ Raison du rejet:             │
│ ┌──────────────────────────┐ │
│ │ Paiement non reçu après  │ │
│ │ vérification...          │ │
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ [Annuler]  [❌ Refuser]      │
└──────────────────────────────┘
```

---

## 🔄 Actualisation

### Automatique
- Dashboard utilise **Supabase Realtime**
- Nouveaux paiements apparaissent automatiquement
- Pas besoin de rafraîchir manuellement

### Manuelle
- Bouton 🔄 en haut à droite
- Force le rechargement si nécessaire

---

## 📋 Checklist quotidienne admin

### Matin (9h)
- [ ] Ouvrir dashboard admin
- [ ] Vérifier paiements de la nuit (si présents)
- [ ] Valider les paiements reçus

### Midi (13h)
- [ ] Vérifier nouveaux paiements
- [ ] Traiter paiements en attente > 1h

### Soir (18h)
- [ ] Vérifier paiements de la journée
- [ ] S'assurer qu'aucun paiement > 2h en attente
- [ ] Contacter chauffeurs si problème

### Hebdomadaire (vendredi)
- [ ] Exporter statistiques (TODO: fonctionnalité future)
- [ ] Vérifier soldes Mobile Money vs DB
- [ ] Rapprocher comptabilité

---

## ⏱️ Délais recommandés

| Situation | Délai action | Action |
|-----------|--------------|--------|
| Paiement reçu | < 5 min | Valider immédiatement |
| Paiement non reçu | 30 min | Contacter chauffeur |
| Paiement douteux | Immédiat | Refuser + investigation |
| Volume > 10/jour | Phase 2 | Activer auto-validation |

---

## 🔐 Sécurité

### Phase 1 (actuel)
- ⚠️ Bouton admin accessible à tous (temporaire)
- ⚠️ Pas de vérification de rôle
- ⚠️ À sécuriser avant production

### Production (TODO)
```dart
// Vérifier rôle avant affichage du bouton
final user = await _supabase.auth.currentUser;
final isAdmin = user?.userMetadata?['role'] == 'admin';

if (isAdmin) {
  // Afficher bouton admin
}
```

### Base de données
- ✅ Fonctions SQL (`validate_token_purchase`) sécurisées
- ✅ RLS policies à configurer pour vue `pending_token_purchases`
- ✅ Logs d'audit dans `admin_notes`

---

## 🐛 Résolution de problèmes

### "Aucun paiement en attente" mais SMS reçu
1. Vérifier que le chauffeur a bien cliqué "ENVOYER"
2. Vérifier logs Supabase : `token_purchases` avec status='pending'
3. Vérifier migration SQL : view `pending_token_purchases` existe ?

### Erreur lors de la validation
1. Vérifier connexion Internet
2. Vérifier que fonction `validate_token_purchase()` existe en DB
3. Vérifier logs : `SupabaseClient` dans console Flutter

### Paiement validé mais jetons non crédités
1. Vérifier fonction `add_tokens()` existe
2. Vérifier table `token_balances` mise à jour
3. Vérifier `token_transactions` pour trace de crédit

### Stream ne se met pas à jour
1. Cliquer bouton 🔄 pour forcer refresh
2. Vérifier Supabase Realtime activé dans projet
3. Redémarrer l'app si nécessaire

---

## 📊 Statistiques (futures)

### Métriques à suivre
- Temps moyen de validation
- Taux de rejet
- Volume par opérateur (MTN vs Moov vs autres)
- Heures de pointe (pour staffing admin)

### Export CSV (TODO Phase 1.5)
```sql
-- Query manuelle pour export
SELECT 
  driver_name,
  total_amount,
  mobile_money_provider,
  status,
  created_at,
  validated_at,
  EXTRACT(EPOCH FROM (validated_at - created_at))/60 as minutes_to_validate
FROM token_purchases
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## 🚀 Passage à Phase 2

### Quand activer ?
- ✅ > 50 paiements/semaine
- ✅ 95%+ de paiements routiniers (même montants)
- ✅ Budget disponible (~10F/mois)

### Prérequis
1. Compte Africa's Talking créé
2. Numéro virtuel configuré
3. Edge Function déployée
4. Tests en parallèle réussis

### Avantages Phase 2
- ⚡ Validation < 30 secondes (vs 5-30 min actuellement)
- 🤖 Aucune action admin requise pour paiements standards
- 📱 Notifications push instantanées au chauffeur
- 📊 Logs automatiques pour audit

---

## 📞 Contact & Support

En cas de problème technique :
1. Vérifier logs dans Supabase Dashboard
2. Vérifier console Flutter (pour erreurs app)
3. Consulter documentation : `PHASE2_AUTOMATISATION_SMS.md`
4. Créer ticket GitHub si bug persistant
