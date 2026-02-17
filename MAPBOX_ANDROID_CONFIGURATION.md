# Configuration MapBox pour mobile_driver

## Problème résolu
```
SDK Registry token is null. See README.md for more information.
```

## Solution appliquée

### 1. **gradle.properties** - Ajout du token
**Fichier :** `mobile_driver/android/gradle.properties`

```properties
MAPBOX_DOWNLOADS_TOKEN=YOUR_MAPBOX_SECRET_TOKEN
```

Ce token est un **secret token** pour télécharger le SDK MapBox. Il est différent du token public utilisé dans `.env`.

### 2. **build.gradle** - Configuration Maven
**Fichier :** `mobile_driver/android/build.gradle`

Ajout du repository MapBox Maven avec authentification :

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        // MapBox Maven repository
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                basic(BasicAuthentication)
            }
            credentials {
                username = "mapbox"
                password = project.hasProperty('MAPBOX_DOWNLOADS_TOKEN') 
                    ? project.property('MAPBOX_DOWNLOADS_TOKEN') 
                    : System.getenv('MAPBOX_DOWNLOADS_TOKEN')
            }
        }
    }
}
```

## Tokens MapBox utilisés

### Token Secret (Downloads)
- **Utilisation :** Téléchargement du SDK Android
- **Fichier :** `android/gradle.properties`
- **Variable :** `MAPBOX_DOWNLOADS_TOKEN`
- **Valeur :** `YOUR_MAPBOX_SECRET_TOKEN`

### Token Public (Runtime)
- **Utilisation :** Affichage des cartes dans l'app
- **Fichier :** `.env`
- **Variable :** `MAPBOX_ACCESS_TOKEN`
- **Valeur :** `YOUR_MAPBOX_ACCESS_TOKEN`

## Configuration iOS (si nécessaire)

Si vous compilez pour iOS, ajoutez ceci dans `ios/Podfile` :

```ruby
# MapBox configuration
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
```

Et dans `ios/Runner/Info.plist` :

```xml
<key>MBXAccessToken</key>
<string>YOUR_MAPBOX_ACCESS_TOKEN</string>
```

## Prochaines étapes

1. ✅ gradle.properties mis à jour
2. ✅ build.gradle configuré
3. 🔄 Relancer `flutter clean`
4. 🔄 Relancer `flutter pub get`
5. 🔄 Relancer `flutter run`

---

**Date :** 19 décembre 2025
