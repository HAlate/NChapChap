# ============================================
# UUMO LOGOS GENERATION SCRIPT - PowerShell
# ============================================

Write-Host "🎨 Générateur de Logos UUMO" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# --------------------------------------------------
# CONFIGURATION
# --------------------------------------------------
$PROJECT_ROOT = Get-Location
$ASSETS_DIR = Join-Path $PROJECT_ROOT "assets"
$LOGOS_DIR = Join-Path $ASSETS_DIR "logos"
$ICONS_DIR = Join-Path $ASSETS_DIR "icons"
$SPLASH_DIR = Join-Path $ASSETS_DIR "splash"

# Couleurs des variantes
$COLORS = @{
    "rider"    = "#FF6B35"
    "driver"   = "#34C759"
    "eat"      = "#FF3B30"
    "merchant" = "#007AFF"
}

# Tailles pour les icônes
$SIZES = @{
    "app_icon"      = @(1024, 512, 256, 192, 144, 96, 72, 48)
    "adaptive_icon" = @(432, 324, 216, 162, 108, 81, 54)
    "notification"  = @(96, 72, 48, 36, 24)
    "store"         = @(1024, 512)
}

# --------------------------------------------------
# FONCTIONS
# --------------------------------------------------
function New-AssetsDirectories {
    Write-Host "`n📁 Création de la structure des dossiers..." -ForegroundColor Yellow
    
    $directories = @(
        $ASSETS_DIR,
        $LOGOS_DIR,
        $ICONS_DIR,
        $SPLASH_DIR,
        (Join-Path $LOGOS_DIR "svg"),
        (Join-Path $LOGOS_DIR "png"),
        (Join-Path $LOGOS_DIR "variants"),
        (Join-Path $ICONS_DIR "ios"),
        (Join-Path $ICONS_DIR "android"),
        (Join-Path $ICONS_DIR "adaptive"),
        (Join-Path $SPLASH_DIR "ios"),
        (Join-Path $SPLASH_DIR "android")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-Host "  ✓ $dir" -ForegroundColor Green
        }
    }
}

function New-SVGLogo {
    param(
        [string]$variant = "rider",
        [string]$type = "full"
    )
    
    $color = $COLORS[$variant]
    $filename = "uumo_$variant"
    if ($type -eq "icon") { $filename += "_icon" }
    $filepath = Join-Path (Join-Path $LOGOS_DIR "svg") "$filename.svg"
    
    $svgContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<svg width="200" height="80" viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <linearGradient id="grad-$variant" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="$color"/>
            <stop offset="100%" stop-color="$(Get-LighterColor $color)"/>
        </linearGradient>
        
        <filter id="glow-$variant">
            <feGaussianBlur stdDeviation="2" result="blur"/>
            <feComposite in="SourceGraphic" in2="blur" operator="over"/>
        </filter>
    </defs>
    
    <!-- Premier U -->
    <path d="M10,50 Q10,20 30,20 L40,20 Q60,20 60,50 L60,60 Q60,70 40,70 L30,70 Q10,70 10,60 Z"
          fill="url(#grad-$variant)" filter="url(#glow-$variant)"/>
    
    <!-- Deuxième U -->
    <path d="M70,50 Q70,20 90,20 L100,20 Q120,20 120,50 L120,60 Q120,70 100,70 L90,70 Q70,70 70,60 Z"
          fill="url(#grad-$variant)" filter="url(#glow-$variant)"/>
    
    <!-- M (signal) -->
    <path d="M130,70 L140,30 L150,50 L160,30 L170,70"
          stroke="url(#grad-$variant)" stroke-width="8" fill="none" 
          stroke-linecap="round" stroke-linejoin="round"/>
    
    <!-- O (cercle) -->
    <circle cx="195" cy="45" r="15" fill="none" 
            stroke="url(#grad-$variant)" stroke-width="8"/>
    <circle cx="195" cy="45" r="4" fill="url(#grad-$variant)"/>
</svg>
"@
    
    $svgContent | Out-File -FilePath $filepath -Encoding UTF8
    Write-Host "  ✓ SVG généré: $filename.svg" -ForegroundColor Green
    
    return $filepath
}

function Get-LighterColor {
    param([string]$hexColor)
    
    # Convertir hex en RGB
    $r = [Convert]::ToInt32($hexColor.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hexColor.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hexColor.Substring(5, 2), 16)
    
    # Éclaircir de 20%
    $r = [Math]::Min(255, [int]($r * 1.2))
    $g = [Math]::Min(255, [int]($g * 1.2))
    $b = [Math]::Min(255, [int]($b * 1.2))
    
    return "#$($r.ToString('X2'))$($g.ToString('X2'))$($b.ToString('X2'))"
}

