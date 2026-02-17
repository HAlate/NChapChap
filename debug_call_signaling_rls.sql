-- ============================================
-- Script de débogage pour call_signaling RLS
-- ============================================

-- Vérifier que la session d'appel existe
SELECT 
    'Call Session Info' as info,
    id,
    caller_id,
    receiver_id,
    caller_type,
    status,
    created_at
FROM call_sessions 
WHERE id = 'eb33b926-3067-4d9c-a27a-62abf5513b59';

-- Vérifier les signaux pour cet appel (sans RLS)
SELECT 
    'Signaling Records (No RLS)' as info,
    id,
    call_id,
    sender_id,
    type,
    processed,
    created_at,
    LENGTH(data::text) as data_length
FROM call_signaling 
WHERE call_id = 'eb33b926-3067-4d9c-a27a-62abf5513b59'
ORDER BY created_at;

-- Tester la politique RLS pour le driver
-- Remplacer 'DRIVER_UUID' par l'UUID réel du driver (09d19641-9600-404c-aa02-2a56f754467a)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '09d19641-9600-404c-aa02-2a56f754467a';

-- Vérifier ce que le driver peut voir
SELECT 
    'What Driver Can See (With RLS)' as info,
    cs.id,
    cs.sender_id,
    cs.type,
    cs.processed,
    cs.created_at
FROM call_signaling cs
WHERE cs.call_id = 'eb33b926-3067-4d9c-a27a-62abf5513b59';

-- Réinitialiser
RESET ROLE;

-- Vérifier si le driver est bien le receiver
SELECT 
    'Driver Auth Check' as info,
    caller_id = '09d19641-9600-404c-aa02-2a56f754467a' as is_caller,
    receiver_id = '09d19641-9600-404c-aa02-2a56f754467a' as is_receiver,
    '09d19641-9600-404c-aa02-2a56f754467a'::uuid as driver_uuid
FROM call_sessions
WHERE id = 'eb33b926-3067-4d9c-a27a-62abf5513b59';

-- Vérifier la politique RLS directement
SELECT 
    'RLS Policy Test' as info,
    EXISTS (
        SELECT 1 FROM call_sessions
        WHERE call_sessions.id = 'eb33b926-3067-4d9c-a27a-62abf5513b59'
        AND (
            call_sessions.caller_id = '09d19641-9600-404c-aa02-2a56f754467a'::uuid 
            OR call_sessions.receiver_id = '09d19641-9600-404c-aa02-2a56f754467a'::uuid
        )
    ) as should_have_access;
