-- Alternative utilisant RPC (Remote Procedure Call)
-- Si la politique WITH CHECK (true) ne fonctionne toujours pas

-- Version avec fonction RPC
SELECT create_notification(
    '09d19641-9600-404c-aa02-2a56f754467a'::UUID,  -- user_id du destinataire
    'incoming_call',  -- type
    'Appel entrant',  -- title
    'Votre passager vous appelle',  -- message
    '{"call_id": "test-123", "caller_type": "rider"}'::JSONB  -- data
);

-- Si cette requête fonctionne, modifiez le code Flutter pour utiliser RPC
-- au lieu de .insert()
