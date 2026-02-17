# Script d'installation des dépendances WebRTC
# Exécuter ce script après avoir mis à jour les fichiers

Write-Host "🚀 Installation des dépendances WebRTC pour UUMO" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Fonction pour installer les dépendances d'une app
function Install-AppDependencies {
    param(
        [string]$AppPath,
        [string]$AppName
    )
    
    Write-Host "📱 Installation pour $AppName..." -ForegroundColor Yellow
    
    if (Test-Path $AppPath) {
        Push-Location $AppPath
        
        Write-Host "  ⏳ flutter pub get..." -ForegroundColor Gray
        flutter pub get
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ $AppName - Dépendances installées" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ $AppName - Erreur d'installation" -ForegroundColor Red
        }
        
        Pop-Location
    }
    else {
        Write-Host "  ⚠️  Chemin non trouvé: $AppPath" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Installer pour mobile_rider
Install-AppDependencies -AppPath ".\mobile_rider" -AppName "Mobile Rider"

# Installer pour mobile_driver
Install-AppDependencies -AppPath ".\mobile_driver" -AppName "Mobile Driver"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "✨ Installation terminée!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Prochaines étapes:" -ForegroundColor Cyan
Write-Host "  1. Exécuter le script SQL dans Supabase:" -ForegroundColor White
Write-Host "     create_call_messaging_tables.sql" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Configurer les permissions dans AndroidManifest.xml:" -ForegroundColor White
Write-Host "     <uses-permission android:name='android.permission.RECORD_AUDIO' />" -ForegroundColor Gray
Write-Host "     <uses-permission android:name='android.permission.INTERNET' />" -ForegroundColor Gray
Write-Host "     <uses-permission android:name='android.permission.MODIFY_AUDIO_SETTINGS' />" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Pour iOS, ajouter dans Info.plist:" -ForegroundColor White
Write-Host "     <key>NSMicrophoneUsageDescription</key>" -ForegroundColor Gray
Write-Host "     <string>Nous avons besoin d'accéder au microphone pour les appels</string>" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Tester les appels entre rider et driver" -ForegroundColor White
Write-Host ""