function New-AppIcons {
    param([string]$variant = "rider")
    
    Write-Host "`n📱 Génération des icônes d'application pour $variant..." -ForegroundColor Yellow
    
    # Icône principale
    $iconSvg = @"
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
    <rect width="1024" height="1024" rx="192" fill="$($COLORS[$variant])"/>
    
    <g transform="translate(212, 212) scale(1.5)" fill="#FFFFFF">
        <!-- Premier U -->
        <path d="M80,200 Q80,80 160,80 L200,80 Q280,80 280,200 L280,240 Q280,320 200,320 L160,320 Q80,320 80,240 Z"/>
        
        <!-- Deuxième U -->
        <path d="M320,200 Q320,80 400,80 L440,80 Q520,80 520,200 L520,240 Q520,320 440,320 L400,320 Q320,320 320,240 Z"/>
        
        <!-- M -->
        <path d="M560,320 L600,160 L640,200 L680,160 L720,320" 
              stroke="#FFFFFF" stroke-width="30" fill="none"/>
        
        <!-- O -->
        <circle cx="840" cy="180" r="50" fill="none" stroke="#FFFFFF" stroke-width="30"/>
        <circle cx="840" cy="180" r="15" fill="#FFFFFF"/>
    </g>
</svg>
"@
    
    $iconPath = Join-Path (Join-Path $ICONS_DIR "ios") "app_icon_$variant.svg"
    $iconSvg | Out-File -FilePath $iconPath -Encoding UTF8
    
    # Générer les tailles PNG (nécessite Inkscape ou ImageMagick)
    New-PNGFromSVG -svgPath $iconPath -variant $variant
    
    Write-Host "  ✓ Icônes générées pour $variant" -ForegroundColor Green
}

function New-PNGFromSVG {
    param(
        [string]$svgPath,
        [string]$variant
    )
    
    # Vérifier si Inkscape est installé
    if (Get-Command inkscape -ErrorAction SilentlyContinue) {
        Write-Host "  → Conversion SVG vers PNG avec Inkscape..." -ForegroundColor Gray
        
        foreach ($size in $SIZES.app_icon) {
            $outputPath = Join-Path (Join-Path $ICONS_DIR "ios") "icon_${size}_$variant.png"
            & inkscape $svgPath --export-filename=$outputPath --export-width=$size --export-height=$size
        }
    } 
    elseif (Get-Command magick -ErrorAction SilentlyContinue) {
        Write-Host "  → Conversion SVG vers PNG avec ImageMagick..." -ForegroundColor Gray
        
        foreach ($size in $SIZES.app_icon) {
            $outputPath = Join-Path (Join-Path $ICONS_DIR "ios") "icon_${size}_$variant.png"
            & magick convert -background none $svgPath -resize ${size}x${size} $outputPath
        }
    }
    else {
        Write-Host "  ⚠️  Installez Inkscape ou ImageMagick pour la conversion PNG" -ForegroundColor Yellow
        Write-Host "  📦 Inkscape: https://inkscape.org/release/" -ForegroundColor Gray
        Write-Host "  📦 ImageMagick: https://imagemagick.org/script/download.php" -ForegroundColor Gray
    }
}

function New-AdaptiveIcons {
    param([string]$variant = "rider")
    
    Write-Host "`n📱 Génération des icônes adaptatives Android..." -ForegroundColor Yellow
    
    # Foreground (logo)
    $foregroundSvg = @"
<svg width="108" height="108" viewBox="0 0 108 108" xmlns="http://www.w3.org/2000/svg">
    <g transform="translate(4, 4)" fill="#FFFFFF">
        <!-- Logo simplifié -->
        <path d="M20,50 Q20,30 35,30 L40,30 Q55,30 55,50 L55,55 Q55,70 40,70 L35,70 Q20,70 20,55 Z"/>
        <path d="M60,50 Q60,30 75,30 L80,30 Q95,30 95,50 L95,55 Q95,70 80,70 L75,70 Q60,70 60,55 Z"/>
        <circle cx="85" cy="50" r="8" fill="none" stroke="#FFFFFF" stroke-width="3"/>
    </g>
</svg>
"@
    
    $fgPath = Join-Path (Join-Path $ICONS_DIR "adaptive") "${variant}_foreground.svg"
    $foregroundSvg | Out-File -FilePath $fgPath -Encoding UTF8
    
    # Background (couleur)
    $backgroundSvg = @"
<svg width="108" height="108" viewBox="0 0 108 108" xmlns="http://www.w3.org/2000/svg">
    <rect width="108" height="108" rx="24" fill="$($COLORS[$variant])"/>
</svg>
"@
    
    $bgPath = Join-Path (Join-Path $ICONS_DIR "adaptive") "${variant}_background.svg"
    $backgroundSvg | Out-File -FilePath $bgPath -Encoding UTF8
    
    Write-Host "  ✓ Icônes adaptatives générées" -ForegroundColor Green
}

