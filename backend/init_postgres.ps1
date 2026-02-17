# Vérifie l'installation de PostgreSQL et crée la base + schéma

# Vérifier si psql est disponible
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "psql n'est pas disponible. Veuillez installer PostgreSQL et redémarrer le terminal."
    exit 1
}

# Créer la base de données si elle n'existe pas
echo "CREATE DATABASE urbanmobility;" | psql -U postgres

# Appliquer le schéma
psql -U postgres -d urbanmobility -f schema.sql

Write-Host "Base de données et schéma prêts !"