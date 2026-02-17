#!/bin/bash

# Script pour créer un driver de test via l'API Supabase Auth
# Cela crée correctement tous les schémas nécessaires (auth.users, auth.identities, etc.)

# Configuration - REMPLACEZ avec vos valeurs
SUPABASE_URL="https://VOTRE_PROJECT_REF.supabase.co"
SUPABASE_ANON_KEY="VOTRE_ANON_KEY"

# Créer le driver Moto (111111)
echo "Création du driver Moto..."
curl -X POST "${SUPABASE_URL}/auth/v1/signup" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "driver_111111@uumo.app",
    "password": "tototo",
    "data": {
      "phone": "111111",
      "full_name": "Driver Moto",
      "user_type": "driver"
    }
  }'

echo "\n\nAttente 2 secondes...\n"
sleep 2

# Vous devez maintenant:
# 1. Confirmer l'email manuellement dans Supabase Dashboard > Authentication > Users
#    (cliquez sur l'utilisateur et activez "Email Confirmed")
# 2. Créer le profil driver en exécutant ce SQL:

echo "Après avoir confirmé l'email dans Supabase Dashboard, exécutez ce SQL:"
echo ""
echo "-- Créer le profil driver pour 111111"
echo "INSERT INTO driver_profiles ("
echo "  id,"
echo "  vehicle_type,"
echo "  vehicle_brand,"
echo "  vehicle_model,"
echo "  vehicle_color,"
echo "  vehicle_plate,"
echo "  license_number,"
echo "  rating,"
echo "  total_trips,"
echo "  is_available,"
echo "  token_balance"
echo ")"
echo "SELECT "
echo "  id,"
echo "  'moto'::vehicle_type,"
echo "  'Yamaha',"
echo "  'MT-07',"
echo "  'Noir',"
echo "  'AB-123-CD',"
echo "  'MOTO123456',"
echo "  4.8,"
echo "  50,"
echo "  true,"
echo "  100"
echo "FROM public.users"
echo "WHERE email = 'driver_111111@uumo.app';"
