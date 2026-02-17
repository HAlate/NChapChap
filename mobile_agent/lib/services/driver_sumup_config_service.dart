import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage driver SumUp configuration
class DriverSumUpConfigService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current driver's SumUp affiliate key
  Future<String?> getAffiliateKey() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('driver_profiles')
          .select('sumup_affiliate_key')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return response['sumup_affiliate_key'] as String?;
    } catch (e) {
      print('Error getting SumUp affiliate key: $e');
      return null;
    }
  }

  /// Save the driver's SumUp affiliate key
  Future<void> saveAffiliateKey(String affiliateKey) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('driver_profiles')
          .update({'sumup_affiliate_key': affiliateKey}).eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to save SumUp key: $e');
    }
  }

  /// Remove the driver's SumUp affiliate key
  Future<void> removeAffiliateKey() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('driver_profiles')
          .update({'sumup_affiliate_key': null}).eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove SumUp key: $e');
    }
  }

  /// Check if the current driver has a SumUp key configured
  Future<bool> hasAffiliateKey() async {
    final key = await getAffiliateKey();
    return key != null && key.isNotEmpty;
  }
}
