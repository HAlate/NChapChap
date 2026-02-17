# Script PowerShell pour remplacer toutes les references a EUR/Euro/symbole-euro par F CFA
# dans tous les fichiers du projet CHAPCHAP
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Remplacement EUR/Euro/symbole-euro -> F CFA" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$baseDir = "C:\000APPS\CHAPCHAP"
$extensions = @("*.dart", "*.ts", "*.sql", "*.md", "*.ps1", "*.sh")

# Pattern pour le symbole euro (Unicode)
$euroSymbol = [char]0x20AC

$replacements = @(
    @{ Old = $euroSymbol; New = 'F' }
    @{ Old = ' EUR'; New = ' F CFA' }
    @{ Old = 'EUR '; New = 'F CFA ' }
    @{ Old = "EUR$euroSymbol"; New = 'F CFA' }
    @{ Old = 'EUR"'; New = 'F CFA"' }
    @{ Old = "EUR'"; New = "F CFA'" }
    @{ Old = 'EUR,'; New = 'F CFA,' }
    @{ Old = 'EUR)'; New = 'F CFA)' }
    @{ Old = 'EUR|'; New = 'F CFA|' }
    @{ Old = 'Euro'; New = 'F CFA' }
    @{ Old = 'euro'; New = 'fcfa' }
    @{ Old = '.eur'; New = '.fcfa' }
    @{ Old = "'eur'"; New = "'fcfa'" }
    @{ Old = '"eur"'; New = '"fcfa"' }
    @{ Old = "value: 'eur'"; New = "value: 'fcfa'" }
    @{ Old = 'Icons.euro'; New = 'Icons.attach_money' }
)

$filesModified = 0
$totalReplacements = 0

foreach ($ext in $extensions) {
    $files = Get-ChildItem -Path $baseDir -Filter $ext -Recurse -File | 
    Where-Object { 
        $_.FullName -notmatch '\\node_modules\\' -and 
        $_.FullName -notmatch '\\\.dart_tool\\' -and
        $_.FullName -notmatch '\\build\\' -and
        $_.FullName -notmatch '\\\.git\\' -and
        $_.Name -ne 'replace_euro_with_fcfa.ps1' -and
        $_.Name -ne 'replace_fcfa_with_euro.ps1'
    }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $originalContent = $content
            $fileReplacements = 0
            
            foreach ($replacement in $replacements) {
                $oldValue = $replacement.Old
                $newValue = $replacement.New
                
                # Compter et remplacer
                $before = $content
                $content = $content.Replace($oldValue, $newValue)
                if ($content -ne $before) {
                    $count = ([regex]::Matches($before, [regex]::Escape($oldValue))).Count
                    $fileReplacements += $count
                }
            }
            
            # Si des modifications ont ete faites, sauvegarder le fichier
            if ($content -ne $originalContent) {
                Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
                $filesModified++
                $totalReplacements += $fileReplacements
                $relativePath = $file.FullName.Replace($baseDir, "").TrimStart('\')
                Write-Host "[OK] $relativePath : $fileReplacements remplacements" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[ERREUR] $($file.Name) : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Termine!" -ForegroundColor Green
Write-Host "Fichiers modifies: $filesModified" -ForegroundColor Yellow
Write-Host "Total remplacements: $totalReplacements" -ForegroundColor Yellow
Write-Host "`nN'oubliez pas de:" -ForegroundColor Yellow
Write-Host "1. Redemarrer les applications Flutter" -ForegroundColor White
Write-Host "2. Verifier les fichiers de migration SQL" -ForegroundColor White
Write-Host "3. Mettre a jour les configurations Stripe/SumUp si necessaire" -ForegroundColor White
