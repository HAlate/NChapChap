/// Énumération des types de documents KYC acceptés
enum KycDocumentType {
  nationalId('national_id', 'Carte d\'identité', '🪪'),
  passport('passport', 'Passeport', '🛂'),
  driversLicense('drivers_license', 'Permis de conduire', '🚗'),
  vehicleRegistration('vehicle_registration', 'Carte grise', '📋'),
  insurance('insurance', 'Assurance', '🛡️'),
  selfie('selfie', 'Photo selfie', '🤳');

  final String value;
  final String displayName;
  final String emoji;

  const KycDocumentType(this.value, this.displayName, this.emoji);

  static KycDocumentType fromString(String value) {
    return KycDocumentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => KycDocumentType.nationalId,
    );
  }

  bool get isRequired =>
      this == KycDocumentType.nationalId ||
      this == KycDocumentType.passport ||
      this == KycDocumentType.driversLicense ||
      this == KycDocumentType.selfie;
}

/// Énumération des statuts de vérification KYC
enum KycStatus {
  notStarted('not_started', 'Non commencé', '⚪'),
  pending('pending', 'En attente', '🟡'),
  inReview('in_review', 'En révision', '🔵'),
  approved('approved', 'Approuvé', '🟢'),
  rejected('rejected', 'Rejeté', '🔴'),
  expired('expired', 'Expiré', '🟠');

  final String value;
  final String displayName;
  final String emoji;

  const KycStatus(this.value, this.displayName, this.emoji);

  static KycStatus fromString(String value) {
    return KycStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => KycStatus.notStarted,
    );
  }

  bool get canAcceptTrips => this == KycStatus.approved;
  bool get needsAction =>
      this == KycStatus.notStarted ||
      this == KycStatus.rejected ||
      this == KycStatus.expired;
}
