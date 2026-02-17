/// Types de véhicules disponibles dans l'application
/// Ces valeurs doivent correspondre exactement à l'ENUM vehicle_type dans Supabase
enum VehicleType {
  moto('moto', 'Moto', '🏍️', 'Moto/Scooter rapide et économique'),
  carEconomy(
      'car_economy', 'Économique', '🚗', 'Voiture compacte à petit prix'),
  carStandard(
      'car_standard', 'Standard', '🚙', 'Voiture confortable classique'),
  carPremium('car_premium', 'Premium', '🚘', 'Voiture haut de gamme'),
  suv('suv', 'SUV', '🚐', 'Grand véhicule spacieux'),
  minibus('minibus', 'Minibus', '🚌', 'Transport 6-8 passagers');

  /// Valeur stockée en base de données
  final String value;

  /// Nom affiché à l'utilisateur
  final String displayName;

  /// Icône emoji du véhicule
  final String emoji;

  /// Description du type de véhicule
  final String description;

  const VehicleType(this.value, this.displayName, this.emoji, this.description);

  /// Convertir depuis la valeur de la base de données
  static VehicleType fromString(String value) {
    return VehicleType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => VehicleType.carStandard,
    );
  }

  /// Obtenir la liste de tous les types pour affichage
  static List<VehicleType> get all => VehicleType.values;
}
