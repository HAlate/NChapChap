import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class StripeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _functionsUrl =
      'https://lpbfemncwasppngjmubn.supabase.co/functions/v1';

  /// Initialize Stripe with publishable key
  static Future<void> initialize(String publishableKey) async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Create a Payment Intent via Supabase Edge Function
  Future<Map<String, dynamic>> createPaymentIntent({
    required String packageId,
    String currency = 'usd',
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_functionsUrl/stripe-create-payment-intent'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'packageId': packageId,
          'currency': currency,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to create payment intent');
      }

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  /// Present Payment Sheet and process payment
  Future<bool> presentPaymentSheet({
    required String clientSecret,
    required BuildContext context,
  }) async {
    try {
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'UUMO',
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.orange,
            ),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Colors.orange,
                  text: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );

      // Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        // User canceled the payment
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement annulé')),
        );
        return false;
      } else {
        // Other error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de paiement: ${e.error.message}')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      return false;
    }
  }

  /// Complete purchase flow (create payment intent + present sheet)
  Future<bool> purchaseTokens({
    required BuildContext context,
    required String packageId,
    String currency = 'usd',
  }) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      // Create payment intent
      final paymentData = await createPaymentIntent(
        packageId: packageId,
        currency: currency,
      );

      // Close loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Present payment sheet
      final success = await presentPaymentSheet(
        clientSecret: paymentData['clientSecret'],
        context: context,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Paiement réussi! ${paymentData['tokenAmount']} jetons ajoutés',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      return success;
    } catch (e) {
      // Close loading if still open
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Get payment history for current user
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('stripe_payment_intents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get payment history: $e');
    }
  }

  /// Check payment status
  Future<Map<String, dynamic>> getPaymentStatus(String paymentIntentId) async {
    try {
      final response = await _supabase
          .from('stripe_payment_intents')
          .select()
          .eq('payment_intent_id', paymentIntentId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get payment status: $e');
    }
  }

  /// Stream payment updates (real-time)
  Stream<Map<String, dynamic>> watchPaymentStatus(String paymentIntentId) {
    return _supabase
        .from('stripe_payment_intents')
        .stream(primaryKey: ['id'])
        .eq('payment_intent_id', paymentIntentId)
        .map((data) => data.first);
  }

  /// Format currency amount (cents to display)
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
