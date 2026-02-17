-- Ajout du champ driver_arrived_notification à la table trips
-- Ce champ permet au chauffeur de notifier manuellement le passager de son arrivée

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS driver_arrived_notification TIMESTAMP WITH TIME ZONE;

-- Ajouter un commentaire pour documenter le champ
COMMENT ON COLUMN trips.driver_arrived_notification IS 
'Timestamp de la dernière notification manuelle envoyée par le chauffeur pour signaler son arrivée au passager';
