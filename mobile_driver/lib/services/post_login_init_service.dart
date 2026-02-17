import 'package:flutter/material.dart';
import '../services/sumup_service.dart';
import '../services/driver_sumup_config_service.dart';

/// Service to handle post-login initialization tasks
class PostLoginInitService {
  final DriverSumUpConfigService _sumupConfigService =
      DriverSumUpConfigService();

  /// Initialize driver-specific services after successful login
  Future<void> initializeDriverServices() async {
    await _initializeSumUp();
  }

  /// Initialize SumUp with driver's individual affiliate key
  Future<void> _initializeSumUp() async {
    try {
      final affiliateKey = await _sumupConfigService.getAffiliateKey();

      if (affiliateKey != null && affiliateKey.isNotEmpty) {
        final isInitialized = await SumUpService.initialize(
          affiliateKey: affiliateKey,
        );

        if (isInitialized) {
          debugPrint('✅ SumUp initialized for driver - Card payments enabled');
        } else {
          debugPrint(
              '⚠️ SumUp initialization failed for driver - Card payments disabled');
        }
      } else {
        debugPrint(
            'ℹ️ Driver has no SumUp key configured - Card payments disabled');
      }
    } catch (e) {
      debugPrint('Error initializing driver SumUp: $e');
    }
  }

  /// Re-initialize SumUp (useful after driver updates their key)
  Future<void> reinitializeSumUp() async {
    SumUpService.reset();
    await _initializeSumUp();
  }

  /// Clean up on logout
  void cleanup() {
    SumUpService.reset();
    debugPrint('Driver services cleaned up');
  }
}
