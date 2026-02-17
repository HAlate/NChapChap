import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/token_package.dart';
import '../models/token_purchase.dart';
import '../models/mobile_money_provider.dart';

class TokenService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Code pays par défaut (Togo)
  static const String _defaultCountryCode = 'TG';

  // =====================================================
  // MOBILE MONEY & PAIEMENTS
  // =====================================================

  /// Récupère le code pays du chauffeur depuis son profil
  /// Retourne le code pays par défaut (TG) si non défini
  Future<String> getDriverCountryCode() async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        debugPrint(
            '[TokenService] User not authenticated, using default country');
        return _defaultCountryCode;
      }

      final response = await _supabase
          .from('driver_profiles')
          .select('country_code')
          .eq('id', driverId)
          .maybeSingle();

      if (response == null || response['country_code'] == null) {
        debugPrint('[TokenService] No country_code in profile, using default');
        return _defaultCountryCode;
      }

      return response['country_code'] as String;
    } catch (e) {
      debugPrint('[TokenService] Error getting country code: $e');
      return _defaultCountryCode;
    }
  }

  /// Récupère les opérateurs Mobile Money disponibles pour le pays du chauffeur
  Future<List<MobileMoneyProvider>> getMobileMoneyProviders() async {
    try {
      // Récupérer le code pays du chauffeur
      final countryCode = await getDriverCountryCode();
      debugPrint('[TokenService] Loading providers for country: $countryCode');

      final response = await _supabase
          .from('mobile_money_numbers')
          .select()
          .eq('country_code', countryCode)
          .eq('is_active', true)
          .order('provider', ascending: true);

      final providers = (response as List)
          .map((json) => MobileMoneyProvider.fromJson(json))
          .toList();

      debugPrint('[TokenService] Found ${providers.length} providers');
      return providers;
    } catch (e) {
      debugPrint('[TokenService] Error getting mobile money providers: $e');
      rethrow;
    }
  }

  /// Crée une demande de paiement Mobile Money
  Future<void> createPaymentRequest({
    required String packageId,
    required String providerId,
    required String securityCode,
    required int totalAmount,
    required int transactionFee,
    bool smsNotification = false,
    bool whatsappNotification = false,
  }) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('User not authenticated');
      }

      // Récupérer le package pour obtenir les détails
      final package = await getPackageById(packageId);
      if (package == null) {
        throw Exception('Package not found');
      }

      final paymentData = {
        'user_id': driverId,
        'package_id': packageId,
        'token_type': 'course',
        'mobile_money_number_id': providerId,
        'token_amount': package.tokenAmount,
        'bonus_tokens': package.discountPercent > 0
            ? (package.tokenAmount * package.discountPercent / 100).round()
            : 0,
        'total_tokens': package.tokenAmount +
            (package.discountPercent > 0
                ? (package.tokenAmount * package.discountPercent / 100).round()
                : 0),
        'price_paid': package.priceXof,
        'transaction_fee': transactionFee,
        'total_amount': totalAmount,
        'security_code_hash':
            _hashSecurityCode(securityCode), // Ne jamais stocker en clair
        'sms_notification': smsNotification,
        'whatsapp_notification': whatsappNotification,
        'payment_method': 'mobile_money',
        'payment_status': 'pending',
      };

      await _supabase.from('token_purchases').insert(paymentData);

      debugPrint('[TokenService] Payment request created successfully');
    } catch (e) {
      debugPrint('[TokenService] Error creating payment request: $e');
      rethrow;
    }
  }

  /// Hash le code de sécurité pour stockage sécurisé
  /// NOTE: Dans un environnement de production, utiliser un vrai algorithme de hash
  String _hashSecurityCode(String code) {
    // Pour l'instant, simple hash basique
    // En production, utiliser crypto package avec SHA-256 ou bcrypt
    return code.hashCode.toString();
  }

  // =====================================================
  // PACKAGES DE JETONS
  // =====================================================

  /// Récupère tous les packages de jetons actifs
  Future<List<TokenPackage>> getActivePackages() async {
    try {
      final response = await _supabase
          .from('token_packages')
          .select()
          .eq('is_active', true)
          .order('price_F CFA', ascending: true);

      return (response as List)
          .map((json) => TokenPackage.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[TokenService] Error getting packages: $e');
      rethrow;
    }
  }

  /// Récupère un package spécifique par ID
  Future<TokenPackage?> getPackageById(String packageId) async {
    try {
      final response = await _supabase
          .from('token_packages')
          .select()
          .eq('id', packageId)
          .single();

      return TokenPackage.fromJson(response);
    } catch (e) {
      debugPrint('[TokenService] Error getting package: $e');
      return null;
    }
  }

  // =====================================================
  // NUMÉROS MOBILE MONEY
  // =====================================================

  /// Récupère les numéros Mobile Money actifs pour un pays
  Future<List<MobileMoneyNumber>> getMobileMoneyNumbers(
      String countryCode) async {
    try {
      final response = await _supabase
          .from('mobile_money_numbers')
          .select()
          .eq('country_code', countryCode)
          .eq('is_active', true)
          .order('provider', ascending: true);

      return (response as List)
          .map((json) => MobileMoneyNumber.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[TokenService] Error getting mobile money numbers: $e');
      rethrow;
    }
  }

  /// Récupère tous les pays disponibles pour Mobile Money
  Future<List<Map<String, String>>> getAvailableCountries() async {
    try {
      final response = await _supabase
          .from('mobile_money_numbers')
          .select('country_code, country_name')
          .eq('is_active', true)
          .order('country_name', ascending: true);

      // Dédupliquer les pays
      final countries = <String, String>{};
      for (final item in response as List) {
        countries[item['country_code'] as String] =
            item['country_name'] as String;
      }

      return countries.entries
          .map((e) => {'code': e.key, 'name': e.value})
          .toList();
    } catch (e) {
      debugPrint('[TokenService] Error getting countries: $e');
      rethrow;
    }
  }

  // =====================================================
  // ACHAT DE JETONS
  // =====================================================

  /// Crée une demande d'achat de jetons (sans numéro Mobile Money visible)
  Future<TokenPurchase> createPurchaseRequest({
    required String packageId,
    required String senderPhone,
    String? transactionReference,
  }) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('User not authenticated');
      }

      // Récupérer le package pour obtenir les détails
      final package = await getPackageById(packageId);
      if (package == null) {
        throw Exception('Package not found');
      }

      // Récupérer un numéro Mobile Money actif (pour usage admin)
      final mobileMoneyNumbers = await _supabase
          .from('mobile_money_numbers')
          .select()
          .eq('is_active', true)
          .limit(1);

      if (mobileMoneyNumbers.isEmpty) {
        throw Exception('Aucun numéro Mobile Money disponible');
      }

      final mobileMoneyNumberId = mobileMoneyNumbers.first['id'] as String;

      final purchaseData = {
        'user_id': driverId,
        'package_id': packageId,
        'token_type': 'course',
        'mobile_money_number_id': mobileMoneyNumberId,
        'token_amount': package.tokenAmount,
        'bonus_tokens': package.discountPercent > 0
            ? (package.tokenAmount * package.discountPercent / 100).round()
            : 0,
        'total_tokens': package.tokenAmount +
            (package.discountPercent > 0
                ? (package.tokenAmount * package.discountPercent / 100).round()
                : 0),
        'price_paid': package.priceXof,
        'sender_phone': senderPhone,
        'transaction_reference': transactionReference,
        'payment_method': 'mobile_money',
        'payment_status': 'pending',
      };

      final response = await _supabase
          .from('token_purchases')
          .insert(purchaseData)
          .select()
          .single();

      debugPrint('[TokenService] Purchase request created: ${response['id']}');
      return TokenPurchase.fromJson(response);
    } catch (e) {
      debugPrint('[TokenService] Error creating purchase request: $e');
      rethrow;
    }
  }

  /// Crée une demande d'achat de jetons (version originale avec numéro visible)
  Future<TokenPurchase> createPurchase({
    required String packageId,
    required String mobileMoneyNumberId,
    required String senderPhone,
    String? transactionReference,
  }) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('User not authenticated');
      }

      // Récupérer le package pour obtenir les détails
      final package = await getPackageById(packageId);
      if (package == null) {
        throw Exception('Package not found');
      }

      final purchaseData = {
        'user_id': driverId,
        'package_id': packageId,
        'token_type': 'course',
        'mobile_money_number_id': mobileMoneyNumberId,
        'token_amount': package.tokenAmount,
        'bonus_tokens': package.discountPercent > 0
            ? (package.tokenAmount * package.discountPercent / 100).round()
            : 0,
        'total_tokens': package.tokenAmount +
            (package.discountPercent > 0
                ? (package.tokenAmount * package.discountPercent / 100).round()
                : 0),
        'price_paid': package.priceXof,
        'sender_phone': senderPhone,
        'transaction_reference': transactionReference,
        'payment_method': 'mobile_money',
        'payment_status': 'pending',
      };

      final response = await _supabase
          .from('token_purchases')
          .insert(purchaseData)
          .select()
          .single();

      debugPrint('[TokenService] Purchase created: ${response['id']}');
      return TokenPurchase.fromJson(response);
    } catch (e) {
      debugPrint('[TokenService] Error creating purchase: $e');
      rethrow;
    }
  }

  /// Met à jour une demande d'achat (ajout de référence ou preuve)
  Future<TokenPurchase> updatePurchase({
    required String purchaseId,
    String? transactionReference,
    String? paymentProofUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (transactionReference != null) {
        updateData['transaction_reference'] = transactionReference;
      }
      if (paymentProofUrl != null) {
        updateData['payment_proof_url'] = paymentProofUrl;
      }

      final response = await _supabase
          .from('token_purchases')
          .update(updateData)
          .eq('id', purchaseId)
          .select()
          .single();

      return TokenPurchase.fromJson(response);
    } catch (e) {
      debugPrint('[TokenService] Error updating purchase: $e');
      rethrow;
    }
  }

  /// Récupère l'historique des achats du chauffeur
  Future<List<TokenPurchase>> getPurchaseHistory({int limit = 50}) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('token_transactions')
          .select()
          .eq('user_id', driverId)
          .eq('token_type', 'course')
          .inFilter('transaction_type', ['purchase', 'spend', 'bonus'])
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => TokenPurchase.fromTransaction(json))
          .toList();
    } catch (e) {
      debugPrint('[TokenService] Error getting purchase history: $e');
      rethrow;
    }
  }

  /// Récupère une demande d'achat spécifique
  Future<TokenPurchase?> getPurchaseById(String purchaseId) async {
    try {
      final response = await _supabase
          .from('token_purchases')
          .select()
          .eq('id', purchaseId)
          .single();

      return TokenPurchase.fromJson(response);
    } catch (e) {
      debugPrint('[TokenService] Error getting purchase: $e');
      return null;
    }
  }

  // =====================================================
  // SOLDE DE JETONS
  // =====================================================

  /// Récupère le solde de jetons du chauffeur
  Future<TokenBalance> getBalance() async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      debugPrint('[TokenService] Getting balance for driver: $driverId');

      if (driverId == null) {
        debugPrint('[TokenService] ERROR: User not authenticated');
        throw Exception('User not authenticated');
      }

      debugPrint('[TokenService] Querying token_balances...');
      final response = await _supabase
          .from('token_balances')
          .select()
          .eq('user_id', driverId)
          .eq('token_type', 'course')
          .maybeSingle();

      debugPrint('[TokenService] Response: $response');

      if (response == null) {
        debugPrint('[TokenService] No balance found, returning empty balance');
        // Aucun solde existant, retourner un solde vide
        return TokenBalance(
          driverId: driverId,
          totalTokens: 0,
          tokensUsed: 0,
          tokensAvailable: 0,
          updatedAt: DateTime.now(),
        );
      }

      // Adapter les données de token_balances au modèle TokenBalance
      final balance = TokenBalance(
        driverId: response['user_id'] as String,
        totalTokens: response['total_purchased'] as int? ?? 0,
        tokensUsed: response['total_spent'] as int? ?? 0,
        tokensAvailable: response['balance'] as int? ?? 0,
        updatedAt: DateTime.parse(response['updated_at'] as String),
      );

      debugPrint(
          '[TokenService] Balance retrieved: ${balance.tokensAvailable} tokens available');
      return balance;
    } catch (e, stackTrace) {
      debugPrint('[TokenService] Error getting balance: $e');
      debugPrint('[TokenService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream du solde de jetons en temps réel
  Stream<TokenBalance> watchBalance() {
    final driverId = _supabase.auth.currentUser?.id;
    debugPrint('[TokenService] Watching balance for driver: $driverId');

    if (driverId == null) {
      debugPrint(
          '[TokenService] ERROR: User not authenticated in watchBalance');
      throw Exception('User not authenticated');
    }

    debugPrint(
        '[TokenService] Starting stream on token_balances for user_id=$driverId, token_type=course');

    return _supabase
        .from('token_balances')
        .stream(primaryKey: ['id']).map((data) {
      debugPrint('[TokenService] Stream data received: $data');

      // Filtrer manuellement les données pour cet utilisateur et ce type
      final filtered = data.where((item) {
        return item['user_id'] == driverId && item['token_type'] == 'course';
      }).toList();

      debugPrint('[TokenService] Filtered data: $filtered');

      if (filtered.isEmpty) {
        debugPrint(
            '[TokenService] Stream data is empty, returning zero balance');
        return TokenBalance(
          driverId: driverId,
          totalTokens: 0,
          tokensUsed: 0,
          tokensAvailable: 0,
          updatedAt: DateTime.now(),
        );
      }

      // Adapter les données de token_balances au modèle TokenBalance
      final balance = filtered.first;
      final tokenBalance = TokenBalance(
        driverId: balance['user_id'] as String,
        totalTokens: balance['total_purchased'] as int? ?? 0,
        tokensUsed: balance['total_spent'] as int? ?? 0,
        tokensAvailable: balance['balance'] as int? ?? 0,
        updatedAt: DateTime.parse(balance['updated_at'] as String),
      );

      debugPrint(
          '[TokenService] Stream returning balance: ${tokenBalance.tokensAvailable} tokens');
      return tokenBalance;
    });
  }

  /// Utilise des jetons (appel de la fonction PostgreSQL)
  Future<bool> useTokens({
    required int tokensToUse,
    required String usageType,
    String? referenceId,
    String? description,
  }) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc('use_driver_tokens', params: {
        'p_driver_id': driverId,
        'p_tokens_to_use': tokensToUse,
        'p_usage_type': usageType,
        'p_reference_id': referenceId,
        'p_description': description,
      });

      return response as bool;
    } catch (e) {
      debugPrint('[TokenService] Error using tokens: $e');
      rethrow;
    }
  }

  // =====================================================
  // VÉRIFICATIONS
  // =====================================================

  /// Vérifie si le chauffeur a assez de jetons
  Future<bool> hasEnoughTokens(int requiredTokens) async {
    try {
      final balance = await getBalance();
      return balance.tokensAvailable >= requiredTokens;
    } catch (e) {
      debugPrint('[TokenService] Error checking token balance: $e');
      return false;
    }
  }

  /// Calcule le coût en jetons d'une action
  int calculateTokenCost({
    required String actionType,
    Map<String, dynamic>? parameters,
  }) {
    // Coûts configurables selon le type d'action
    switch (actionType) {
      case 'trip_offer':
        return 1; // 1 jeton par offre de course
      case 'negotiation':
        return 2; // 2 jetons par négociation
      case 'priority_listing':
        return 5; // 5 jetons pour être en tête de liste
      default:
        return 0;
    }
  }
  // Fin du fichier
}
