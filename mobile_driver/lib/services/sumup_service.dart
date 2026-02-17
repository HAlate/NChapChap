import 'package:flutter/material.dart';
import 'package:sumup/sumup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SumUpService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static bool _isInitialized = false;
  static String? _currentAffiliateKey;

  /// Initialize SumUp SDK with driver's individual affiliate key (OPTIONAL)
  static Future<bool> initialize({
    required String affiliateKey,
  }) async {
    // If already initialized with the same key, return true
    if (_isInitialized && _currentAffiliateKey == affiliateKey) {
      return true;
    }

    // If initialized with different key, need to re-initialize
    _isInitialized = false;
    _currentAffiliateKey = null;

    try {
      await Sumup.init(affiliateKey);
      _isInitialized = true;
      _currentAffiliateKey = affiliateKey;
      print('SumUp SDK initialized with affiliate key');
      return true;
    } catch (e) {
      print('Error initializing SumUp: $e');
      // Don't throw - SumUp is optional
      return false;
    }
  }

  /// Reset SumUp initialization (useful when driver logs out)
  static void reset() {
    _isInitialized = false;
    _currentAffiliateKey = null;
    print('SumUp SDK reset');
  }

  /// Check if SumUp is available and ready
  static bool get isAvailable => _isInitialized;

  /// Check if SumUp is ready to process payments
  Future<bool> isReady() async {
    try {
      final isLoggedIn = await Sumup.isLoggedIn;
      return isLoggedIn ?? false;
    } catch (e) {
      print('Error checking SumUp status: $e');
      return false;
    }
  }

  /// Login to SumUp (opens SumUp app or web)
  Future<bool> login() async {
    try {
      final result = await Sumup.login();
      return result != null;
    } catch (e) {
      print('Error logging in to SumUp: $e');
      return false;
    }
  }

  /// Prepare payment in database
  Future<Map<String, dynamic>> preparePayment({
    required String tripId,
    required double amountUsd,
    int tipPercentage = 0,
  }) async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('Driver not authenticated');
      }

      // Get trip details
      final trip = await _supabase
          .from('trips')
          .select('rider_id, distance_km')
          .eq('id', tripId)
          .single();

      // Calculate amounts in cents
      final baseAmountCents = (amountUsd * 100).round();
      final tipAmountCents = (baseAmountCents * tipPercentage / 100).round();

      // Create SumUp transaction in database
      final response = await _supabase.rpc('create_sumup_transaction', params: {
        'p_trip_id': tripId,
        'p_driver_id': driverId,
        'p_rider_id': trip['rider_id'],
        'p_amount_cents': baseAmountCents,
        'p_currency': 'usd',
        'p_tip_amount_cents': tipAmountCents,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to prepare payment: $e');
    }
  }

  /// Process card payment via SumUp
  Future<bool> processPayment({
    required BuildContext context,
    required String transactionCode,
    required double totalAmount,
    String currency = 'USD',
    String? title,
  }) async {
    try {
      // Check if logged in
      final isLoggedIn = await isReady();
      if (!isLoggedIn) {
        final loginSuccess = await login();
        if (!loginSuccess) {
          throw Exception('Failed to login to SumUp');
        }
      }

      // Create payment request
      final payment = SumupPayment(
        total: totalAmount,
        currency: currency,
        title: title ?? 'Course UUMO',
      );

      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          ),
        );
      }

      // Process payment through SumUp
      final response = await Sumup.checkout(SumupPaymentRequest(payment));

      // Close loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (response.success == true) {
        // Payment successful - confirm in database
        await confirmPayment(
          transactionCode: transactionCode,
          sumupTransactionId: response.transactionCode ?? '',
          cardType: null, // Card details not available in response
          cardLast4: null,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paiement réussi!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } else {
        // Payment failed
        await failPayment(
          transactionCode: transactionCode,
          errorMessage: 'Payment failed',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Paiement échoué'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      // Close loading if still open
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Mark as failed in database
      try {
        await failPayment(
          transactionCode: transactionCode,
          errorMessage: e.toString(),
        );
      } catch (_) {}

      return false;
    }
  }

  /// Confirm payment in database
  Future<void> confirmPayment({
    required String transactionCode,
    required String sumupTransactionId,
    String? cardType,
    String? cardLast4,
  }) async {
    try {
      await _supabase.rpc('confirm_sumup_transaction', params: {
        'p_transaction_code': transactionCode,
        'p_sumup_transaction_id': sumupTransactionId,
        'p_card_type': cardType,
        'p_card_last4': cardLast4,
      });
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  /// Mark payment as failed in database
  Future<void> failPayment({
    required String transactionCode,
    String? errorMessage,
  }) async {
    try {
      await _supabase.rpc('fail_sumup_transaction', params: {
        'p_transaction_code': transactionCode,
        'p_error_message': errorMessage,
      });
    } catch (e) {
      print('Failed to mark payment as failed: $e');
    }
  }

  /// Complete trip (payment already done between driver and rider)
  /// Token was already deducted when offer was accepted
  Future<void> completeTrip({
    required String tripId,
  }) async {
    try {
      await _supabase.from('trips').update({
        'status': 'completed',
        'payment_method': 'cash', // Default: cash payment
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to complete trip: $e');
    }
  }

  /// Calculate trip cost
  Future<Map<String, dynamic>> calculateTripCost({
    required String tripId,
    int tipPercentage = 0,
  }) async {
    try {
      final response = await _supabase.rpc('calculate_trip_amount', params: {
        'p_trip_id': tripId,
        'p_tip_percentage': tipPercentage,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to calculate trip cost: $e');
    }
  }

  /// Get payment history for driver
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final driverId = _supabase.auth.currentUser?.id;
      if (driverId == null) {
        throw Exception('Driver not authenticated');
      }

      final response = await _supabase
          .from('sumup_transactions')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get payment history: $e');
    }
  }

  /// Get specific transaction status
  Future<Map<String, dynamic>> getTransactionStatus(
      String transactionCode) async {
    try {
      final response = await _supabase
          .from('sumup_transactions')
          .select()
          .eq('transaction_code', transactionCode)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get transaction status: $e');
    }
  }

  /// Open SumUp settings
  Future<void> openSettings() async {
    try {
      await Sumup.openSettings();
    } catch (e) {
      print('Error opening SumUp settings: $e');
      rethrow;
    }
  }

  /// Logout from SumUp
  Future<bool> logout() async {
    try {
      final result = await Sumup.logout();
      return result != null;
    } catch (e) {
      print('Error logging out from SumUp: $e');
      return false;
    }
  }

  /// Format amount for display
  static String formatAmount(int amountCents, String currency) {
    final amount = amountCents / 100;
    switch (currency.toLowerCase()) {
      case 'usd':
        return '\$${amount.toStringAsFixed(2)}';
      case 'fcfa':
        return 'F${amount.toStringAsFixed(2)}';
      case 'gbp':
        return '£${amount.toStringAsFixed(2)}';
      default:
        return '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}';
    }
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currency) {
    switch (currency.toLowerCase()) {
      case 'usd':
        return '\$';
      case 'fcfa':
        return 'F';
      case 'gbp':
        return '£';
      default:
        return currency.toUpperCase();
    }
  }
}
