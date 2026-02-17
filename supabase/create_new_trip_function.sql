-- 1. Définition de la fonction pour créer une nouvelle course.
-- Cette fonction s'exécute avec les droits du créateur (SECURITY DEFINER),
-- ce qui lui permet de contourner les RLS pour les actions qu'elle déclenche (comme la création de notifications).
create or replace function public.create_new_trip(
    p_departure text,
    p_departure_lat double precision,
    p_departure_lng double precision,
    p_destination text,
    p_destination_lat double precision,
    p_destination_lng double precision,
    p_vehicle_type text,
    p_distance_km double precision
)
returns trips -- La fonction retourne la ligne complète du trajet créé.
language plpgsql
security definer -- C'est la partie la plus importante !
set search_path = public
as $$
declare
  new_trip trips;
begin
  -- Insère la nouvelle course dans la table 'trips'.
  -- Le `rider_id` est automatiquement récupéré depuis l'utilisateur authentifié qui appelle la fonction.
  insert into public.trips(rider_id, departure, departure_lat, departure_lng, destination, destination_lat, destination_lng, vehicle_type, distance_km, status)
  values (auth.uid(), p_departure, p_departure_lat, p_departure_lng, p_destination, p_destination_lat, p_destination_lng, p_vehicle_type::vehicle_type, p_distance_km, 'pending')
  returning * into new_trip;

  return new_trip;
end;
$$;

-- 2. Donner les permissions d'exécution de cette fonction aux utilisateurs authentifiés.
-- Sans cela, l'application ne pourra pas appeler la fonction.
grant execute on function public.create_new_trip(text, double precision, double precision, text, double precision, double precision, text, double precision) to authenticated;