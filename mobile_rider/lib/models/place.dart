/// Représente un lieu, avec des informations géographiques et descriptives.
class Place {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  Place({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Crée une instance de Place à partir d'une prédiction d'autocomplétion de Google Places.
  /// Les coordonnées sont initialisées à 0.0 et devront être récupérées plus tard.
  factory Place.fromAutocomplete(Map<String, dynamic> prediction) {
    return Place(
      placeId: prediction['place_id'] as String,
      name: prediction['structured_formatting']['main_text'],
      address: prediction['description'],
      latitude: 0.0, // Les détails doivent être récupérés séparément
      longitude: 0.0, // Les détails doivent être récupérés séparément
    );
  }

  /// Crée une instance de Place à partir des détails d'un lieu de Google Places.
  factory Place.fromDetails(Map<String, dynamic> result) {
    return Place(
      placeId: result['place_id'] ?? '',
      name: result['name'],
      address: result['formatted_address'],
      latitude: result['geometry']['location']['lat'],
      longitude: result['geometry']['location']['lng'],
    );
  }

  @override
  String toString() {
    return 'Place(name: $name, address: $address, lat: $latitude, lng: $longitude)';
  }
}