function New-Favicon {
    param([string]$variant = "rider")
    
    Write-Host "`n🌐 Génération du favicon..." -ForegroundColor Yellow
    
    $faviconSvg = @"
<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
    <rect width="32" height="32" rx="6" fill="$($COLORS[$variant])"/>
    <text x="16" y="22" fill="#FFFFFF" font-family="Arial" font-size="14" 
          font-weight="bold" text-anchor="middle">UU</text>
</svg>
"@
    
    $faviconPath = Join-Path $LOGOS_DIR "favicon_$variant.svg"
    $faviconSvg | Out-File -FilePath $faviconPath -Encoding UTF8
    
    # Générer aussi en PNG
    if (Get-Command magick -ErrorAction SilentlyContinue) {
        $pngPath = Join-Path $LOGOS_DIR "favicon_$variant.png"
        & magick convert -background none $faviconPath -resize 32x32 $pngPath
    }
    
    Write-Host "  ✓ Favicon généré" -ForegroundColor Green
}

function New-SplashAssets {
    param([string]$variant = "rider")
    
    Write-Host "`n✨ Génération des assets de splash screen..." -ForegroundColor Yellow
    
    # Logo pour splash screen
    $splashLogoSvg = @"
<svg width="300" height="150" viewBox="0 0 300 150" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <linearGradient id="splashGrad-$variant" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="$($COLORS[$variant])"/>
            <stop offset="100%" stop-color="$(Get-LighterColor $COLORS[$variant])"/>
        </linearGradient>
        
        <filter id="splashGlow-$variant">
            <feGaussianBlur stdDeviation="3" result="blur"/>
            <feComposite in="SourceGraphic" in2="blur" operator="over"/>
        </filter>
    </defs>
    
    <!-- Logo agrandi pour splash -->
    <g transform="translate(25, 25)">
        <path d="M20,70 Q20,20 60,20 L70,20 Q110,20 110,70 L110,85 Q110,120 70,120 L60,120 Q20,120 20,85 Z"
              fill="url(#splashGrad-$variant)" filter="url(#splashGlow-$variant)"/>
        
        <path d="M130,70 Q130,20 170,20 L180,20 Q220,20 220,70 L220,85 Q220,120 180,120 L170,120 Q130,120 130,85 Z"
              fill="url(#splashGrad-$variant)" filter="url(#splashGlow-$variant)"/>
        
        <path d="M240,120 L255,40 L270,70 L285,40 L300,120"
              stroke="url(#splashGrad-$variant)" stroke-width="12" fill="none"
              stroke-linecap="round" stroke-linejoin="round"/>
        
        <circle cx="340" cy="70" r="25" fill="none"
                stroke="url(#splashGrad-$variant)" stroke-width="12"/>
        <circle cx="340" cy="70" r="8" fill="url(#splashGrad-$variant)"/>
    </g>
</svg>
"@
    
    $splashPath = Join-Path $SPLASH_DIR "splash_logo_$variant.svg"
    $splashLogoSvg | Out-File -FilePath $splashPath -Encoding UTF8
    
    # Générer aussi pour iOS et Android
    Copy-Item $splashPath (Join-Path (Join-Path $SPLASH_DIR "ios") "splash_logo.svg") -Force
    Copy-Item $splashPath (Join-Path (Join-Path $SPLASH_DIR "android") "splash_logo.svg") -Force
    
    Write-Host "  ✓ Assets de splash screen générés" -ForegroundColor Green
}

