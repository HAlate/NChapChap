# Modèle Économique UUMO

## Vue d'ensemble

UUMO fonctionne sur un modèle de **vente de jetons** aux chauffeurs. Les paiements des courses se font directement entre chauffeurs et passagers, UUMO ne touche pas à cet argent.

## Flux Financiers

### 1. Revenu UUMO : Vente de Jetons 💰

```
Chauffeur → [Stripe] → UUMO
         Achète des jetons
         1 jeton = droit de faire 1 offre
```

**Comment ça fonctionne :**

- Le chauffeur achète des jetons via **Stripe** (carte bancaire, Apple Pay, Google Pay)
- Prix exemple : 10 jetons = 20F
- **C'est ici que UUMO gagne de l'argent**
- Les jetons sont stockés dans `token_balances`

**Fichiers concernés :**

- Migration : `20260107000005_add_stripe_payments.sql`
- Edge Functions : `stripe-create-payment-intent`, `stripe-webhook`
- Écran : `mobile_driver/lib/features/tokens/presentation/screens/token_purchase_screen.dart`

### 2. Utilisation des Jetons

```
Chauffeur → [Fait une offre] → Plateforme UUMO
         1 offre = 1 jeton déduit automatiquement
```

**Comment ça fonctionne :**

- Un passager publie une demande de course
- Le chauffeur fait une offre
- Quand le passager **accepte l'offre** → **1 jeton est automatiquement déduit**
- Déduction via trigger : `spend_token_on_trip_offer_acceptance()`

**Fichiers concernés :**

- Migration : `20251130014703_create_token_deduction_trigger.sql`
- Trigger SQL : Déduit automatiquement le jeton quand `trip_offers.status = 'accepted'`

### 3. Paiement de la Course (Hors UUMO) 💵

```
Passager → [Cash/Carte] → Chauffeur
         Paye directement le chauffeur
         UUMO ne touche RIEN
```

**Comment ça fonctionne :**

- Le paiement se fait **directement entre passager et chauffeur**
- Deux options :
  1. **Espèces** (cash) - par défaut
  2. **Carte bancaire** via SumUp (optionnel)

**IMPORTANT :**

- ❌ UUMO ne gère PAS ce paiement
- ❌ UUMO ne prend PAS de commission sur ce paiement
- ✅ Le chauffeur garde 100% de l'argent de la course
- ✅ UUMO a déjà gagné via la vente du jeton

### 4. SumUp : Simple Outil d'Encaissement 💳

```
Passager → [Carte bancaire] → SumUp → Chauffeur
         Optionnel, pour les passagers sans cash
         Argent va au chauffeur, pas à UUMO
```

**Comment ça fonctionne :**

- Chaque chauffeur configure **son propre compte SumUp**
- Si le passager n'a pas d'espèces, le chauffeur peut encaisser par carte
- L'argent va **directement sur le compte SumUp du chauffeur**
- UUMO fournit juste le support technique (intégration SDK)

**Fichiers concernés :**

- Migration : `20260107000006_add_sumup_payments.sql`
- Migration : `20260107000007_add_sumup_individual_keys.sql`
- Service : `mobile_driver/lib/services/sumup_service.dart`
- Écran config : `mobile_driver/lib/features/settings/presentation/screens/sumup_settings_screen.dart`

## Écran de Fin de Course

### Interface Chauffeur

Quand la course est terminée, le chauffeur a **2 options** :

#### Option 1 : Paiement en espèces (par défaut)

```
Bouton : "Terminer la course" (vert)
→ Marque la course comme complétée
→ payment_method = 'cash'
→ Aucun encaissement via SumUp
```

#### Option 2 : Encaissement par carte (si SumUp configuré)

```
Bouton : "Encaisser par carte" (orange)
→ Ouvre SumUp SDK
→ Passager tape sa carte
→ Argent va sur compte SumUp du chauffeur
→ Marque la course comme complétée
→ payment_method = 'sumup'
```

**Fichier :** `mobile_driver/lib/features/trip/presentation/screens/trip_completion_screen.dart`

### Workflow Complet

```
1. Passager publie demande de course
2. Chauffeur fait une offre
3. Passager accepte l'offre → ✅ 1 jeton déduit (UUMO gagne)
4. Chauffeur effectue la course
5. Fin de course :
   - Si passager paye en espèces → "Terminer la course"
   - Si passager paye par carte → "Encaisser par carte" (SumUp)
6. Course marquée comme complétée
```

## Avantages du Modèle

### Pour UUMO

- ✅ **Revenu prévisible** : Vente de jetons
- ✅ **Pas de gestion financière** : Pas de reversements aux chauffeurs
- ✅ **Scalabilité** : Pas de limite
- ✅ **Responsabilité limitée** : Pas de gestion de l'argent des courses
- ✅ **Simple** : Un seul flux de revenus (jetons)

