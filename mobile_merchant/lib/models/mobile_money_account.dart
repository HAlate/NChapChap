class MobileMoneyProvider {
  final String id;
  final String name;
  final String? shortName;
  final String? logoUrl;
  final String? ussdCode;

  MobileMoneyProvider({
    required this.id,
    required this.name,
    this.shortName,
    this.logoUrl,
    this.ussdCode,
  });

  factory MobileMoneyProvider.fromJson(Map<String, dynamic> json) {
    return MobileMoneyProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String?,
      logoUrl: json['logo_url'] as String?,
      ussdCode: json['ussd_code'] as String?,
    );
  }
}

class MobileMoneyAccount {
  final String id;
  final String countryCode;
  final MobileMoneyProvider? provider;
  final String accountName;
  final String? accountHolder;
  final String phoneNumber;
  final bool isActive;
  final bool isPrimary;

  MobileMoneyAccount({
    required this.id,
    required this.countryCode,
    this.provider,
    required this.accountName,
    this.accountHolder,
    required this.phoneNumber,
    required this.isActive,
    required this.isPrimary,
  });

  factory MobileMoneyAccount.fromJson(Map<String, dynamic> json) {
    return MobileMoneyAccount(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      provider: json['mobile_money_providers'] != null
          ? MobileMoneyProvider.fromJson(json['mobile_money_providers'])
          : null,
      accountName: json['account_name'] as String,
      accountHolder: json['account_holder'] as String?,
      phoneNumber: json['phone_number'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}