function New-VariantConfig {
    param([string]$variant = "rider")
    
    Write-Host "`n⚙️  Génération de la configuration pour $variant..." -ForegroundColor Yellow
    
    $configContent = @"
// UUMO $variant Theme Configuration
// Generated on $(Get-Date -Format "yyyy-MM-dd")

class UUMO${(Get-Culture).TextInfo.ToTitleCase($variant)}Config {
  static const String variant = '$variant';
  
  // Colors
  static const String primaryColor = '$($COLORS[$variant])';
  static const String primaryColorLight = '$(Get-LighterColor $COLORS[$variant])';
  static const String backgroundColor = '#0F1A2B';
  
  // Assets Paths
  static const String logoPath = 'assets/logos/svg/uumo_$variant.svg';
  static const String logoIconPath = 'assets/logos/svg/uumo_${variant}_icon.svg';
  static const String splashLogoPath = 'assets/splash/splash_logo_$variant.svg';
  
  // App Icons
  static const Map<String, String> appIcons = {
    'ios_1024': 'assets/icons/ios/icon_1024_$variant.png',
    'ios_512': 'assets/icons/ios/icon_512_$variant.png',
    'android_foreground': 'assets/icons/adaptive/${variant}_foreground.svg',
    'android_background': 'assets/icons/adaptive/${variant}_background.svg',
  };
  
  // App Name
  static const String appName = 'UUMO ${(Get-Culture).TextInfo.ToTitleCase($variant)}';
  static const String appDescription = 'Universal Urban Mobility - ${(Get-Culture).TextInfo.ToTitleCase($variant)} Version';
}
"@
    
    $configPath = Join-Path (Join-Path $LOGOS_DIR "variants") "${variant}_config.dart"
    $configContent | Out-File -FilePath $configPath -Encoding UTF8
    
    Write-Host "  ✓ Configuration générée: ${variant}_config.dart" -ForegroundColor Green
}

function New-Readme {
    Write-Host "`n📄 Génération du fichier README..." -ForegroundColor Yellow
    
    $readmeContent = @"
# UUMO Logos Assets

## Structure des dossiers

\`\`\`
assets/
├── logos/
│   ├── svg/                    # Logos vectoriels
│   │   ├── uumo_rider.svg     # Logo principal Rider
│   │   ├── uumo_driver.svg    # Logo Driver
│   │   ├── uumo_eat.svg       # Logo Eat
│   │   └── uumo_merchant.svg  # Logo Merchant
│   ├── png/                   # Logos rasterisés
│   └── variants/              # Configurations par variante
├── icons/
│   ├── ios/                   # Icônes iOS
│   ├── android/               # Icônes Android
│   └── adaptive/              # Icônes adaptatives Android
└── splash/                    # Assets splash screen
    ├── ios/
    ├── android/
    └── splash_logo_*.svg
\`\`\`

## Variantes de couleur

| Variante | Couleur | Code Hex | Utilisation |
|----------|---------|----------|-------------|
| Rider | Orange | #FF6B35 | Application utilisateur |
| Driver | Vert | #34C759 | Application chauffeur |
| Eat | Rouge | #FF3B30 | Application livraison |
| Merchant | Bleu | #007AFF | Application commerçant |

## Utilisation dans Flutter

### 1. Ajouter les assets dans pubspec.yaml

\`\`\`yaml
flutter:
  assets:
    - assets/logos/svg/
    - assets/icons/ios/
    - assets/splash/
\`\`\`

### 2. Utiliser un logo

\`\`\`dart
import 'package:flutter_svg/flutter_svg.dart';

class UUMOLogo extends StatelessWidget {
  final String variant; // 'rider', 'driver', 'eat', 'merchant'
  
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logos/svg/uumo_`${variant}.svg',
      width: 200,
      height: 80,
    );
  }
}
```

### 3. Configuration par variante

Chaque variante a un fichier de configuration dans \`assets/logos/variants/\` :

\`\`\`dart
import 'assets/logos/variants/rider_config.dart';

// Utiliser la configuration
print(UUMORiderConfig.primaryColor); // #FF6B35
print(UUMORiderConfig.appName); // UUMO Rider
\`\`\`

## Génération des assets

Les logos ont été générés avec le script \`Generate-UUMO-Logos.ps1\`.

Pour régénérer les assets :

\`\`\`powershell
.\Generate-UUMO-Logos.ps1
\`\`\`

## Formats disponibles

1. **SVG** : Vectoriel, échelle infinie
2. **PNG** : Raster, tailles multiples
3. **Configuration Dart** : Fichiers de config pour chaque variante

## Tailles d'icônes

- **iOS** : 1024x1024, 512x512, 256x256, 192x192, 144x144, 96x96, 72x72, 48x48
- **Android** : 432x432 (xxxhdpi), 324x324 (xxhdpi), 216x216 (xhdpi), 162x162 (hdpi), 108x108 (mdpi)
- **Favicon** : 32x32
- **Splash** : 300x150 (logo seul)

## Mise à jour

Pour mettre à jour les logos :

1. Modifier le script PowerShell
2. Exécuter \`.\Generate-UUMO-Logos.ps1\`
3. Les fichiers seront régénérés

## Contact

Pour toute modification des logos, contacter l'équipe design.
\`\`\`
"@

    $readmePath = Join-Path $ASSETS_DIR "README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    
    Write-Host "  ✓ README.md généré" -ForegroundColor Green
}

function New-AllVariants {
    Write-Host "`n🌈 Génération de toutes les variantes..." -ForegroundColor Cyan
    
    foreach ($variant in $COLORS.Keys) {
        Write-Host "`n─────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "🎨 Traitement: $variant" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
        
        # Générer le logo principal
        New-SVGLogo -variant $variant
        
        # Générer la version icône
        New-SVGLogo -variant $variant -type "icon"
        
        # Générer les icônes d'application
        New-AppIcons -variant $variant
        
        # Générer les icônes adaptatives
        New-AdaptiveIcons -variant $variant
        
        # Générer le favicon
        New-Favicon -variant $variant
        
        # Générer les assets de splash
        New-SplashAssets -variant $variant
        
        # Générer la configuration
        New-VariantConfig -variant $variant
    }
}

