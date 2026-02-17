# Script de Duplication Automatique du Projet Supabase UUMO
# Usage: .\duplicate_supabase_project.ps1 -NewProjectRef "abc123" -NewAnonKey "eyJ..." -Environment "staging"

param(
    [Parameter(Mandatory = $true, HelpMessage = "Le Project Ref du nouveau projet Supabase (ex: abc123def456)")]
    [string]$NewProjectRef,
    
    [Parameter(Mandatory = $true, HelpMessage = "La cle Anon du nouveau projet")]
    [string]$NewAnonKey,
    
    [Parameter(Mandatory = $false, HelpMessage = "Nom de l'environnement (staging, dev, test)")]
    [string]$Environment = "staging",
    
    [Parameter(Mandatory = $false, HelpMessage = "Cle Service Role (optionnel)")]
    [string]$ServiceRoleKey = ""
)

# Couleurs pour l'affichage
$Green = "Green"
$Cyan = "Cyan"
$Yellow = "Yellow"
$Red = "Red"

# Fonction pour afficher les messages
function Write-Step {
    param([string]$Message, [string]$Color = $Cyan)
    Write-Host "`n$Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "OK $Message" -ForegroundColor $Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "ERRF CFA $Message" -ForegroundColor $Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor $Yellow
}

# Debut du script
Clear-Host
Write-Host "=========================================================" -ForegroundColor $Green
Write-Host "   DUPLICATION DU PROJET SUPABASE UUMO                  " -ForegroundColor $Green
Write-Host "=========================================================" -ForegroundColor $Green
Write-Host ""
Write-Info "Environnement: $Environment"
Write-Info "Project Ref: $NewProjectRef"
Write-Host ""

# Verification des prerequis
Write-Step "=== ETAPE 1: Verification des Prerequis ===" $Green

# Verifier que Supabase CLI est installe
try {
    $supabaseVersion = supabase --version 2>$null
    Write-Success "Supabase CLI installe: $supabaseVersion"
}
catch {
    Write-ErrorMsg "Supabase CLI n'est pas installe"
    Write-Info "Installez-le avec: npm install -g supabase"
    exit 1
}

# Verifier la connexion
Write-Step "=== ETAPE 2: Liaison au Nouveau Projet ===" $Green

try {
    Write-Info "Liaison au projet $NewProjectRef..."
    supabase link --project-ref $NewProjectRef
    Write-Success "Projet lie avec succes"
}
catch {
    Write-ErrorMsg "Echec de la liaison au projet"
    Write-Info "Assurez-vous d'etre connecte avec: supabase login"
    exit 1
}

# Application des migrations
Write-Step "=== ETAPE 3: Application des Migrations ===" $Green

$migrationsPath = "c:\000APPS\UUMO\supabase\migrations"

if (Test-Path $migrationsPath) {
    $migrations = Get-ChildItem $migrationsPath -Filter "*.sql" | Sort-Object Name
    Write-Info "Nombre de migrations trouvees: $($migrations.Count)"
    
    Write-Host "`nVoulez-vous appliquer toutes les migrations automatiquement ? (O/N)" -ForegroundColor $Yellow
    $response = Read-Host
    
    if ($response -eq "O" -or $response -eq "o") {
        try {
            Write-Info "Application des migrations..."
            supabase db push
            Write-Success "Migrations appliquees avec succes"
        }
        catch {
            Write-ErrorMsg "Echec de l'application des migrations"
            Write-Info "Vous pouvez les appliquer manuellement via le SQL Editor"
            exit 1
        }
    }
    else {
        Write-Info "Application manuelle requise. Liste des migrations:"
        foreach ($migration in $migrations) {
            Write-Host "   - $($migration.Name)" -ForegroundColor White
        }
    }
}
else {
    Write-ErrorMsg "Dossier migrations introuvable: $migrationsPath"
}

# Mise a jour des fichiers de configuration
Write-Step "=== ETAPE 4: Mise a Jour des Configurations ===" $Green

$newUrl = "https://$NewProjectRef.supabase.co"

# Configuration pour mobile_driver
$mobileDriverEnv = "c:\000APPS\UUMO\mobile_driver\.env.$Environment"
$mobileDriverContent = @"
# Supabase Configuration - Environment: $Environment
SUPABASE_URL=$newUrl
SUPABASE_ANON_KEY=$NewAnonKey

# Stripe Configuration (for token purchases)
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key_here

# SumUp Configuration (Optional)
# SUMUP_AFFILIATE_KEY=your_sumup_affiliate_key_here
"@

try {
    Set-Content -Path $mobileDriverEnv -Value $mobileDriverContent -Encoding UTF8
    Write-Success "Configuration mobile_driver creee: .env.$Environment"
}
catch {
    Write-ErrorMsg "Echec de creation de la configuration mobile_driver"
}

# Configuration pour admin
$adminEnv = "c:\000APPS\UUMO\admin\.env.$Environment"
$adminContent = @"
# Supabase Configuration - Environment: $Environment
VITE_SUPABASE_URL=$newUrl
VITE_SUPABASE_ANON_KEY=$NewAnonKey
"@

