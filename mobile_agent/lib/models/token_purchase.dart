class TokenPurchase {
  final String id;
  final String driverId;
  final String packageId;
  final String mobileMoneyNumberId;

  // Détails de la transaction
  final int tokenAmount;
  final int bonusTokens;
  final int totalTokens;
  final int pricePaid;

  // Informations de paiement
  final String senderPhone;
  final String? transactionReference;
  final String? paymentProofUrl;

  // Statut
  final String status; // pending, validated, rejected, expired

  // Validation admin
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? rejectionReason;
  final String? adminNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  TokenPurchase({
    required this.id,
    required this.driverId,
    required this.packageId,
    required this.mobileMoneyNumberId,
    required this.tokenAmount,
    this.bonusTokens = 0,
    required this.totalTokens,
    required this.pricePaid,
    required this.senderPhone,
    this.transactionReference,
    this.paymentProofUrl,
    this.status = 'pending',
    this.validatedBy,
    this.validatedAt,
    this.rejectionReason,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isValidated => status == 'validated';
  bool get isRejected => status == 'rejected';
  bool get isExpired => status == 'expired';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'validated':
        return 'Validé';
      case 'rejected':
        return 'Rejeté';
      case 'expired':
        return 'Expiré';
      default:
        return 'Inconnu';
    }
  }

  factory TokenPurchase.fromJson(Map<String, dynamic> json) {
    return TokenPurchase(
      id: json['id'] as String,
      driverId: json['user_id'] as String,
      packageId: json['package_id'] as String,
      mobileMoneyNumberId: json['mobile_money_number_id'] as String,
      tokenAmount: json['token_amount'] as int,
      bonusTokens: json['bonus_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int,
      pricePaid: json['price_paid'] as int,
      senderPhone: json['sender_phone'] as String,
      transactionReference: json['transaction_reference'] as String?,
      paymentProofUrl: json['payment_proof_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      validatedBy: json['validated_by'] as String?,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Factory pour créer depuis token_transactions (structure existante)
  factory TokenPurchase.fromTransaction(Map<String, dynamic> json) {
    final transactionType = json['transaction_type'] as String?;
    final amount = json['amount'] as int? ?? 0;

    return TokenPurchase(
      id: json['id'] as String,
      driverId: json['user_id'] as String,
      packageId: json['reference_id'] as String? ?? '',
      mobileMoneyNumberId: '',
      tokenAmount: amount.abs(),
      bonusTokens: 0,
      totalTokens: amount.abs(),
      pricePaid: 0,
      senderPhone: '',
      transactionReference: json['reference_id'] as String?,
      paymentProofUrl: null,
      status: transactionType == 'purchase' ? 'validated' : 'pending',
      validatedBy: null,
      validatedAt: transactionType == 'purchase'
          ? DateTime.parse(json['created_at'] as String)
          : null,
      rejectionReason: null,
      adminNotes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': driverId,
      'package_id': packageId,
      'mobile_money_number_id': mobileMoneyNumberId,
      'token_amount': tokenAmount,
      'bonus_tokens': bonusTokens,
      'total_tokens': totalTokens,
      'price_paid': pricePaid,
      'sender_phone': senderPhone,
      'transaction_reference': transactionReference,
      'payment_proof_url': paymentProofUrl,
      'status': status,
      'validated_by': validatedBy,
      'validated_at': validatedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TokenBalance {
  final String driverId;
  final int totalTokens;
  final int tokensUsed;
  final int tokensAvailable;
  final DateTime? lastPurchaseAt;
  final DateTime updatedAt;

  TokenBalance({
    required this.driverId,
    this.totalTokens = 0,
    this.tokensUsed = 0,
    this.tokensAvailable = 0,
    this.lastPurchaseAt,
    required this.updatedAt,
  });

  factory TokenBalance.fromJson(Map<String, dynamic> json) {
    return TokenBalance(
      driverId: json['user_id'] as String,
      totalTokens: json['total_tokens'] as int? ?? 0,
      tokensUsed: json['tokens_used'] as int? ?? 0,
      tokensAvailable: json['tokens_available'] as int? ?? 0,
      lastPurchaseAt: json['last_purchase_at'] != null
          ? DateTime.parse(json['last_purchase_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': driverId,
      'total_tokens': totalTokens,
      'tokens_used': tokensUsed,
      'tokens_available': tokensAvailable,
      'last_purchase_at': lastPurchaseAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class MobileMoneyNumber {
  final String id;
  final String countryCode;
  final String countryName;
  final String provider;
  final String phoneNumber;
  final String accountName;
  final bool isActive;
  final String? instructions;
  final int displayOrder;

  MobileMoneyNumber({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.provider,
    required this.phoneNumber,
    required this.accountName,
    this.isActive = true,
    this.instructions,
    this.displayOrder = 0,
  });

  factory MobileMoneyNumber.fromJson(Map<String, dynamic> json) {
    return MobileMoneyNumber(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
      provider: json['provider'] as String,
      phoneNumber: json['phone_number'] as String,
      accountName: json['account_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      instructions: json['instructions'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_code': countryCode,
      'country_name': countryName,
      'provider': provider,
      'phone_number': phoneNumber,
      'account_name': accountName,
      'is_active': isActive,
      'instructions': instructions,
      'display_order': displayOrder,
    };
  }
}