### Pour les Chauffeurs

- ✅ **Autonomie** : Garde 100% de l'argent des courses
- ✅ **Flexibilité** : Peut accepter espèces ET cartes (avec SumUp)
- ✅ **Transparent** : Sait exactement combien coûte une offre (1 jeton)
- ✅ **Pas de commission** sur les courses

### Pour les Passagers

- ✅ **Options de paiement** : Espèces ou carte (si chauffeur a SumUp)
- ✅ **Prix direct** : Négocie directement avec le chauffeur
- ✅ **Flexibilité** : Peut choisir sa méthode de paiement

## Comparaison avec Modèles Traditionnels

| Critère                 | Uber/Bolt (Commission) | UUMO (Jetons)             |
| ----------------------- | ---------------------- | ------------------------- |
| **Revenu plateforme**   | % de chaque course     | Vente de jetons           |
| **Gestion paiements**   | Plateforme gère tout   | Direct chauffeur↔passager |
| **Commission course**   | 20-30%                 | 0%                        |
| **Reversements**        | Hebdomadaires/mensuels | Aucun                     |
| **Complexité fiscale**  | Haute                  | Faible                    |
| **Coût pour chauffeur** | Variable (% course)    | Fixe (prix jeton)         |

## Configurations Requises

### Pour activer les paiements

**1. Stripe (OBLIGATOIRE pour UUMO)**

```env
# mobile_driver/.env
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx
```

Configuration dans Supabase :

- Edge Function `stripe-create-payment-intent` déployée
- Edge Function `stripe-webhook` déployée (webhook configuré sur Stripe)

**2. SumUp (OPTIONNEL pour chaque chauffeur)**

```
Chauffeur → Paramètres → Configuration SumUp
→ Saisit sa clé d'affiliation (de developer.sumup.com)
→ Teste la connexion
→ Enregistre
```

## Base de Données

### Tables Principales

**token_packages** : Packages de jetons disponibles à l'achat

```sql
id, name, token_amount, price_usd, stripe_price_id
```

**token_balances** : Solde de jetons de chaque chauffeur

```sql
user_id, token_type, balance
```

**token_transactions** : Historique des transactions de jetons

```sql
id, user_id, transaction_type (purchase, spend), amount
```

**stripe_transactions** : Paiements Stripe (achat de jetons)

```sql
id, user_id, amount_cents, stripe_payment_intent_id, status
```

**sumup_transactions** : Encaissements SumUp (courses)

```sql
id, trip_id, driver_id, amount_cents, status
```

### Triggers Importants

**spend_token_on_trip_offer_acceptance()** :

- Déclenché quand `trip_offers.status = 'accepted'`
- Déduit automatiquement 1 jeton
- Enregistre dans `token_transactions`

## Sécurité

### Jetons

- ✅ RLS (Row Level Security) : Chaque chauffeur voit uniquement son solde
- ✅ Trigger atomique : Pas de double déduction possible
- ✅ Vérification solde avant acceptation d'offre

### Paiements Stripe

- ✅ Webhook signé : Vérification signature Stripe
- ✅ Idempotence : Pas de double paiement
- ✅ Edge Functions : Code côté serveur sécurisé

### SumUp

- ✅ Comptes individuels : Chaque chauffeur son propre compte
- ✅ RLS : Chaque chauffeur voit uniquement sa clé
- ✅ Optionnel : App fonctionne sans SumUp

## Questions Fréquentes

**Q: Pourquoi le chauffeur doit payer des jetons ?**
R: C'est le modèle économique de UUMO. Au lieu de prendre une commission sur chaque course, UUMO vend des "crédits" pour faire des offres.

**Q: Le passager paye-t-il UUMO ?**
R: Non, le passager paye directement le chauffeur (espèces ou carte via SumUp du chauffeur).

**Q: UUMO prend une commission sur les courses ?**
R: Non, 0% de commission. UUMO gagne uniquement sur la vente de jetons.

**Q: Que se passe-t-il si le chauffeur n'a plus de jetons ?**
R: Il ne peut plus faire d'offres. Il doit acheter des jetons via Stripe.

**Q: SumUp est-il obligatoire ?**
R: Non, c'est optionnel. Le chauffeur peut n'accepter que les espèces.

**Q: Qui gère les litiges de paiement course ?**
R: Le chauffeur et le passager directement. UUMO n'intervient pas dans le paiement de la course.

---

**Date:** 8 janvier 2026  
**Version:** 2.0  
**Projet:** UUMO - Urban Mobility Platform
