import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/token_package.dart';
import '../models/mobile_money_account.dart';

class TokenPurchaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<TokenPackage>> getPackagesByType(String tokenType) async {
    try {
      final response = await _supabase
          .from('token_packages')
          .select()
          .eq('token_type', tokenType)
          .eq('is_active', true)
          .order('price_F CFA');

      return (response as List)
          .map((json) => TokenPackage.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des packs: $e');
    }
  }

  Future<List<MobileMoneyAccount>> getMobileMoneyAccounts(
      String countryCode) async {
    try {
      final response = await _supabase
          .from('mobile_money_accounts')
          .select('''
            *,
            mobile_money_providers (
              id,
              name,
              short_name,
              logo_url,
              ussd_code
            )
          ''')
          .eq('country_code', countryCode)
          .eq('is_active', true)
          .order('is_primary', ascending: false);

      return (response as List)
          .map((json) => MobileMoneyAccount.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des comptes Mobile Money: $e');
    }
  }

  Future<int> getTokenBalance(String userId, String tokenType) async {
    try {
      final response = await _supabase
          .from('token_balances')
          .select('balance')
          .eq('user_id', userId)
          .eq('token_type', tokenType)
          .maybeSingle();

      if (response == null) return 0;
      return response['balance'] as int? ?? 0;
    } catch (e) {
      throw Exception('Erreur lors du chargement du solde: $e');
    }
  }

  Future<Map<String, dynamic>> createPurchase({
    required String userId,
    required String packageId,
    required String tokenType,
    required int tokenAmount,
    required int pricePaid,
    required String currencyCode,
    required String momoAccountId,
    required String senderPhone,
    required String senderName,
    required String externalTransactionId,
  }) async {
    try {
      // Créer purchase
      final purchaseResponse = await _supabase
          .from('token_purchases')
          .insert({
            'user_id': userId,
            'package_id': packageId,
            'token_type': tokenType,
            'token_amount': tokenAmount,
            'price_paid': pricePaid,
            'currency_code': currencyCode,
            'payment_method': 'mobile_money',
            'payment_status': 'pending',
          })
          .select()
          .single();

      final purchaseId = purchaseResponse['id'] as String;

      // Générer référence transaction
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final transactionRef = 'TXN-$timestamp-${userId.substring(0, 6)}';

      // Créer transaction
      final transactionResponse = await _supabase
          .from('payment_transactions')
          .insert({
            'purchase_id': purchaseId,
            'user_id': userId,
            'amount': pricePaid,
            'currency_code': currencyCode,
            'payment_method': 'mobile_money',
            'momo_account_id': momoAccountId,
            'sender_phone': senderPhone,
            'sender_name': senderName,
            'transaction_ref': transactionRef,
            'external_transaction_id': externalTransactionId,
            'status': 'pending',
          })
          .select()
          .single();

      return {
        'success': true,
        'purchase_id': purchaseId,
        'transaction_ref': transactionRef,
        'transaction_id': transactionResponse['id'],
      };
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'achat: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseHistory(String userId) async {
    try {
      final response = await _supabase
          .from('token_purchases')
          .select('''
            *,
            token_packages (
              name,
              description
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Erreur lors du chargement de l\'historique: $e');
    }
  }

  Future<Map<String, dynamic>?> getPendingPurchase(String userId) async {
    try {
      final response = await _supabase
          .from('token_purchases')
          .select('''
            *,
            token_packages (
              name
            )
          ''')
          .eq('user_id', userId)
          .eq('payment_status', 'pending')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }
}
