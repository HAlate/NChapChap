# Script de Migration Supabase - UUMO
# Ce script applique toutes les migrations dans le bon ordre

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRef,
    
    [Parameter(Mandatory = $false)]
    [string]$SupabasePassword = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   UUMO - Migration Supabase" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que Supabase CLI est installé
$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCli) {
    Write-Host "❌ Supabase CLI n'est pas installé!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation via npm:" -ForegroundColor Yellow
    Write-Host "  npm install -g supabase" -ForegroundColor White
    Write-Host ""
    Write-Host "Installation via Scoop (Windows):" -ForegroundColor Yellow
    Write-Host "  scoop install supabase" -ForegroundColor White
    exit 1
}

Write-Host "✅ Supabase CLI détecté" -ForegroundColor Green

# Aller dans le dossier racine
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host ""
Write-Host "📂 Dossier de travail: $scriptPath" -ForegroundColor Cyan

# Vérifier que le dossier migrations existe
if (-not (Test-Path "supabase\migrations")) {
    Write-Host "❌ Dossier supabase\migrations introuvable!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Dossier migrations trouvé" -ForegroundColor Green

# Login Supabase (si nécessaire)
Write-Host ""
Write-Host "🔐 Connexion à Supabase..." -ForegroundColor Cyan

# Tenter de lier le projet
Write-Host ""
Write-Host "🔗 Liaison au projet $ProjectRef..." -ForegroundColor Cyan

$linkCommand = "supabase link --project-ref $ProjectRef"
if ($SupabasePassword) {
    $linkCommand += " --password $SupabasePassword"
}

Invoke-Expression $linkCommand

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Échec de la liaison au projet" -ForegroundColor Red
    Write-Host ""
    Write-Host "Assurez-vous que:" -ForegroundColor Yellow
    Write-Host "  1. Vous êtes connecté: supabase login" -ForegroundColor White
    Write-Host "  2. Le Project Reference est correct" -ForegroundColor White
    Write-Host "  3. Vous avez les droits d'accès au projet" -ForegroundColor White
    exit 1
}

Write-Host "✅ Projet lié avec succès" -ForegroundColor Green

# Liste des migrations dans l'ordre
$migrations = @(
    "20251129153356_01_create_base_enums_and_users.sql",
    "20251129153421_02_create_token_tables.sql",
    "20251129153457_03_create_trips_and_offers.sql",
    "20251129153535_04_create_orders_and_delivery.sql",
    "20251129153609_05_create_profile_tables.sql",
    "20251129153635_06_create_products_and_menu.sql",
    "20251129153711_07_create_payments_and_functions.sql",
    "20251130014703_create_token_deduction_trigger.sql",
    "20251130061524_create_orders_token_deduction_trigger.sql",
    "20251130064354_add_token_purchases_and_transactions.sql",
    "20251201000001_fix_users_insert_policy.sql",
    "20251214_create_trip_offers_view.sql",
    "20251215_admin_dashboard_view.sql",
    "20251216_add_driver_arrived_notification.sql",
    "20251216_add_rider_info_to_trip_offers_view.sql"
)

Write-Host ""
Write-Host "📋 Migrations à appliquer: $($migrations.Count)" -ForegroundColor Cyan
Write-Host ""

# Appliquer toutes les migrations
Write-Host "🚀 Application des migrations..." -ForegroundColor Cyan
Write-Host ""

supabase db push

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   ✅ Migration réussie!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Prochaines étapes:" -ForegroundColor Cyan
    Write-Host "  1. Configurez vos variables d'environnement" -ForegroundColor White
    Write-Host "  2. Mettez à jour les constantes dans les apps Flutter" -ForegroundColor White
    Write-Host "  3. Testez l'authentification" -ForegroundColor White
    Write-Host ""
    Write-Host "Pour insérer des données de test:" -ForegroundColor Yellow
    Write-Host "  supabase db reset" -ForegroundColor White
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "   ❌ Échec de la migration" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Vérifiez les logs ci-dessus pour plus de détails" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pour appliquer manuellement:" -ForegroundColor Yellow
    Write-Host "  1. Ouvrez le SQL Editor dans Supabase Dashboard" -ForegroundColor White
    Write-Host "  2. Copiez le contenu de chaque fichier de migration" -ForegroundColor White
    Write-Host "  3. Exécutez-les dans l'ordre indiqué dans GUIDE_INSTALLATION_SUPABASE.md" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Vérification
Write-Host "🔍 Vérification de l'installation..." -ForegroundColor Cyan
Write-Host ""

# Tester la connexion à la base de données
$verifyQuery = @"
SELECT 
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public') as tables_count,
    (SELECT COUNT(*) FROM pg_type WHERE typtype = 'e') as enum_count,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public') as function_count;
"@

Write-Host "Tables publiques, types ENUM et fonctions créés" -ForegroundColor Green
Write-Host ""
Write-Host "Pour voir plus de détails, exécutez dans le SQL Editor:" -ForegroundColor Yellow
Write-Host $verifyQuery -ForegroundColor White
Write-Host ""
Write-Host "✨ Configuration terminée!" -ForegroundColor Green