try {
    Set-Content -Path $adminEnv -Value $adminContent -Encoding UTF8
    Write-Success "Configuration admin creee: .env.$Environment"
}
catch {
    Write-ErrorMsg "Echec de creation de la configuration admin"
}

# Configuration pour backend (si service role key fournie)
if ($ServiceRoleKey -ne "") {
    $backendEnv = "c:\000APPS\UUMO\backend\.env.$Environment"
    $backendContent = @"
# Supabase Configuration - Environment: $Environment
SUPABASE_URL=$newUrl
SUPABASE_SERVICE_ROLE_KEY=$ServiceRoleKey
"@
    
    try {
        Set-Content -Path $backendEnv -Value $backendContent -Encoding UTF8
        Write-Success "Configuration backend creee: .env.$Environment"
    }
    catch {
        Write-ErrorMsg "Echec de creation de la configuration backend"
    }
}
else {
    Write-Info "Service Role Key non fournie, configuration backend ignoree"
}

# Deploiement des Edge Functions
Write-Step "=== ETAPE 5: Deploiement des Edge Functions ===" $Green

Write-Host "`nVoulez-vous deployer les Edge Functions ? (O/N)" -ForegroundColor $Yellow
$deployFunctions = Read-Host

if ($deployFunctions -eq "O" -or $deployFunctions -eq "o") {
    $functionsPath = "c:\000APPS\UUMO\supabase\functions"
    
    if (Test-Path $functionsPath) {
        $functions = Get-ChildItem $functionsPath -Directory | Where-Object { $_.Name -ne "import_map.json" -and $_.Name -ne "deno.json" }
        
        foreach ($function in $functions) {
            try {
                Write-Info "Deploiement de $($function.Name)..."
                supabase functions deploy $function.Name --project-ref $NewProjectRef
                Write-Success "Fonction $($function.Name) deployee"
            }
            catch {
                Write-ErrorMsg "Echec du deploiement de $($function.Name)"
            }
        }
    }
    else {
        Write-Info "Aucune fonction a deployer"
    }
}
else {
    Write-Info "Deploiement des fonctions ignore"
}

# Generation du rapport
Write-Step "=== RESUME DE LA DUPLICATION ===" $Green

$backendConfig = ""
if ($ServiceRoleKey -ne "") {
    $backendConfig = "- backend\.env.$Environment"
}

$serviceRoleInfo = ""
if ($ServiceRoleKey -ne "") {
    $serviceRoleInfo = "Service Role Key: $ServiceRoleKey"
}

$reportContent = @"
# Rapport de Duplication Supabase
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Environnement: $Environment

## Nouveau Projet
- Project Ref: $NewProjectRef
- URL: $newUrl

## Fichiers de Configuration Crees
- mobile_driver\.env.$Environment
- admin\.env.$Environment
$backendConfig

## Prochaines Etapes Manuelles

### 1. Activer les Extensions PostgreSQL
Allez dans Database > Extensions et activez:
- postgis (geolocalisation)
- pg_net (webhooks)
- uuid-ossp (UUID)

### 2. Configurer l'Authentification
Allez dans Authentication > Settings:
- Email Confirmation: A configurer selon vos besoins
- Site URL: A configurer
- Redirect URLs: A ajouter

### 3. Configurer les Secrets des Edge Functions
Allez dans Edge Functions > Secrets et ajoutez:
- STRIPE_SECRET_KEY=...
- STRIPE_WEBHOOK_SECRET=...

### 4. Configurer les Webhooks Stripe (si necessaire)
URL du webhook: $newUrl/functions/v1/stripe-webhook
Evenements: payment_intent.succeeded, payment_intent.payment_failed

### 5. Tester la Connexion
- Lancez l'application mobile avec .env.$Environment
- Verifiez que la connexion fonctionne
- Creez un utilisateur de test

### 6. Verifications SQL a Executer
Voir le guide GUIDE_DUPLICATION_SUPABASE.md pour les requetes SQL de verification.

## Credentials (A Sauvegarder dans un Gestionnaire de Mots de Passe)

Project Ref: $NewProjectRef
URL: $newUrl
Anon Key: $NewAnonKey
$serviceRoleInfo

---
Genere automatiquement par duplicate_supabase_project.ps1
"@

$reportPath = "c:\000APPS\UUMO\DUPLICATION_REPORT_$Environment`_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8

Write-Host ""
Write-Host "=========================================================" -ForegroundColor $Green
Write-Host "          DUPLICATION TERMINEE AVEC SUCCES              " -ForegroundColor $Green
Write-Host "=========================================================" -ForegroundColor $Green
Write-Host ""
Write-Success "Rapport genere: $reportPath"
Write-Host ""
Write-Info "Consultez le fichier GUIDE_DUPLICATION_SUPABASE.md pour plus de details"
Write-Host ""

# Ouvrir le rapport
$openReport = Read-Host "Voulez-vous ouvrir le rapport maintenant ? (O/N)"
if ($openReport -eq "O" -or $openReport -eq "o") {
    Start-Process $reportPath
}
