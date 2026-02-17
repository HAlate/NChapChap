# Script PowerShell pour créer un driver via l'API Supabase Auth
# Remplacez les valeurs ci-dessous

$SUPABASE_URL = "https://VOTRE_PROJECT_REF.supabase.co"
$SUPABASE_ANON_KEY = "VOTRE_ANON_KEY"

# Créer le driver Moto (111111)
Write-Host "Création du driver Moto via API..." -ForegroundColor Cyan

$body = @{
    email    = "driver_111111@uumo.app"
    password = "tototo"
    data     = @{
        phone     = "111111"
        full_name = "Driver Moto"
        user_type = "driver"
    }
} | ConvertTo-Json

$headers = @{
    "apikey"       = $SUPABASE_ANON_KEY
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/signup" `
        -Method Post `
        -Headers $headers `
        -Body $body
    
    Write-Host "`n✅ Driver créé avec succès!" -ForegroundColor Green
    Write-Host "ID: $($response.user.id)" -ForegroundColor Yellow
    
    Write-Host "`nÉTAPES SUIVANTES:" -ForegroundColor Cyan
    Write-Host "1. Allez dans Supabase Dashboard > Authentication > Users"
    Write-Host "2. Trouvez driver_111111@uumo.app"
    Write-Host "3. Cliquez dessus et activez 'Email Confirmed'"
    Write-Host "4. Exécutez le SQL ci-dessous dans SQL Editor:`n"
    
    Write-Host @"
INSERT INTO driver_profiles (
  id, vehicle_type, vehicle_brand, vehicle_model, vehicle_color,
  vehicle_plate, license_number, rating, total_trips, is_available, token_balance
)
SELECT 
  id, 'moto'::vehicle_type, 'Yamaha', 'MT-07', 'Noir',
  'AB-123-CD', 'MOTO123456', 4.8, 50, true, 100
FROM public.users
WHERE email = 'driver_111111@uumo.app';
"@ -ForegroundColor Yellow
    
}
catch {
    Write-Host "`n❌ Erreur lors de la création:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
