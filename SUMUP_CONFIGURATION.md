# Configuration SumUp - Comptes Individuels par Chauffeur

## Vue d'ensemble

SumUp est un système de paiement par carte **optionnel** pour l'application mobile driver. **Chaque chauffeur peut configurer son propre compte SumUp** et recevoir les paiements directement sur son compte personnel.

Les chauffeurs peuvent utiliser l'application complètement fonctionnelle même sans SumUp configuré - ils pourront toujours terminer leurs courses avec le paiement par jetons.

## Avantages de SumUp

- **Compte personnel** : Chaque chauffeur utilise son propre compte SumUp
- **Paiements directs** : Les fonds vont directement sur le compte du chauffeur
- Accepter les paiements par carte bancaire à la fin d'une course
- Élargir les options de paiement pour les passagers
- Transactions sécurisées via le SDK SumUp
- **Autonomie** : Pas besoin de l'administrateur pour configurer SumUp

## Configuration pour les Chauffeurs

### Étape 1 : Créer un compte SumUp

1. Visitez [developer.sumup.com](https://developer.sumup.com/)
2. Créez un compte développeur (gratuit)
3. Créez une nouvelle application
4. Copiez votre **Affiliate Key** (Clé d'affiliation)

### Étape 2 : Configurer dans l'App Mobile Driver

1. Ouvrez l'application UUMO Driver
2. Allez dans **Paramètres** → **Configuration SumUp**
3. Collez votre clé d'affiliation dans le champ
4. Cliquez sur **"Tester la connexion"** pour vérifier
5. Cliquez sur **"Enregistrer la clé"**
6. ✅ Les paiements par carte sont maintenant activés!

### Étape 3 : Utiliser SumUp

Une fois configuré, lors de la fin d'une course:

- Le bouton **"Payer par carte"** apparaît
- Le passager peut payer avec sa carte
- Le paiement va directement sur votre compte SumUp
- Aucun jeton n'est déduit

## Fonctionnement

### Chauffeur SANS SumUp configuré

- ✅ L'application fonctionne normalement
- ✅ Peut accepter et effectuer des courses
- ✅ Termine les courses avec paiement par jetons (1 jeton déduit)
- ℹ️ Message affiché : "Configurez SumUp pour accepter les paiements par carte"
- ❌ Bouton "Payer par carte" non visible

### Chauffeur AVEC SumUp configuré

- ✅ Peut proposer deux options de paiement au passager:
  1. **Payer par carte** : Utilise le compte SumUp du chauffeur
  2. **Payer avec jetons** : Déduit 1 jeton du chauffeur
- ✅ Les deux méthodes fonctionnent parfaitement
- ✅ Le chauffeur choisit la méthode avec le passager

## Architecture Technique

### Base de données

**Table `driver_profiles`** - Nouvelle colonne ajoutée:

```sql
sumup_affiliate_key TEXT  -- Clé SumUp individuelle du chauffeur
```

### Écran de Configuration

**Fichier**: `mobile_driver/lib/features/settings/presentation/screens/sumup_settings_screen.dart`

Fonctionnalités:

- ✅ Saisie/modification de la clé d'affiliation
- ✅ Test de connexion SumUp
- ✅ Enregistrement dans la base de données
- ✅ Réinitialisation automatique du SDK SumUp
- ✅ Suppression de la clé
- ✅ Instructions pour obtenir une clé

### Services

1. **DriverSumUpConfigService** (`driver_sumup_config_service.dart`)

   - Récupère la clé du chauffeur depuis `driver_profiles`
   - Sauvegarde/supprime la clé
   - Vérifie si le chauffeur a une clé configurée

2. **PostLoginInitService** (`post_login_init_service.dart`)

   - Initialise SumUp après le login du chauffeur
   - Utilise automatiquement la clé du chauffeur
   - Gère la réinitialisation et le nettoyage

3. **SumUpService** (`sumup_service.dart`)
   - Modifié pour supporter les clés individuelles
   - Permet la réinitialisation avec une nouvelle clé
   - Méthode `reset()` pour nettoyer l'état

### Initialisation

**Au démarrage de l'app** (`main.dart`):

```dart
// SumUp n'est PAS initialisé au démarrage
// Attendre que le chauffeur se connecte
```

**Après login du chauffeur**:

```dart
final postLoginService = PostLoginInitService();
await postLoginService.initializeDriverServices();
// → Récupère la clé du chauffeur
// → Initialise SumUp si la clé existe
```

**Après mise à jour de la clé**:

```dart
await postLoginService.reinitializeSumUp();
// → Reset SumUp
// → Réinitialise avec la nouvelle clé
```

## Workflow de paiement par carte

1. Le chauffeur termine la course
2. Le passager choisit "Payer par carte"
3. SumUp SDK s'ouvre pour traiter le paiement
4. Le paiement est confirmé
5. Une transaction est créée dans `sumup_transactions`
6. La course est marquée comme complétée avec `payment_method = 'sumup'`

## Workflow de paiement par jetons

1. Le chauffeur termine la course
2. Le chauffeur choisit "Payer avec jetons"
3. La course est marquée comme complétée avec `payment_method = 'tokens'`
4. Un jeton est automatiquement déduit via le trigger `handle_trip_token_deduction`
5. Le chauffeur voit un message de confirmation

## Base de données

### Table: sumup_transactions

Stocke toutes les transactions SumUp :

```sql
- id: UUID (PK)
- trip_id: UUID (FK vers trips)
- driver_id: UUID (FK vers auth.users)
- transaction_code: TEXT (unique)
- sumup_transaction_id: TEXT
- amount_cents: INTEGER
- currency: TEXT
- status: TEXT (pending, completed, failed)
- card_type: TEXT
- card_last4: TEXT
- created_at: TIMESTAMPTZ
- completed_at: TIMESTAMPTZ
```

### Fonctions RPC

- `calculate_trip_amount(p_trip_id, p_tip_percentage)` : Calcule le montant total de la course
- `create_sumup_transaction(...)` : Crée une nouvelle transaction SumUp
- `confirm_sumup_transaction(...)` : Confirme une transaction réussie
- `fail_sumup_transaction(...)` : Marque une transaction comme échouée

## Tests

### Tester sans SumUp (Chauffeur sans clé configurée)

1. Se connecter en tant que chauffeur
2. Ne PAS aller dans Configuration SumUp (ou laisser vide)
3. Accepter et compléter une course
4. ✅ Vérifier que seul le bouton "Payer avec jetons" est visible
5. ✅ Vérifier le message : "Configurez SumUp pour accepter les paiements par carte"
6. ✅ Vérifier que la course se termine correctement avec déduction de 1 jeton

### Tester avec SumUp (Chauffeur avec clé configurée)

1. Se connecter en tant que chauffeur
2. Aller dans **Paramètres → Configuration SumUp**
3. Saisir une clé d'affiliation valide
4. Cliquer sur "Tester la connexion" → Devrait afficher "✅ Connexion SumUp réussie"
5. Cliquer sur "Enregistrer la clé"
6. Accepter et compléter une course
7. ✅ Vérifier que les deux boutons sont visibles :
   - "Payer par carte"
   - "Payer avec jetons"
8. ✅ Tester les deux méthodes de paiement

### Tester le changement de clé

1. Chauffeur avec clé configurée
2. Aller dans Configuration SumUp
3. Modifier la clé d'affiliation
4. Enregistrer
5. ✅ Vérifier que SumUp se réinitialise avec la nouvelle clé
6. ✅ Tester un paiement par carte avec la nouvelle configuration

### Tester la suppression de la clé

1. Chauffeur avec clé configurée
2. Aller dans Configuration SumUp
3. Cliquer sur "Supprimer la clé"
4. Confirmer la suppression
5. ✅ Vérifier que le bouton "Payer par carte" disparaît lors de la prochaine course
6. ✅ Vérifier que le paiement par jetons fonctionne toujours

## Dépannage

### Le chauffeur ne voit pas le bouton "Payer par carte"

**Solutions:**

1. Vérifier que le chauffeur a configuré sa clé SumUp dans les paramètres
2. Vérifier que la clé est valide (utiliser "Tester la connexion")
3. Redémarrer l'application après configuration de la clé
4. Consulter les logs : `PostLoginInitService` devrait afficher "✅ SumUp initialized"

### La connexion SumUp échoue lors du test

**Solutions:**

1. Vérifier que la clé d'affiliation est correcte (copiée depuis developer.sumup.com)
2. Vérifier la connexion Internet
3. Vérifier que le compte SumUp Developer est actif
4. Essayer de créer une nouvelle clé d'affiliation

### SumUp ne s'initialise pas après le login

**Solutions:**

1. Vérifier que `driver_profiles.sumup_affiliate_key` contient la clé:
   ```sql
   SELECT sumup_affiliate_key FROM driver_profiles WHERE user_id = 'driver_uuid';
   ```
2. Vérifier les politiques RLS sur `driver_profiles`
3. Consulter les logs Flutter pour les erreurs
4. Essayer de réenregistrer la clé dans les paramètres

### Une transaction SumUp échoue

**Solutions:**

- La transaction est automatiquement marquée comme `failed` dans la base de données
- Le chauffeur peut réessayer ou utiliser le paiement par jetons
- Consulter la table `sumup_transactions` pour les détails de l'erreur
- Vérifier que le compte SumUp du chauffeur est actif et vérifié
- Vérifier la connexion du terminal SumUp (si applicable)

## Sécurité et Confidentialité

### Protection des clés d'affiliation

- ✅ Les clés SumUp sont stockées de manière sécurisée dans `driver_profiles`
- ✅ Politiques RLS (Row Level Security) : chaque chauffeur ne peut voir que sa propre clé
- ✅ Les clés ne sont jamais exposées dans les logs
- ✅ Communication chiffrée entre l'app et Supabase

### Données personnelles

- Chaque chauffeur contrôle son propre compte SumUp
- Les paiements vont directement sur le compte du chauffeur
- UUMO ne gère pas les fonds (contrairement aux jetons)
- Le chauffeur peut supprimer sa clé à tout moment

### Politiques RLS

```sql
-- Chauffeur peut lire uniquement sa propre clé
CREATE POLICY "Drivers can read own SumUp key"
ON driver_profiles FOR SELECT
USING (auth.uid() = user_id);

-- Chauffeur peut mettre à jour uniquement sa propre clé
CREATE POLICY "Drivers can update own SumUp key"
ON driver_profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

## Avantages de l'Approche par Compte Individuel

### Pour les Chauffeurs

✅ **Autonomie totale** : Pas besoin d'attendre l'administrateur
✅ **Paiements directs** : Pas d'intermédiaire, fonds immédiats
✅ **Simplicité** : Configuration en 2 minutes dans l'app
✅ **Flexibilité** : Peut activer/désactiver quand il veut
✅ **Transparence** : Voit toutes ses transactions sur son compte SumUp

### Pour UUMO (l'entreprise)

✅ **Pas de gestion financière** : Pas de reversement à gérer
✅ **Responsabilité limitée** : Chaque chauffeur gère son compte
✅ **Scalabilité** : Pas de limite de chauffeurs
✅ **Conformité** : Chaque chauffeur est responsable de sa fiscalité
✅ **Coûts réduits** : Pas de compte SumUp centralisé à gérer

### Pour les Passagers

✅ **Plus d'options** : Peut payer par carte si le chauffeur l'accepte
✅ **Flexibilité** : Le choix appartient au chauffeur et au passager
✅ **Sécurité** : Transaction via SumUp (certifié PCI-DSS)

## Comparaison avec l'Approche Centralisée

| Critère                 | Approche 1: Centralisée | Approche 2: Individuelle (Actuelle) |
| ----------------------- | ----------------------- | ----------------------------------- |
| **Gestion**             | Par UUMO                | Par chaque chauffeur                |
| **Paiements**           | Vers compte UUMO        | Vers compte du chauffeur            |
| **Configuration**       | Dans `.env` (admin)     | Dans l'app (chauffeur)              |
| **Reversements**        | Requis                  | Aucun                               |
| **Scalabilité**         | Limitée                 | Illimitée                           |
| **Autonomie chauffeur** | Faible                  | Totale                              |
| **Complexité UUMO**     | Haute                   | Faible                              |

## Support

### Pour les Chauffeurs

**Problèmes avec SumUp:**

1. Consulter l'écran Configuration SumUp dans l'app
2. Utiliser la fonction "Tester la connexion"
3. Vérifier developer.sumup.com pour l'état du compte

**Support UUMO:**

- Section d'aide dans l'application
- Email support: support@uumo.com

### Pour les Développeurs

**Documentation code:**

- Service principal : `mobile_driver/lib/services/sumup_service.dart`
- Service config chauffeur : `mobile_driver/lib/services/driver_sumup_config_service.dart`
- Service post-login : `mobile_driver/lib/services/post_login_init_service.dart`
- Écran paramètres : `mobile_driver/lib/features/settings/presentation/screens/sumup_settings_screen.dart`
- Écran complétion : `mobile_driver/lib/features/trip/presentation/screens/trip_completion_screen.dart`

**Documentation externe:**

- SumUp Developer Portal : https://developer.sumup.com/docs/
- Package Flutter sumup : https://pub.dev/packages/sumup
- API Reference : https://developer.sumup.com/api/

---

**Dernière mise à jour:** 7 janvier 2026  
**Version:** 2.0.0 (Comptes individuels)  
**Projet:** UUMO - Urban Mobility Platform
