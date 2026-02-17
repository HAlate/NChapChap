import '../core/constants/kyc_types.dart';

/// Modèle représentant un document KYC soumis par un chauffeur
class KycDocument {
  final String id;
  final String driverId;
  final KycDocumentType documentType;
  final String? documentNumber;
  final DateTime? expiryDate;

  // URLs des images stockées
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? selfieUrl;

  // Données extraites par Microblink
  final Map<String, dynamic>? microblinkData;
  final String? extractedName;
  final DateTime? extractedBirthDate;
  final String? extractedAddress;

  // Statut de vérification
  final KycStatus verificationStatus;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  // Notes et feedback
  final String? adminNotes;
  final String? rejectionReason;

  // Métadonnées
  final DateTime submittedAt;
  final DateTime updatedAt;

  KycDocument({
    required this.id,
    required this.driverId,
    required this.documentType,
    this.documentNumber,
    this.expiryDate,
    this.frontImageUrl,
    this.backImageUrl,
    this.selfieUrl,
    this.microblinkData,
    this.extractedName,
    this.extractedBirthDate,
    this.extractedAddress,
    required this.verificationStatus,
    this.verifiedBy,
    this.verifiedAt,
    this.adminNotes,
    this.rejectionReason,
    required this.submittedAt,
    required this.updatedAt,
  });

  /// Créer depuis JSON Supabase
  factory KycDocument.fromJson(Map<String, dynamic> json) {
    return KycDocument(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      documentType: KycDocumentType.fromString(json['document_type'] as String),
      documentNumber: json['document_number'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      frontImageUrl: json['front_image_url'] as String?,
      backImageUrl: json['back_image_url'] as String?,
      selfieUrl: json['selfie_url'] as String?,
      microblinkData: json['microblink_data'] as Map<String, dynamic>?,
      extractedName: json['extracted_name'] as String?,
      extractedBirthDate: json['extracted_birth_date'] != null
          ? DateTime.parse(json['extracted_birth_date'] as String)
          : null,
      extractedAddress: json['extracted_address'] as String?,
      verificationStatus:
          KycStatus.fromString(json['verification_status'] as String),
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convertir en JSON pour Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'document_type': documentType.value,
      'document_number': documentNumber,
      'expiry_date': expiryDate?.toIso8601String(),
      'front_image_url': frontImageUrl,
      'back_image_url': backImageUrl,
      'selfie_url': selfieUrl,
      'microblink_data': microblinkData,
      'extracted_name': extractedName,
      'extracted_birth_date': extractedBirthDate?.toIso8601String(),
      'extracted_address': extractedAddress,
      'verification_status': verificationStatus.value,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'admin_notes': adminNotes,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copier avec modifications
  KycDocument copyWith({
    String? id,
    String? driverId,
    KycDocumentType? documentType,
    String? documentNumber,
    DateTime? expiryDate,
    String? frontImageUrl,
    String? backImageUrl,
    String? selfieUrl,
    Map<String, dynamic>? microblinkData,
    String? extractedName,
    DateTime? extractedBirthDate,
    String? extractedAddress,
    KycStatus? verificationStatus,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? adminNotes,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? updatedAt,
  }) {
    return KycDocument(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      frontImageUrl: frontImageUrl ?? this.frontImageUrl,
      backImageUrl: backImageUrl ?? this.backImageUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      microblinkData: microblinkData ?? this.microblinkData,
      extractedName: extractedName ?? this.extractedName,
      extractedBirthDate: extractedBirthDate ?? this.extractedBirthDate,
      extractedAddress: extractedAddress ?? this.extractedAddress,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Vérifier si le document est expiré
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  /// Vérifier si le document est en attente
  bool get isPending =>
      verificationStatus == KycStatus.pending ||
      verificationStatus == KycStatus.inReview;

  /// Vérifier si le document est approuvé
  bool get isApproved => verificationStatus == KycStatus.approved;

  /// Vérifier si le document est rejeté
  bool get isRejected => verificationStatus == KycStatus.rejected;
}

/// Modèle pour l'état KYC global d'un chauffeur
class DriverKycStatus {
  final KycStatus status;
  final DateTime? completedAt;
  final DateTime? expiryDate;
  final List<KycDocument> documents;

  DriverKycStatus({
    required this.status,
    this.completedAt,
    this.expiryDate,
    this.documents = const [],
  });

  /// Créer depuis les données du driver_profile
  factory DriverKycStatus.fromProfile(Map<String, dynamic> profile) {
    return DriverKycStatus(
      status: KycStatus.fromString(
          profile['kyc_status'] as String? ?? 'not_started'),
      completedAt: profile['kyc_completed_at'] != null
          ? DateTime.parse(profile['kyc_completed_at'] as String)
          : null,
      expiryDate: profile['kyc_expiry_date'] != null
          ? DateTime.parse(profile['kyc_expiry_date'] as String)
          : null,
    );
  }

  /// Vérifier si le chauffeur peut accepter des courses
  bool get canAcceptTrips {
    if (!status.canAcceptTrips) return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  /// Obtenir les documents manquants requis
  List<KycDocumentType> get missingRequiredDocuments {
    final submitted = documents.map((d) => d.documentType).toSet();
    final required = KycDocumentType.values.where((t) => t.isRequired);
    return required.where((type) => !submitted.contains(type)).toList();
  }

  /// Obtenir le prochain document à soumettre
  KycDocumentType? get nextDocumentToSubmit {
    final missing = missingRequiredDocuments;
    return missing.isNotEmpty ? missing.first : null;
  }

  /// Pourcentage de complétion
  double get completionPercentage {
    final required = KycDocumentType.values.where((t) => t.isRequired).length;
    final approved = documents
        .where((d) => d.isApproved && d.documentType.isRequired)
        .length;
    return (approved / required) * 100;
  }
}
