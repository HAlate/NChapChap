# ============================================
# UUMO ASSETS VERIFICATION SCRIPT
# ============================================

Write-Host "🔍 Vérification des Assets UUMO" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$ASSETS_DIR = "assets"
$LOGOS_DIR = Join-Path $ASSETS_DIR "logos"
$ICONS_DIR = Join-Path $ASSETS_DIR "icons"
$SPLASH_DIR = Join-Path $ASSETS_DIR "splash"

$requiredFiles = @{
    "Logos SVG"      = @(
        "$LOGOS_DIR\svg\uumo_rider.svg",
        "$LOGOS_DIR\svg\uumo_driver.svg",
        "$LOGOS_DIR\svg\uumo_eat.svg",
        "$LOGOS_DIR\svg\uumo_merchant.svg"
    )
    
    "Configurations" = @(
        "$LOGOS_DIR\variants\rider_config.dart",
        "$LOGOS_DIR\variants\driver_config.dart",
        "$LOGOS_DIR\variants\eat_config.dart",
        "$LOGOS_DIR\variants\merchant_config.dart"
    )
    
    "Splash Assets"  = @(
        "$SPLASH_DIR\splash_logo_rider.svg",
        "$SPLASH_DIR\ios\splash_logo.svg",
        "$SPLASH_DIR\android\splash_logo.svg"
    )
}

$missingFiles = @()
$presentFiles = 0
$totalFiles = 0

Write-Host "`n📁 Vérification de la structure..." -ForegroundColor Yellow

foreach ($category in $requiredFiles.Keys) {
    Write-Host "`n$category" -ForegroundColor Gray
    Write-Host ("─" * $category.Length) -ForegroundColor DarkGray
    
    foreach ($file in $requiredFiles[$category]) {
        $totalFiles++
        if (Test-Path $file) {
            Write-Host "  ✓ $(Split-Path $file -Leaf)" -ForegroundColor Green
            $presentFiles++
        }
        else {
            Write-Host "  ✗ $(Split-Path $file -Leaf)" -ForegroundColor Red
            $missingFiles += $file
        }
    }
}

# Vérifier les tailles des icônes PNG
Write-Host "`n📱 Vérification des icônes PNG..." -ForegroundColor Yellow

$iosIconDir = Join-Path $ICONS_DIR "ios"
if (Test-Path $iosIconDir) {
    $pngFiles = Get-ChildItem $iosIconDir -Filter *.png
    if ($pngFiles.Count -gt 0) {
        Write-Host "  ✓ $($pngFiles.Count) fichiers PNG trouvés" -ForegroundColor Green
        
        foreach ($file in $pngFiles) {
            $dimensions = & magick identify -format "%wx%h" $file.FullName 2>$null
            Write-Host "    → $($file.Name): $dimensions" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  ⚠️  Aucun fichier PNG trouvé" -ForegroundColor Yellow
    }
}

# Résumé
Write-Host "`n" -NoNewline
Write-Host "📊 " -ForegroundColor Cyan -NoNewline
Write-Host "RÉSUMÉ:" -ForegroundColor White

$percentage = [math]::Round(($presentFiles / $totalFiles) * 100)
Write-Host "  Fichiers présents: $presentFiles/$totalFiles ($percentage%)" -ForegroundColor $(if ($percentage -ge 90) { "Green" } elseif ($percentage -ge 70) { "Yellow" } else { "Red" })

if ($missingFiles.Count -gt 0) {
    Write-Host "`n❌ Fichiers manquants:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Gray
    }
    
    Write-Host "`n🔄 Pour générer les fichiers manquants:" -ForegroundColor Yellow
    Write-Host "   .\Generate-UUMO-Logos.ps1" -ForegroundColor Gray
}
else {
    Write-Host "`n✅ Tous les assets sont présents!" -ForegroundColor Green
}

# Vérifier la configuration Flutter
Write-Host "`n⚙️  Vérification de la configuration Flutter..." -ForegroundColor Yellow

if (Test-Path "pubspec.yaml") {
    $pubspecContent = Get-Content -Path "pubspec.yaml" -Raw
    if ($pubspecContent -match "assets:") {
        Write-Host "  ✓ Section assets trouvée dans pubspec.yaml" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠️  Section assets manquante dans pubspec.yaml" -ForegroundColor Yellow
        Write-Host "  Exécutez .\Configure-Flutter-Assets.ps1 pour configurer" -ForegroundColor Gray
    }
}
else {
    Write-Host "  ⚠️  pubspec.yaml non trouvé" -ForegroundColor Yellow
}

Write-Host "`n✅ Vérification terminée" -ForegroundColor Green