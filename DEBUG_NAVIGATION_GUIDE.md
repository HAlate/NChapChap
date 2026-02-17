# 🔍 Guide de Débogage - Navigation Driver

## ✅ Modifications apportées

### 1. **Logs de débogage complets**
Tous les points critiques ont maintenant des logs détaillés :
- Chargement de l'icône de voiture
- Création des marqueurs
- Création des polylines
- Position GPS

### 2. **Fallback pour les polylines**
Si Mapbox/le cache échoue :
- ✅ Ligne droite en pointillés (orange) entre le chauffeur et la destination
- ✅ Toujours visible même en cas d'erreur

### 3. **Fallback pour l'icône**
Si le fichier `car_top.png` n'est pas trouvé :
- ✅ Marqueur bleu par défaut utilisé

---

## 🔍 Comment déboguer

### Étape 1 : Lancer l'application
```bash
cd mobile_driver
flutter run
```

### Étape 2 : Regarder les logs dans la console

Cherchez ces messages dans l'ordre :

#### A. Initialisation
```
[DRIVER_NAV] ===== INIT STATE =====
[DRIVER_NAV] Pickup: -6.xxxx, 39.xxxx
[DRIVER_NAV] Destination: -6.xxxx, 39.xxxx
```
✅ Si vous voyez `0.0, 0.0` → **PROBLÈME : Les coordonnées ne sont pas passées correctement**

#### B. Chargement icône
```
[DRIVER_NAV] Loading car icon from assets/icons/car_top.png
[DRIVER_NAV] Car icon loaded successfully
```
❌ Si erreur → L'icône n'est pas dans le bon dossier ou mal déclarée dans pubspec.yaml

#### C. Création de la carte
```
[DRIVER_NAV] ===== MAP CREATED =====
[DRIVER_NAV] Calling _updateMarkers
[DRIVER_NAV] _currentPosition: Position(...)
[DRIVER_NAV] Total markers: 3
```
✅ Doit afficher **3 marqueurs** (driver + pickup + destination)

#### D. Polylines
```
[DRIVER_NAV] _updatePolylines called
[DRIVER_NAV] Fetching route from LatLng(...) to LatLng(...)
[DRIVER_NAV] Polyline points count: X
```
✅ Si `count: 0` → Fallback activé (ligne droite)
✅ Si `count: > 0` → Route Mapbox chargée

---

## ❌ Problèmes courants

### Problème 1 : Aucun marqueur visible
**Symptôme** : Carte vide, pas de marqueurs

**Causes possibles** :
1. Les coordonnées sont `0.0, 0.0`
2. Les marqueurs sont créés mais hors de l'écran
3. La caméra ne se centre pas correctement

**Solution** :
Regardez dans les logs :
```
[DRIVER_NAV] Pickup: 0.0, 0.0
```
Si vous voyez `0.0`, les données du trip ne contiennent pas les coordonnées.

### Problème 2 : Pas de polyline
**Symptôme** : Marqueurs visibles mais pas de ligne

**Causes possibles** :
1. Mapbox API key invalide ou manquante
2. Cache route vide
3. Erreur réseau

**Solution** :
Le fallback devrait créer une ligne droite. Cherchez :
```
[DRIVER_NAV] No polyline points, creating simple straight line
```
ou
```
[DRIVER_NAV] Fallback polyline created
```

### Problème 3 : Pas d'icône de voiture
**Symptôme** : Marqueurs pickup/destination OK, mais pas de voiture

**Causes possibles** :
1. `_currentPosition` est null
2. L'icône `car_top.png` n'est pas chargée
3. GPS non activé

**Solution** :
Cherchez :
```
[DRIVER_NAV] Cannot add driver marker: position=false, icon=true
```
→ Problème GPS

```
[DRIVER_NAV] Cannot add driver marker: position=true, icon=false
```
→ Problème chargement icône

---

## 🧪 Test en mode simulé

Si le GPS ne fonctionne pas :

1. **Activer le mode test** : Cliquez sur l'icône 🐛 en haut à droite
2. Une position simulée sera créée à ~500m du pickup
3. Les logs afficheront :
```
[OfferService] Driver position: -6.xxxx, 39.xxxx
```

---

## 📱 Vérifications rapides

### 1. Vérifier les assets
```bash
ls mobile_driver/assets/icons/car_top.png
```
Le fichier doit exister.

### 2. Vérifier pubspec.yaml
```yaml
flutter:
  assets:
    - assets/icons/car_top.png
```

### 3. Redémarrer après modification assets
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🆘 Si rien ne fonctionne

**Partagez ces informations :**
1. Les logs complets depuis `[DRIVER_NAV] ===== INIT STATE =====`
2. Screenshot de la carte
3. Les valeurs de `widget.tripData` dans les logs

Les logs vous diront EXACTEMENT où ça bloque ! 🎯
