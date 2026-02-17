-- ========================================
-- Script pour mettre à jour le nom d'un rider
-- ========================================
-- Utilisation: Remplacez les valeurs ci-dessous puis exécutez

DO $$
DECLARE
  v_rider_phone text := '909090'; -- Changez par le téléphone du rider
  v_full_name text := 'Passager Test'; -- Nom complet du rider
  v_rider_id uuid;
BEGIN
  -- Trouver l'ID du rider par son téléphone
  SELECT id INTO v_rider_id
  FROM users
  WHERE phone = v_rider_phone AND user_type = 'rider';

  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'Rider avec le téléphone % non trouvé', v_rider_phone;
  END IF;

  -- Mettre à jour le nom complet
  UPDATE users
  SET full_name = v_full_name,
      updated_at = now()
  WHERE id = v_rider_id;

  RAISE NOTICE '✅ Nom mis à jour pour le rider (téléphone: %)', v_rider_phone;
  RAISE NOTICE '📝 Nouveau nom: %', v_full_name;
END $$;

-- ========================================
-- Vérifier le résultat
-- ========================================
SELECT 
  id,
  phone,
  full_name,
  email,
  user_type,
  created_at
FROM users
WHERE user_type = 'rider'
ORDER BY created_at DESC;
