-- Ajout de la colonne driver_counter_price pour permettre au driver de faire une contre-offre
-- 
-- WORKFLOW DE NÉGOCIATION COMPLET:
-- 1. Driver propose un prix initial (offered_price)
-- 2. Rider peut accepter OU faire une contre-offre (counter_price)
-- 3. Driver peut accepter la contre-offre du rider OU faire sa propre contre-offre (driver_counter_price)
-- 4. Négociation continue jusqu'à accord mutuel (final_price)
--
-- EXEMPLE:
-- - Driver offre: 5000 (offered_price)
-- - Rider contre-offre: 4000 (counter_price)
-- - Driver contre-offre: 4500 (driver_counter_price)
-- - Rider accepte: 4500 (final_price)

-- Ajouter la colonne driver_counter_price à trip_offers
ALTER TABLE trip_offers 
ADD COLUMN IF NOT EXISTS driver_counter_price int CHECK (driver_counter_price > 0);

-- Ajouter un commentaire pour documenter
COMMENT ON COLUMN trip_offers.driver_counter_price IS 
'Contre-offre du driver suite à la contre-offre du rider. Permet une négociation bidirectionnelle complète.';

-- Mettre à jour le commentaire de la table
COMMENT ON TABLE trip_offers IS 
'Offres des drivers pour les trajets avec système de négociation bidirectionnelle:
- offered_price: Prix initial proposé par le driver
- counter_price: Contre-offre du rider
- driver_counter_price: Contre-offre du driver (réponse à counter_price)
- final_price: Prix final accepté par les deux parties';
