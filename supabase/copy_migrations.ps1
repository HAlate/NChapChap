# Script simple pour copier les migrations a appliquer manuellement

$outputDir = ".\migrations_to_apply"

# Creer le dossier si necessaire
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
    Write-Host "Dossier cree: $outputDir"
}

# Copier les 3 migrations
$migrations = @(
    "20260108000001_create_no_show_system.sql",
    "20260108000002_change_token_deduction_to_trip_start.sql",
    "20260108000003_fix_users_insert_policy_for_signup.sql"
)

Write-Host ""
Write-Host "Copie des migrations..." -ForegroundColor Yellow

foreach ($file in $migrations) {
    $source = ".\migrations\$file"
    $dest = "$outputDir\$file"
    
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $dest -Force
        Write-Host "  OK - $file" -ForegroundColor Green
    }
    else {
        Write-Host "  ERRF CFA - Fichier introuvable: $file" -ForegroundColor Red
    }
}

# Creer README
$readme = @"
MIGRATIONS A APPLIQUER MANUELLEMENT
====================================

Ces 3 migrations doivent etre appliquees via le Dashboard Supabase

ORDRE D'EXECUTION
-----------------

1. 20260108000001_create_no_show_system.sql
   - Systeme No Show (reports, penalties)

2. 20260108000002_change_token_deduction_to_trip_start.sql
   - Protection contre No Show passagers

3. 20260108000003_fix_users_insert_policy_for_signup.sql
   - CRITIQUE: Corrige erreur creation utilisateur

INSTRUCTIONS
------------

1. Ouvrir https://supabase.com/dashboard
2. Selectionner projet UUMO
3. Menu: SQL Editor
4. Pour chaque fichier (dans l'ordre):
   - Ouvrir le fichier avec notepad
   - Copier TOUT le contenu
   - Coller dans SQL Editor
   - Cliquer RUN ou appuyer F5
   - Verifier: pas d'erreurs rouges

TEST
----

Apres avoir applique les 3 migrations:
- Tester inscription dans app Driver
- Tester inscription dans app Rider
- Devrait fonctionner sans erreur RLS!

AIDE
----

Si erreur SQL, consulter:
- GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md (dossier parent)
- Ou partager l'erreur complete
"@

Set-Content -Path "$outputDir\README.txt" -Value $readme

Write-Host ""
Write-Host "TERMINE!" -ForegroundColor Green
Write-Host ""
Write-Host "Fichiers prepares dans: $outputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaine etape:" -ForegroundColor Yellow
Write-Host "  1. Ouvrir Supabase Dashboard > SQL Editor"
Write-Host "  2. Appliquer les 3 fichiers SQL (dans l'ordre)"
Write-Host "  3. Tester l'inscription dans les apps"
Write-Host ""
Write-Host "Voir README.txt dans le dossier pour details." -ForegroundColor Gray
Write-Host ""

# Ouvrir le dossier dans l'explorateur
explorer $outputDir
