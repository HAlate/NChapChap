import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour le service de statut du chauffeur.
final driverStatusServiceProvider = Provider((ref) => DriverStatusService(ref));

class DriverStatusService {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  DriverStatusService(this._ref);

  /// Met à jour le statut du chauffeur dans la base de données.
  Future<void> updateOnlineStatusInDb(bool isOnline) async {
    final driverId = _supabase.auth.currentUser?.id;
    if (driverId == null) return;

    await _supabase
        .from('driver_profiles')
        .update({'is_online': isOnline}).eq('id', driverId);
  }
}
