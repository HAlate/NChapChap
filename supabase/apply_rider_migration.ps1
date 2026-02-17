# Script pour appliquer la migration 20251216_add_rider_info_to_trip_offers_view.sql
# Ce script met à jour la vue trip_offers_with_driver pour inclure les informations du rider

Write-Host "Application de la migration: add_rider_info_to_trip_offers_view" -ForegroundColor Cyan

# Charger les variables d'environnement depuis .env s'il existe
$envFile = "..\\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$') {
            $key = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
            Write-Host "Loaded: $key" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Fichier .env introuvable. Utilisation des variables d'environnement système." -ForegroundColor Yellow
}

# Récupérer l'URL de la base de données depuis les variables d'environnement
$dbUrl = $env:SUPABASE_DB_URL
if (-not $dbUrl) {
    Write-Host "ERREUR: SUPABASE_DB_URL n'est pas défini dans les variables d'environnement" -ForegroundColor Red
    Write-Host "Veuillez définir SUPABASE_DB_URL dans votre fichier .env ou variables d'environnement système" -ForegroundColor Yellow
    exit 1
}

Write-Host "Connexion à la base de données..." -ForegroundColor Cyan

# Chemin du fichier de migration
$migrationFile = ".\migrations\20251216_add_rider_info_to_trip_offers_view.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "ERREUR: Fichier de migration introuvable: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Application de la migration depuis: $migrationFile" -ForegroundColor Cyan

# Exécuter la migration avec psql
try {
    $content = Get-Content $migrationFile -Raw
    $content | psql $dbUrl
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nMigration appliquée avec succès!" -ForegroundColor Green
        Write-Host "La vue trip_offers_with_driver inclut maintenant les informations du rider (passager)" -ForegroundColor Green
    }
    else {
        Write-Host "`nERRF CFA lors de l'application de la migration (code: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`nERREUR: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nTerminé!" -ForegroundColor Cyan