# --------------------------------------------------
# EXÉCUTION PRINCIPALE
# --------------------------------------------------
Write-Host "`n🎯 Que souhaitez-vous générer ?" -ForegroundColor Yellow
Write-Host "1. Toutes les variantes (Rider + Driver + Eat + Merchant)" -ForegroundColor Gray
Write-Host "2. Rider uniquement" -ForegroundColor Gray
Write-Host "3. Driver uniquement" -ForegroundColor Gray
Write-Host "4. Eat uniquement" -ForegroundColor Gray
Write-Host "5. Merchant uniquement" -ForegroundColor Gray

$choice = Read-Host "`nChoix (1-5, par défaut: 1)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

# Créer la structure des dossiers
New-AssetsDirectories

switch ($choice) {
    "1" { 
        # Toutes les variantes
        New-AllVariants
    }
    "2" { 
        # Rider uniquement
        New-SVGLogo -variant "rider"
        New-SVGLogo -variant "rider" -type "icon"
        New-AppIcons -variant "rider"
        New-AdaptiveIcons -variant "rider"
        New-Favicon -variant "rider"
        New-SplashAssets -variant "rider"
        New-VariantConfig -variant "rider"
    }
    "3" { 
        # Driver uniquement
        New-SVGLogo -variant "driver"
        New-SVGLogo -variant "driver" -type "icon"
        New-AppIcons -variant "driver"
        New-AdaptiveIcons -variant "driver"
        New-Favicon -variant "driver"
        New-SplashAssets -variant "driver"
        New-VariantConfig -variant "driver"
    }
    "4" { 
        # Eat uniquement
        New-SVGLogo -variant "eat"
        New-SVGLogo -variant "eat" -type "icon"
        New-AppIcons -variant "eat"
        New-AdaptiveIcons -variant "eat"
        New-Favicon -variant "eat"
        New-SplashAssets -variant "eat"
        New-VariantConfig -variant "eat"
    }
    "5" { 
        # Merchant uniquement
        New-SVGLogo -variant "merchant"
        New-SVGLogo -variant "merchant" -type "icon"
        New-AppIcons -variant "merchant"
        New-AdaptiveIcons -variant "merchant"
        New-Favicon -variant "merchant"
        New-SplashAssets -variant "merchant"
        New-VariantConfig -variant "merchant"
    }
}

# Générer le README
New-Readme

Write-Host "`n" -NoNewline
Write-Host "✅ " -ForegroundColor Green -NoNewline
Write-Host "Génération des logos UUMO terminée !" -ForegroundColor Cyan
Write-Host "📁 Les assets sont disponibles dans: $ASSETS_DIR" -ForegroundColor Yellow
Write-Host "📚 Consultez le README pour l'utilisation: $ASSETS_DIR\README.md" -ForegroundColor Yellow

if (-not (Get-Command inkscape -ErrorAction SilentlyContinue) -and 
    -not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "`n⚠️  REMARQUE IMPORTANTE:" -ForegroundColor Red
    Write-Host "Les fichiers SVG ont été générés, mais pas les PNG." -ForegroundColor Yellow
    Write-Host "Installez Inkscape ou ImageMagick pour générer les PNG." -ForegroundColor Yellow
}