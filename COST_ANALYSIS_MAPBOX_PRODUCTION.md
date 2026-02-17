# 💰 Évaluation des Coûts - Mapbox en Production

## 📊 Scénario: 10 000 Riders - 100 000 Requêtes/Jour

**Date d'évaluation** : 19 décembre 2025  
**Configuration** : Google Maps SDK (display) + Mapbox APIs (directions + geocoding)

---

## 🎯 Hypothèses du Scénario

### Volume
- **Riders actifs** : 10 000
- **Requêtes totales** : 100 000/jour
- **Jours/mois** : 30
- **Requêtes mensuelles** : **3 000 000**

### Répartition des Requêtes

Par course typique, on estime:
- **2 recherches d'adresses** (autocomplete départ + destination)
- **1 calcul d'itinéraire** (directions)
- **1 reverse geocoding** (confirmation position)

**Répartition estimée** :
| Type de requête | % | Requêtes/jour | Requêtes/mois |
|----------------|---|---------------|---------------|
| Geocoding (Search) | 40% | 40 000 | 1 200 000 |
| Directions | 35% | 35 000 | 1 050 000 |
| Reverse Geocoding | 15% | 15 000 | 450 000 |
| Autres (autocomplete) | 10% | 10 000 | 300 000 |
| **TOTAL** | **100%** | **100 000** | **3 000 000** |

---

## 💵 Tarification Mapbox

### Quotas Gratuits (par mois)
- ✅ **Geocoding** : 100 000 requêtes gratuites
- ✅ **Directions** : 100 000 requêtes gratuites
- ✅ **Static Images** : 200 000 gratuites (non utilisé ici)

### Tarification au-delà du quota gratuit

| Service | Prix après quota gratuit |
|---------|-------------------------|
| Geocoding | $0.50 / 1 000 requêtes |
| Directions | $0.40 / 1 000 requêtes |
| Reverse Geocoding | $0.50 / 1 000 requêtes (même que Geocoding) |

---

## 📈 Calcul des Coûts Mensuels

### 1. Geocoding (Forward + Autocomplete)

**Volume mensuel** : 1 200 000 + 300 000 = 1 500 000 requêtes

```
Quota gratuit :        100 000 requêtes → $0
Requêtes payantes : 1 400 000 requêtes → 1 400 × $0.50 = $700
```

**Coût Geocoding** : **$700/mois**

---

### 2. Directions

**Volume mensuel** : 1 050 000 requêtes

```
Quota gratuit :        100 000 requêtes → $0
Requêtes payantes :    950 000 requêtes → 950 × $0.40 = $380
```

**Coût Directions** : **$380/mois**

---

### 3. Reverse Geocoding

**Volume mensuel** : 450 000 requêtes

```
Quota gratuit :       Déjà utilisé dans Geocoding
Requêtes payantes :   450 000 requêtes → 450 × $0.50 = $225
```

**Coût Reverse Geocoding** : **$225/mois**

---

## 💰 COÛT TOTAL MAPBOX

### Résumé Mensuel (SANS cache)

| Service | Requêtes/mois | Quota gratuit | Payant | Coût |
|---------|---------------|---------------|--------|------|
| Geocoding + Autocomplete | 1 500 000 | 100 000 | 1 400 000 | **$700** |
| Directions | 1 050 000 | 100 000 | 950 000 | **$380** |
| Reverse Geocoding | 450 000 | 0 | 450 000 | **$225** |
| **TOTAL SANS CACHE** | **3 000 000** | **200 000** | **2 800 000** | **$1 305** |

### 🚀 AVEC Système de Cache Implémenté

**Taux de hit cache estimé** :
- Geocoding/Autocomplete : **40%** (requêtes fréquentes)
- Routes : **30%** (trafic change souvent)
- Reverse Geocoding : **35%** (lieux populaires)

#### Requêtes réelles à Mapbox après cache

| Service | Requêtes initiales | Cache hit | Requêtes API | Coût |
|---------|-------------------|-----------|--------------|------|
| Geocoding + Autocomplete | 1 500 000 | 40% (600k) | 900 000 | **$450** |
| Directions | 1 050 000 | 30% (315k) | 735 000 | **$254** |
| Reverse Geocoding | 450 000 | 35% (157k) | 293 000 | **$97** |
| **TOTAL AVEC CACHE** | **3 000 000** | **1 072 000** | **1 928 000** | **$801** |

### 💵 Économies Grâce au Cache

| Métrique | Valeur |
|----------|--------|
| **Coût SANS cache** | $1 305/mois |
| **Coût AVEC cache** | $801/mois |
| **Économies** | **$504/mois** |
| **Réduction** | **38.6%** |
| **Économies annuelles** | **$6 048** |

### Coût Total Mapbox OPTIMISÉ : **$801/mois**

---

## 🔄 Comparaison avec Google Maps

### Tarification Google Maps (à volume équivalent)

