-- Fix pour l'erreur "Database error querying schema" lors de la connexion

-- 1. Vérifier et corriger les politiques RLS sur auth.users
-- Supabase Auth a besoin d'accéder à auth.users sans restrictions RLS pour la connexion

-- 2. Vérifier que l'utilisateur existe dans public.users
-- Si la query #9 du diagnostic était vide, on doit créer l'entrée
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Récupérer l'ID de auth.users
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = 'driver_111111@uumo.app';

    -- Si l'utilisateur existe dans auth.users mais pas dans public.users
    IF v_user_id IS NOT NULL THEN
        -- Insérer dans public.users si absent
        INSERT INTO public.users (id, email, phone, full_name, user_type)
        SELECT 
            au.id,
            au.email,
            au.raw_user_meta_data->>'phone',
            au.raw_user_meta_data->>'full_name',
            'driver'::user_type
        FROM auth.users au
        WHERE au.email = 'driver_111111@uumo.app'
        AND NOT EXISTS (
            SELECT 1 FROM public.users WHERE id = au.id
        )
        ON CONFLICT (id) DO NOTHING;
        
        RAISE NOTICE 'Utilisateur synchronisé dans public.users';
    ELSE
        RAISE NOTICE 'Utilisateur non trouvé dans auth.users';
    END IF;
END $$;

-- 3. Désactiver temporairement RLS sur users pour tester
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 4. Vérifier que tous les drivers de test sont dans public.users
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
)
ON CONFLICT (id) DO NOTHING;

-- 5. Réactiver RLS avec des politiques correctes
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 6. Recréer les politiques RLS
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.users;

-- Politique de lecture: les utilisateurs peuvent lire leur propre profil
CREATE POLICY "Users can view own profile"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Politique de mise à jour: les utilisateurs peuvent modifier leur propre profil
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Politique d'insertion: permettre l'insertion pour les nouveaux utilisateurs
CREATE POLICY "Enable insert for authenticated users"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 7. Vérification finale
SELECT 
    'Vérification finale' as status,
    COUNT(*) as total_drivers_in_public_users
FROM public.users
WHERE email LIKE 'driver_%@uumo.app';

-- 8. Afficher les infos du driver de test
SELECT 
    u.id,
    u.email,
    u.phone,
    u.full_name,
    u.user_type,
    dp.vehicle_type,
    dp.vehicle_brand || ' ' || dp.vehicle_model as vehicle,
    dp.is_available
FROM public.users u
JOIN driver_profiles dp ON dp.id = u.id
WHERE u.email = 'driver_111111@uumo.app';

-- Message de confirmation
SELECT 'Correction terminée! Essayez de vous reconnecter avec: 111111 / tototo' as message;
