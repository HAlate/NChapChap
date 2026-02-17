# Script pour synchroniser les migrations Supabase
# Marque les migrations existantes comme appliquées et pousse les nouvelles

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Synchronisation Migrations Supabase" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Liste des migrations existantes à marquer comme appliquées
$existingMigrations = @(
    "20251129151241",
    "20251129151318",
    "20251129151348",
    "20251129151418",
    "20251129151459",
    "20251129153356",
    "20251129153421",
    "20251129153457",
    "20251129153535",
    "20251129153609",
    "20251129153635",
    "20251129153711",
    "20251130014703",
    "20251130061524",
    "20251130064354",
    "20251201000001",
    "20251214",
    "20251215",
    "20251216000001",
    "20251216000002",
    "20251216000003",
    "20260107000001",
    "20260107000002",
    "20260107000003",
    "20260107000004",
    "20260107000005",
    "20260107000006",
    "20260107000007"
)

# Nouvelles migrations à appliquer
$newMigrations = @(
    "20260108000001",
    "20260108000002",
    "20260108000003"
)

Write-Host "Étape 1: Marquage des migrations existantes comme 'applied'" -ForegroundColor Yellow
Write-Host "($($existingMigrations.Count) migrations)" -ForegroundColor Gray
Write-Host ""

$migrationsString = $existingMigrations -join " "
$command = "supabase migration repair --status applied $migrationsString"

Write-Host "Exécution: " -NoNewline
Write-Host $command -ForegroundColor Gray
Write-Host ""

try {
    Invoke-Expression $command
    Write-Host "✅ Migrations existantes marquées comme appliquées" -ForegroundColor Green
}
catch {
    Write-Host "❌ Erreur lors du marquage des migrations: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Étape 2: Vérification de l'état des migrations" -ForegroundColor Yellow
Write-Host ""

try {
    supabase migration list
}
catch {
    Write-Host "⚠️ Erreur lors de la liste des migrations: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Étape 3: Application des nouvelles migrations" -ForegroundColor Yellow
Write-Host "($($newMigrations.Count) migrations: No Show, Token Deduction, User Creation Fix)" -ForegroundColor Gray
Write-Host ""

try {
    supabase db push
    Write-Host "✅ Nouvelles migrations appliquées avec succès!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Erreur lors de l'application des migrations: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Étape 4: Vérification finale" -ForegroundColor Yellow
Write-Host ""

try {
    supabase migration list
    Write-Host ""
    Write-Host "✅ SYNCHRONISATION TERMINÉE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Les nouvelles migrations incluent:" -ForegroundColor Cyan
    Write-Host "  - Système No Show (reports, penalties)" -ForegroundColor White
    Write-Host "  - Déduction jetons au démarrage (protection No Show)" -ForegroundColor White
    Write-Host "  - Correction création utilisateur (RLS + trigger auto)" -ForegroundColor White
}
catch {
    Write-Host "⚠️ Erreur lors de la vérification finale: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Migration terminée! Testez l'inscription." -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
