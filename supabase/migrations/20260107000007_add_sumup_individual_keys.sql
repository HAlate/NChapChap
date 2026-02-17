-- Add individual SumUp affiliate keys for drivers
-- This allows each driver to use their own SumUp account

-- Add sumup_affiliate_key column to driver_profiles
ALTER TABLE driver_profiles
ADD COLUMN IF NOT EXISTS sumup_affiliate_key TEXT;

-- Add comment to explain the column
COMMENT ON COLUMN driver_profiles.sumup_affiliate_key IS 'Individual SumUp affiliate key for this driver. If set, the driver can accept card payments directly to their SumUp account.';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_driver_profiles_sumup_key 
ON driver_profiles(sumup_affiliate_key) 
WHERE sumup_affiliate_key IS NOT NULL;

-- Add RLS policy to allow drivers to update their own SumUp key
CREATE POLICY "Drivers can update their own SumUp key"
ON driver_profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
