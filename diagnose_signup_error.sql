-- =========================================
-- DIAGNOSTIC: Database error saving new user
-- =========================================

-- 1. Vérifier le type enum user_type
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = 'user_type'::regtype
ORDER BY enumsortorder;

-- 2. Vérifier les contraintes sur la table users
SELECT 
  conname as constraint_name,
  contype as type,
  CASE contype
    WHEN 'c' THEN 'CHECK'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'p' THEN 'PRIMARY KEY'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 't' THEN 'TRIGGER'
    ELSE contype::text
  END as constraint_type,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.users'::regclass;

-- 3. Vérifier les politiques RLS sur INSERT
SELECT 
  polname,
  polpermissive,
  polroles::regrole[],
  polcmd,
  polqual,
  polwithcheck
FROM pg_policy
WHERE polrelid = 'public.users'::regclass
  AND polcmd = 'a'; -- INSERT

-- 4. Vérifier la structure complète de users
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default,
  character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- 5. Tester manuellement l'insertion qui échoue
-- (À exécuter séparément pour voir l'erreur exacte)
DO $$
DECLARE
  test_id uuid := gen_random_uuid();
BEGIN
  -- Simuler ce que fait le trigger
  INSERT INTO public.users (id, email, phone, full_name, user_type)
  VALUES (
    test_id,
    'test@uumo.app',
    '123456789',
    'Test User',
    'rider'::user_type
  );
  
  -- Nettoyer
  DELETE FROM public.users WHERE id = test_id;
  
  RAISE NOTICE 'Test d''insertion réussi ✅';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test d''insertion échoué ❌: %', SQLERRM;
END $$;

-- 6. Vérifier que RLS est activé
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'users';
