/// Modèle pour un achat de jetons en attente de validation admin
/// Correspond à la view pending_token_purchases de Supabase
class PendingTokenPurchase {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final String packageId;
  final String packageName;
  final int tokenAmount;
  final int bonusTokens;
  final int totalTokens;
  final int pricePaid;
  final int transactionFee;
  final int totalAmount;
  final String mobileMoneyProvider;
  final String? mobileMoneyPhone;
  final bool smsNotification;
  final bool whatsappNotification;
  final String status;
  final DateTime createdAt;

  PendingTokenPurchase({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    required this.packageId,
    required this.packageName,
    required this.tokenAmount,
    required this.bonusTokens,
    required this.totalTokens,
    required this.pricePaid,
    required this.transactionFee,
    required this.totalAmount,
    required this.mobileMoneyProvider,
    this.mobileMoneyPhone,
    required this.smsNotification,
    required this.whatsappNotification,
    required this.status,
    required this.createdAt,
  });

  factory PendingTokenPurchase.fromJson(Map<String, dynamic> json) {
    return PendingTokenPurchase(
      id: json['id'] as String,
      driverId: json['user_id'] as String,
      driverName: json['driver_name'] as String,
      driverPhone: json['driver_phone'] as String?,
      packageId: json['package_id'] as String,
      packageName: json['package_name'] as String,
      tokenAmount: json['token_amount'] as int,
      bonusTokens: json['bonus_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int,
      pricePaid: json['price_paid'] as int,
      transactionFee: json['transaction_fee'] as int,
      totalAmount: json['total_amount'] as int,
      mobileMoneyProvider: json['mobile_money_provider'] as String,
      mobileMoneyPhone: json['mobile_money_phone'] as String?,
      smsNotification: json['sms_notification'] as bool? ?? false,
      whatsappNotification: json['whatsapp_notification'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': driverId,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'package_id': packageId,
      'package_name': packageName,
      'token_amount': tokenAmount,
      'bonus_tokens': bonusTokens,
      'total_tokens': totalTokens,
      'price_paid': pricePaid,
      'transaction_fee': transactionFee,
      'total_amount': totalAmount,
      'mobile_money_provider': mobileMoneyProvider,
      'mobile_money_phone': mobileMoneyPhone,
      'sms_notification': smsNotification,
      'whatsapp_notification': whatsappNotification,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Temps écoulé depuis la création (ex: "il y a 2 min", "il y a 1h")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'il y a ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'il y a ${difference.inHours}h';
    } else {
      return 'il y a ${difference.inDays}j';
    }
  }

  /// Icône de l'opérateur Mobile Money
  String get providerIcon {
    if (mobileMoneyProvider.toUpperCase().contains('MTN')) return '📱';
    if (mobileMoneyProvider.toUpperCase().contains('MOOV')) return '💳';
    if (mobileMoneyProvider.toUpperCase().contains('TOGOCOM')) return '📲';
    if (mobileMoneyProvider.toUpperCase().contains('ORANGE')) return '🍊';
    return '💰';
  }

  /// Badge de notification
  String get notificationBadge {
    final badges = <String>[];
    if (smsNotification) badges.add('SMS');
    if (whatsappNotification) badges.add('WhatsApp');
    return badges.isEmpty ? '' : badges.join(' + ');
  }

  @override
  String toString() {
    return 'PendingTokenPurchase(id: $id, driver: $driverName, amount: $totalAmount F, status: $status, created: $timeAgo)';
  }
}