| Service Google | Requêtes/mois | Prix unitaire | Coût |
|----------------|---------------|---------------|------|
| Places Autocomplete | 1 500 000 | $2.83/1000 | **$4 245** |
| Directions | 1 050 000 | $5.00/1000 | **$5 250** |
| Geocoding | 450 000 | $4.00/1000 | **$1 800** |
| **TOTAL** | **3 000 000** | - | **$11 295** |

*Note: Google offre $200 de crédit gratuit/mois, soit coût réel de $11 095*

---

## 📊 Comparatif Final

| Provider | Coût Mensuel | Coût Annuel |
|----------|--------------|-------------|
| Google Maps | $11 095 | $133 140 |
| **Mapbox SANS cache** | **$1 305** | **$15 660** |
| **Mapbox AVEC cache** | **$801** | **$9 612** |
| **ÉCONOMIES vs Google** | **$10 294** | **$123 528** |

### Réduction de coûts : 
- **vs Google Maps** : **92.8% d'économies** 🎉
- **vs Mapbox sans cache** : **38.6% d'économies supplémentaires** 🚀

### Impact du système de cache
- **Coût mensuel réduit de** : $504
- **ROI du développement cache** : Rentabilisé en **2.8 jours**
- **Économies annuelles cache** : **$6 048**

---

## 🎯 Scénarios Alternatifs

### Scénario 1 : Volume Réduit (50 000 requêtes/jour)

**Mensuel** : 1 500 000 requêtes

| Service | Payant | Coût |
|---------|--------|------|
| Geocoding | 650 000 | $325 |
| Directions | 425 000 | $170 |
| Reverse Geocoding | 225 000 | $112.50 |
| **TOTAL** | - | **$607.50/mois** |

**vs Google** : ~$5 500/mois → **Économies : $4 892.50/mois**

---

### Scénario 2 : Volume Doublé (200 000 requêtes/jour)

**Mensuel** : 6 000 000 requêtes

| Service | Payant | Coût |
|---------|--------|------|
| Geocoding | 2 900 000 | $1 450 |
| Directions | 2 000 000 | $800 |
| Reverse Geocoding | 900 000 | $450 |
| **TOTAL** | - | **$2 700/mois** |

**vs Google** : ~$22 500/mois → **Économies : $19 800/mois**

---

### Scénario 3 : Optimisation Avancée

**Stratégies de réduction** :

1. **Caching intelligent**
   - Cache des adresses fréquentes (restaurants, lieux populaires)
   - Réduction estimée : -20% des requêtes geocoding

2. **Debouncing autocomplete**
   - Attendre 300ms avant de lancer la recherche
   - Réduction estimée : -30% des requêtes autocomplete

3. **Réutilisation des itinéraires**
   - Cache des routes populaires pendant 5 minutes
   - Réduction estimée : -10% des requêtes directions

**Impact** :

| Optimisation | Économies/mois |
|--------------|----------------|
| Cache geocoding | -$140 |
| Debouncing | -$105 |
| Cache routes | -$38 |
| **TOTAL OPTIMISÉ** | **$1 022/mois** |

**Économies supplémentaires** : $283/mois

---

## 📉 Projection sur 12 Mois

### Croissance Prévue

| Mois | Riders | Requêtes/jour | Coût Mapbox | Coût Google | Économies |
|------|--------|---------------|-------------|-------------|-----------|
| Mois 1-3 | 10 000 | 100 000 | $1 305 | $11 095 | $9 790 |
| Mois 4-6 | 15 000 | 150 000 | $1 957 | $16 643 | $14 686 |
| Mois 7-9 | 20 000 | 200 000 | $2 700 | $22 190 | $19 490 |
| Mois 10-12 | 25 000 | 250 000 | $3 262 | $27 738 | $24 476 |

**Économies année 1** : **$204 996**

---

## 🛡️ Stratégie de Mitigation des Coûts

### 1. Monitoring en Temps Réel

**Alertes à configurer** :
- ⚠️ Si > 80% du quota gratuit utilisé (80 000 requêtes)
- 🔴 Si coût quotidien > $50
- 🔴 Si projection mensuelle > $1 500

**Dashboard Mapbox** : https://account.mapbox.com/

---

### 2. Optimisations Techniques

**Immediate (Low-Hanging Fruit)** :

```dart
// 1. Debouncing autocomplete
Timer? _debounce;
void onSearchChanged(String query) {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    // Appeler Mapbox seulement après 300ms d'inactivité
    mapboxGeocoding.searchPlaces(query);
  });
}

// 2. Cache simple en mémoire
final Map<String, List<Place>> _autocompleteCache = {};
Future<List<Place>> searchPlacesWithCache(String query) async {
  if (_autocompleteCache.containsKey(query)) {
    return _autocompleteCache[query]!;
  }
  final results = await mapboxGeocoding.searchPlaces(query);
  _autocompleteCache[query] = results;
  return results;
}

// 3. Limiter le nombre de résultats
final places = await mapboxGeocoding.searchPlaces(
  query,
  limit: 5, // Au lieu de 10
);
```

**Impact estimé** : -$200/mois

---

### 3. Plan de Contingence

**Si coûts dépassent $2 000/mois** :

