# Script pour extraire et afficher les migrations à appliquer manuellement

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Extraction Migrations pour Dashboard" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$migrations = @(
    @{
        File        = "20260108000001_create_no_show_system.sql"
        Name        = "No Show System"
        Description = "Tables no_show_reports, user_penalties, colonnes tracking"
    },
    @{
        File        = "20260108000002_change_token_deduction_to_trip_start.sql"
        Name        = "Token Deduction au démarrage"
        Description = "Protection contre No Show passagers"
    },
    @{
        File        = "20260108000003_fix_users_insert_policy_for_signup.sql"
        Name        = "Fix User Creation (IMPORTANT!)"
        Description = "Corrige l'erreur RLS lors de l'inscription"
    }
)

$outputDir = ".\migrations_to_apply"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "📁 Extraction des migrations dans: $outputDir" -ForegroundColor Yellow
Write-Host ""

foreach ($migration in $migrations) {
    $sourcePath = ".\migrations\$($migration.File)"
    $destPath = "$outputDir\$($migration.File)"
    
    Write-Host "📄 $($migration.Name)" -ForegroundColor Cyan
    Write-Host "   Fichier: $($migration.File)" -ForegroundColor Gray
    Write-Host "   Description: $($migration.Description)" -ForegroundColor Gray
    
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        
        # Afficher les premières lignes
        $content = Get-Content -Path $sourcePath -TotalCount 10
        Write-Host "   Aperçu:" -ForegroundColor Yellow
        $content | ForEach-Object {
            if ($_ -match "^\s*--") {
                Write-Host "   $_" -ForegroundColor DarkGray
            }
            else {
                Write-Host "   $_" -ForegroundColor White
            }
        }
        Write-Host "   ✅ Copié dans $destPath" -ForegroundColor Green
    }
    else {
        Write-Host "   ❌ Fichier introuvable: $sourcePath" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Ouvrir Supabase Dashboard → SQL Editor" -ForegroundColor White
Write-Host "2. Pour chaque fichier dans $outputDir:" -ForegroundColor White
Write-Host "   - Ouvrir le fichier avec un éditeur" -ForegroundColor White
Write-Host "   - Copier TOUT le contenu" -ForegroundColor White
Write-Host "   - Coller dans SQL Editor" -ForegroundColor White
Write-Host "   - Cliquer 'Run' (F5)" -ForegroundColor White
Write-Host ""
Write-Host "3. Vérifier que tout s'est bien passé:" -ForegroundColor White
Write-Host "   - Pas d'erreurs rouges" -ForegroundColor White
Write-Host "   - Message de succès" -ForegroundColor White
Write-Host ""
Write-Host "4. Tester l'inscription dans l'app!" -ForegroundColor White
Write-Host ""

# Créer un fichier README dans le dossier
$readmeLines = @(
    "# Migrations a appliquer manuellement",
    "",
    "## Ordre d'execution",
    "",
    "Appliquer ces migrations dans l'ordre suivant via Supabase Dashboard > SQL Editor:",
    "",
    "### 1. 20260108000001_create_no_show_system.sql",
    "Systeme No Show",
    "- Cree les tables pour gerer les No Show",
    "- Ajoute les colonnes de tracking",
    "- Configure les penalites",
    "",
    "### 2. 20260108000002_change_token_deduction_to_trip_start.sql",
    "Deduction jetons au demarrage",
    "- Change le moment de deduction du jeton",
    "- Protege contre les No Show passagers",
    "- Nouveau trigger sur trips.status",
    "",
    "### 3. 20260108000003_fix_users_insert_policy_for_signup.sql",
    "Fix creation utilisateur (CRITIQUE)",
    "- Corrige l'erreur RLS lors de l'inscription",
    "- Ajoute trigger automatique pour creer users",
    "- Simplifie le code d'inscription",
    "",
    "## Comment appliquer",
    "",
    "1. Ouvrir Supabase Dashboard",
    "2. Selectionner projet UUMO",
    "3. Menu: SQL Editor",
    "4. Pour chaque fichier:",
    "   Ouvrir le fichier",
    "   Copier TOUT le contenu",
    "   Coller dans SQL Editor",
    "   Cliquer Run ou F5",
    "5. Verifier succes (pas d'erreurs rouges)",
    "",
    "## Test apres application",
    "",
    "Tester l'inscription:",
    "- App Driver: Creer nouveau compte",
    "- App Rider: Creer nouveau compte",
    "- Devrait fonctionner sans erreur RLS!",
    "",
    "## Support",
    "",
    "Si erreur SQL:",
    "- Verifier que les migrations precedentes sont bien appliquees",
    "- Consulter GUIDE_APPLICATION_MANUELLE_MIGRATIONS.md",
    "- Partager le message d`'erreur complet"
)

Set-Content -Path "$outputDir\README.md" -Value ($readmeLines -join "`n")

Write-Host "📝 README créé: $outputDir\README.md" -ForegroundColor Green
Write-Host ""
Write-Host "Pour voir les fichiers:" -ForegroundColor Yellow
Write-Host "  explorer $outputDir" -ForegroundColor White
Write-Host ""
