/// Types de réservation disponibles pour les courses
/// Ces valeurs doivent correspondre exactement à l'ENUM booking_type dans Supabase
enum BookingType {
  immediate('immediate', 'Immédiate', '⚡', 'Départ maintenant'),
  scheduled('scheduled', 'Réservée', '📅', 'Planifier pour plus tard');

  /// Valeur stockée en base de données
  final String value;

  /// Nom affiché à l'utilisateur
  final String displayName;

  /// Icône emoji du type
  final String emoji;

  /// Description du type de réservation
  final String description;

  const BookingType(this.value, this.displayName, this.emoji, this.description);

  /// Convertir depuis la valeur de la base de données
  static BookingType fromString(String value) {
    return BookingType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => BookingType.immediate,
    );
  }

  /// Vérifier si c'est une course immédiate
  bool get isImmediate => this == BookingType.immediate;

  /// Vérifier si c'est une course réservée
  bool get isScheduled => this == BookingType.scheduled;
}