1. **Option A** : Hybrid caching avec Supabase
   - Stocker les 1000 adresses les plus recherchées
   - Coût Supabase : ~$25/mois
   - Économies : ~$300/mois

2. **Option B** : Rate limiting par utilisateur
   - Max 50 recherches/jour par rider
   - Évite les abus/bots
   - Réduction estimée : -15%

3. **Option C** : Passer à un plan entreprise Mapbox
   - Négocier un tarif volume
   - Généralement -20% à -30% sur tarifs publics

---

## 💡 Recommandations

### Court Terme (0-3 mois)

1. ✅ **Implémenter le debouncing** immédiatement
   - Économies : ~$100/mois
   - Effort : 2 heures dev

2. ✅ **Configurer les alertes** Mapbox
   - Éviter les surprises de facturation
   - Effort : 30 minutes

3. ✅ **Monitorer l'usage réel**
   - Dashboard hebdomadaire
   - Ajuster les estimations

### Moyen Terme (3-6 mois)

1. 📊 **Implémenter le caching intelligent**
   - Cache Supabase pour adresses populaires
   - ROI : 6 semaines
   - Économies : $200-300/mois

2. 🔍 **Analyser les patterns d'utilisation**
   - Identifier les pics
   - Optimiser les moments de forte charge

3. 🤝 **Négocier avec Mapbox**
   - Volume prévu : 3-6M requêtes/mois
   - Demander un tarif entreprise

### Long Terme (6-12 mois)

1. 🚀 **Évaluer d'autres providers**
   - HERE Maps, TomTom
   - Comparer les tarifs volume

2. 🏗️ **Architecture hybride avancée**
   - Combiner plusieurs providers
   - Failover automatique
   - Optimisation des coûts

---

## 📋 Checklist de Mise en Production

### Avant le lancement

- [ ] Configurer le plan Mapbox (Pay-as-you-go ou Enterprise)
- [ ] Mettre en place les alertes de facturation
- [ ] Implémenter le debouncing autocomplete
- [ ] Tester avec charge réelle (staging)
- [ ] Documenter les KPIs à suivre

### Monitoring Post-Lancement

- [ ] Suivi quotidien des coûts (semaine 1)
- [ ] Dashboard hebdomadaire (mois 1-3)
- [ ] Review mensuel avec optimisations
- [ ] Projection trimestrielle

### Optimisation Continue

- [ ] A/B testing différents seuils de debouncing
- [ ] Analyse des requêtes redondantes
- [ ] Implémentation cache progressif
- [ ] Benchmark vs autres providers

---

## 🎯 ROI de la Migration

### Investissement Initial

| Poste | Coût |
|-------|------|
| Développement (migration) | 16 heures × $50/h = $800 |
| Tests et validation | 8 heures × $50/h = $400 |
| Documentation | 4 heures × $50/h = $200 |
| **TOTAL INVESTISSEMENT** | **$1 400** |

### Retour sur Investissement

**Mois 1** :
- Économies : $9 790
- Coût migration : -$1 400
- **Bénéfice net : $8 390**

**ROI : Rentabilisé en 4 jours** 🚀

---

## 📊 Tableau de Bord Recommandé

### KPIs à suivre

| Métrique | Cible | Alerte si |
|----------|-------|-----------|
| Coût/jour | < $44 | > $50 |
| Requêtes/rider/jour | ~10 | > 20 |
| Taux d'erreur API | < 1% | > 2% |
| Temps de réponse moyen | < 500ms | > 1000ms |
| Cache hit rate | > 30% | < 20% |

### Outils de Monitoring

1. **Mapbox Dashboard** : Utilisation temps réel
2. **Supabase** : Logs applicatifs
3. **Google Analytics** : Comportement utilisateur
4. **Custom Dashboard** : Vue consolidée

---

## 📞 Contact Mapbox

Pour négocier un tarif entreprise :

**Email** : sales@mapbox.com  
**Argument** : 3-6M requêtes/mois prévues  
**Demande** : Tarif volume réduit de 20-30%

**Impact potentiel** : -$260 à -$390/mois supplémentaires

---

## ✅ Conclusion

### Résumé Exécutif

**Scénario** : 10 000 riders, 100 000 requêtes/jour

| Métrique | Valeur |
|----------|--------|
| **Coût Mapbox** | **$1 305/mois** |
| Coût Google Maps | $11 095/mois |
| **Économies** | **$9 790/mois** |
| **ROI migration** | **4 jours** |
| **Économies annuelles** | **$117 480** |

### Recommandation

✅ **La migration vers Mapbox est hautement recommandée**

**Raisons** :
1. 💰 Économies massives (88%)
2. 🚀 ROI immédiat (< 1 semaine)
3. 📈 Scalabilité sans explosion des coûts
4. 🛡️ Stratégies d'optimisation disponibles
5. 🌍 Meilleure couverture Afrique

**Risques** : Faibles
**Impact** : Très positif

---

**Document créé le** : 19 décembre 2025  
**Validité** : 12 mois (revoir si changement tarifs Mapbox)  
**Prochaine révision** : Mars 2026
