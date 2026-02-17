-- Add related_id column to token_transactions table
-- This is used by the trigger functions but was missing from the schema
ALTER TABLE token_transactions 
ADD COLUMN IF NOT EXISTS related_id uuid;

-- Verify the column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'token_transactions'
ORDER BY ordinal_position;
