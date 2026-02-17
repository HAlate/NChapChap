import 'package:flutter/material.dart';

/// Modèle représentant un opérateur Mobile Money
///
/// Contient:
/// - id: Identifiant unique dans la base de données
/// - name: Nom affiché (MTN, Moov, Togocom, etc.)
/// - code: Code court pour affichage (MTN, MVA, TGC)
/// - countryCode: Code pays ISO (TG, BJ, CI, etc.)
/// - phoneNumber: Numéro de l'opérateur pour recevoir les paiements
/// - ussdPattern: Formule USSD avec placeholders ({amount}, {code}, {phone})
/// - color: Couleur de branding de l'opérateur
/// - isActive: Si l'opérateur accepte actuellement les paiements
class MobileMoneyProvider {
  final String id;
  final String name;
  final String code;
  final String countryCode;
  final String countryName;
  final String phoneNumber;
  final String accountName;
  final String ussdPattern;
  final Color color;
  final bool isActive;

  const MobileMoneyProvider({
    required this.id,
    required this.name,
    required this.code,
    required this.countryCode,
    required this.countryName,
    required this.phoneNumber,
    required this.accountName,
    required this.ussdPattern,
    required this.color,
    this.isActive = true,
  });

  /// Retourne le nom complet: "Togo - MTN - Mobile Money"
  String get displayName => '$countryName - $name - $accountName';

  /// Création depuis JSON (base de données Supabase)
  factory MobileMoneyProvider.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String? ?? json['name'] as String;

    return MobileMoneyProvider(
      id: json['id'] as String,
      name: providerName,
      code: json['code'] as String? ?? _getCodeFromName(providerName),
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
      phoneNumber: json['phone_number'] as String,
      accountName: json['account_name'] as String,
      ussdPattern: json['ussd_pattern'] as String? ??
          _getDefaultUssdPattern(providerName),
      color: _getColorFromProvider(providerName),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Conversion vers JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'country_code': countryCode,
      'phone_number': phoneNumber,
      'ussd_pattern': ussdPattern,
      'is_active': isActive,
    };
  }

  /// Génère le code USSD final avec les valeurs réelles
  ///
  /// Remplace les placeholders:
  /// - {amount} : Montant à envoyer
  /// - {code} : Code de sécurité
  /// - {phone} : Numéro destinataire (optionnel)
  String generateUssdCode({
    required int amount,
    required String securityCode,
    String? recipientPhone,
  }) {
    return ussdPattern
        .replaceAll('{amount}', amount.toString())
        .replaceAll('{code}', securityCode)
        .replaceAll('{phone}', recipientPhone ?? phoneNumber);
  }

  /// Extrait un code court depuis le nom
  static String _getCodeFromName(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('MTN')) return 'MTN';
    if (upper.contains('MOOV')) return 'MVA';
    if (upper.contains('TOGOCOM')) return 'TGC';
    if (upper.contains('ORANGE')) return 'ORA';
    if (upper.contains('CELTIIS')) return 'CEL';
    if (upper.contains('AIRTEL')) return 'AIR';
    // Par défaut, prendre les 3 premières lettres
    return name.substring(0, name.length >= 3 ? 3 : name.length).toUpperCase();
  }

  /// Récupère la couleur de branding selon le nom
  static Color _getColorFromProvider(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('MTN')) return const Color(0xFFFFCC00); // Jaune MTN
    if (upper.contains('MOOV')) return const Color(0xFF0066CC); // Bleu Moov
    if (upper.contains('TOGOCOM'))
      return const Color(0xFFFF6600); // Orange Togocom
    if (upper.contains('ORANGE')) return const Color(0xFFFF6600); // Orange
    if (upper.contains('CELTIIS'))
      return const Color(0xFF00AA00); // Vert Celtiis
    if (upper.contains('AIRTEL'))
      return const Color(0xFFCC0000); // Rouge Airtel
    return Colors.grey; // Couleur par défaut
  }

  /// Récupère le pattern USSD par défaut selon l'opérateur
  static String _getDefaultUssdPattern(String name) {
    final upper = name.toUpperCase();
    // Patterns USSD standards (peuvent être modifiés dans la DB)
    if (upper.contains('MTN')) {
      return '*133*1*1*{amount}*{code}#';
    }
    if (upper.contains('MOOV')) {
      return '*555*1*{amount}*{code}#';
    }
    if (upper.contains('TOGOCOM')) {
      return '*900*1*{amount}*{code}#';
    }
    if (upper.contains('ORANGE')) {
      return '*144*1*{amount}*{code}#';
    }
    if (upper.contains('CELTIIS')) {
      return '*901*{amount}*{code}#';
    }
    if (upper.contains('AIRTEL')) {
      return '*777*{amount}*{code}#';
    }
    // Pattern générique par défaut
    return '*XXX*{amount}*{code}#';
  }

  /// Copie avec modifications
  MobileMoneyProvider copyWith({
    String? id,
    String? name,
    String? code,
    String? countryCode,
    String? countryName,
    String? phoneNumber,
    String? accountName,
    String? ussdPattern,
    Color? color,
    bool? isActive,
  }) {
    return MobileMoneyProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountName: accountName ?? this.accountName,
      ussdPattern: ussdPattern ?? this.ussdPattern,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'MobileMoneyProvider(id: $id, name: $name, code: $code, country: $countryCode, ussd: $ussdPattern)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MobileMoneyProvider && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
