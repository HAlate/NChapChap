# Script PowerShell pour remplacer FCFA par EUR dans tous les fichiers Dart

$files = Get-ChildItem -Path "C:\000APPS\UUMO" -Include "*.dart" -Recurse -File

$count = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Remplacer toutes les variantes de FCFA par EUR
    $content = $content -replace ' FCFA', 'EUR'
    $content = $content -replace 'FCFA', 'EUR'
    $content = $content -replace 'F CFA', 'EUR'
    
    # Sauvegarder si modifie
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "Modifie: $($file.Name)" -ForegroundColor Green
        $count++
    }
}

Write-Host "`nTotal: $count fichiers modifies" -ForegroundColor Cyan
