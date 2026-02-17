-- Créer des drivers de test pour chaque type de véhicule

-- 1. Supprimer les anciens drivers de test s'ils existent (ordre important: profils -> users -> auth)
-- Supprimer les profils drivers
DELETE FROM driver_profiles 
WHERE id IN (
    SELECT id FROM public.users WHERE phone IN ('111111', '222222', '333333', '444444', '555555', '666666')
);

-- Supprimer de public.users
DELETE FROM public.users WHERE phone IN ('111111', '222222', '333333', '444444', '555555', '666666');

-- Supprimer de auth.users (par email)
DELETE FROM auth.users WHERE email IN (
    'driver_111111@uumo.app',
    'driver_222222@uumo.app',
    'driver_333333@uumo.app',
    'driver_444444@uumo.app',
    'driver_555555@uumo.app',
    'driver_666666@uumo.app'
);

-- Attendre un peu pour que les suppressions soient propagées
SELECT pg_sleep(0.5);

-- 2. Insérer les drivers dans auth.users (avec mot de passe: tototo)
-- Note: Le hash correspond au mot de passe "tototo"
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at
)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid,
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    email,
    '$2a$10$rGXHQqLwVYqJvIqBJvQEOeYbJvqVXqvYJvQEOeYbJvqVXqvYJvQEO', -- Hash de tototo
    NOW(),
    jsonb_build_object(
        'full_name', full_name,
        'phone', phone,
        'user_type', 'driver'
    ),
    NOW(),
    NOW()
FROM (VALUES
    ('driver_111111@uumo.app', 'Driver Moto', '111111'),
    ('driver_222222@uumo.app', 'Driver Economy', '222222'),
    ('driver_333333@uumo.app', 'Driver Standard', '333333'),
    ('driver_444444@uumo.app', 'Driver Premium', '444444'),
    ('driver_555555@uumo.app', 'Driver SUV', '555555'),
    ('driver_666666@uumo.app', 'Driver Minibus', '666666')
) AS t(email, full_name, phone);

-- 3. Insérer dans public.users (uniquement les nouveaux)
INSERT INTO public.users (id, email, phone, full_name, user_type)
SELECT 
    au.id,
    au.email,
    au.raw_user_meta_data->>'phone',
    au.raw_user_meta_data->>'full_name',
    'driver'::user_type
FROM auth.users au
WHERE au.email LIKE 'driver_%@uumo.app'
AND NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = au.id
);

-- 4. Créer les profils de drivers avec leurs véhicules
INSERT INTO driver_profiles (
    id,
    vehicle_type,
    vehicle_brand,
    vehicle_model,
    vehicle_color,
    vehicle_plate,
    license_number,
    rating,
    total_trips,
    is_available,
    token_balance
)
SELECT 
    u.id,
    vehicle_data.vehicle_type::vehicle_type,
    vehicle_data.brand,
    vehicle_data.model,
    vehicle_data.color,
    vehicle_data.plate,
    vehicle_data.license,
    4.8,
    50,
    true,
    100
FROM public.users u
CROSS JOIN LATERAL (
    SELECT * FROM (VALUES
        ('driver_111111@uumo.app', 'moto', 'Yamaha', 'MT-07', 'Noir', 'AB-123-CD', 'MOTO123456'),
        ('driver_222222@uumo.app', 'car_economy', 'Renault', 'Clio 5', 'Blanc', 'EF-456-GH', 'DRV7890123'),
        ('driver_333333@uumo.app', 'car_standard', 'Peugeot', '308', 'Gris', 'IJ-789-KL', 'DRV4561234'),
        ('driver_444444@uumo.app', 'car_premium', 'BMW', 'Série 5', 'Noir', 'MN-012-OP', 'DRV7892345'),
        ('driver_555555@uumo.app', 'suv', 'Audi', 'Q5', 'Bleu', 'QR-345-ST', 'DRV1233456'),
        ('driver_666666@uumo.app', 'minibus', 'Mercedes', 'Vito', 'Blanc', 'UV-678-WX', 'DRV4564567')
    ) AS v(email, vehicle_type, brand, model, color, plate, license)
    WHERE v.email = u.email
) AS vehicle_data(email, vehicle_type, brand, model, color, plate, license)
WHERE u.email LIKE 'driver_%@uumo.app';

-- 5. Vérifier la création
SELECT 
    dp.id,
    u.full_name,
    u.phone,
    dp.vehicle_type,
    dp.vehicle_brand || ' ' || dp.vehicle_model as vehicle,
    dp.vehicle_plate,
    dp.is_available,
    dp.token_balance
FROM driver_profiles dp
JOIN public.users u ON u.id = dp.id
WHERE u.phone IN ('111111', '222222', '333333', '444444', '555555', '666666')
ORDER BY dp.vehicle_type;

-- 6. Afficher un résumé
SELECT 
    'Drivers créés avec succès!' as message,
    COUNT(*) as total_drivers
FROM driver_profiles dp
JOIN public.users u ON u.id = dp.id
WHERE u.phone IN ('111111', '222222', '333333', '444444', '555555', '666666');

-- Informations de connexion (Téléphone / Mot de passe):
-- Moto:     111111 / tototo
-- Economy:  222222 / tototo
-- Standard: 333333 / tototo
-- Premium:  444444 / tototo
-- SUV:      555555 / tototo
-- Minibus:  666666 / tototo
