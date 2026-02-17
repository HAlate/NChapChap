class TokenPackage {
  final String id;
  final String name;
  final String? description;
  final String tokenType;
  final int tokenAmount;
  final int priceXof;
  final int? priceGhs;
  final int? priceNgn;
  final int? priceXaf;
  final int discountPercent;
  final bool isPopular;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;

  TokenPackage({
    required this.id,
    required this.name,
    this.description,
    required this.tokenType,
    required this.tokenAmount,
    required this.priceXof,
    this.priceGhs,
    this.priceNgn,
    this.priceXaf,
    required this.discountPercent,
    required this.isPopular,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
  });

  factory TokenPackage.fromJson(Map<String, dynamic> json) {
    return TokenPackage(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      tokenType: json['token_type'] as String,
      tokenAmount: json['token_amount'] as int,
      priceXof: json['price_xof'] as int,
      priceGhs: json['price_ghs'] as int?,
      priceNgn: json['price_ngn'] as int?,
      priceXaf: json['price_xaf'] as int?,
      discountPercent: json['discount_percent'] as int? ?? 0,
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'token_type': tokenType,
      'token_amount': tokenAmount,
      'price_xof': priceXof,
      'price_ghs': priceGhs,
      'price_ngn': priceNgn,
      'price_xaf': priceXaf,
      'discount_percent': discountPercent,
      'is_popular': isPopular,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  int getPriceForCurrency(String currencyCode) {
    switch (currencyCode) {
      case 'XOF':
        return priceXof;
      case 'GHS':
        return priceGhs ?? priceXof;
      case 'NGN':
        return priceNgn ?? priceXof;
      case 'XAF':
        return priceXaf ?? priceXof;
      default:
        return priceXof;
    }
  }

  String getFormattedPrice(String currencyCode) {
    final price = getPriceForCurrency(currencyCode);
    switch (currencyCode) {
      case 'XOF':
        return '$price F CFA';
      case 'GHS':
        return 'GH₵ $price';
      case 'NGN':
        return '₦ $price';
      case 'XAF':
        return '$price F CFA';
      default:
        return '$price F CFA';
    }
  }
}
