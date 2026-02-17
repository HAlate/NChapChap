import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pending_token_purchase.dart';

/// Service pour la gestion admin des achats de jetons
/// PHASE 1: Validation manuelle avec interface simplifiée
/// PHASE 2: Intégration webhook SMS pour auto-validation
class AdminTokenService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // RÉCUPÉRATION DES PAIEMENTS EN ATTENTE
  // =====================================================

  /// Récupère tous les paiements en attente de validation
  /// Utilise la view pending_token_purchases créée en SQL
  Future<List<PendingTokenPurchase>> getPendingPurchases() async {
    try {
      debugPrint('[AdminTokenService] Fetching pending purchases...');

      final response = await _supabase
          .from('pending_token_purchases')
          .select()
          .order('created_at', ascending: false);

      final purchases = (response as List)
          .map((json) => PendingTokenPurchase.fromJson(json))
          .toList();

      debugPrint(
          '[AdminTokenService] Found ${purchases.length} pending purchases');
      return purchases;
    } catch (e) {
      debugPrint('[AdminTokenService] Error fetching pending purchases: $e');
      rethrow;
    }
  }

  /// Stream en temps réel des paiements en attente
  /// Mise à jour automatique quand un nouveau paiement arrive
  Stream<List<PendingTokenPurchase>> watchPendingPurchases() {
    debugPrint('[AdminTokenService] Starting real-time watch...');

    return _supabase
        .from('pending_token_purchases')
        .stream(primaryKey: ['id']).map((data) {
      debugPrint('[AdminTokenService] Stream update: ${data.length} purchases');

      return (data as List)
          .map((json) => PendingTokenPurchase.fromJson(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Récupère les statistiques des paiements
  Future<Map<String, int>> getPurchaseStats() async {
    try {
      final response = await _supabase
          .from('token_purchases')
          .select('status')
          .gte('created_at',
              DateTime.now().subtract(Duration(days: 7)).toIso8601String());

      final data = response as List;

      final stats = <String, int>{
        'pending': 0,
        'completed': 0,
        'failed': 0,
        'cancelled': 0,
      };

      for (final item in data) {
        final status = item['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('[AdminTokenService] Error fetching stats: $e');
      return {};
    }
  }

  // =====================================================
  // VALIDATION & REJET
  // =====================================================

  /// Valide un paiement et crédite les jetons au chauffeur
  /// Appelle la fonction SQL validate_token_purchase()
  Future<bool> validatePurchase({
    required String purchaseId,
    String? adminNotes,
  }) async {
    try {
      debugPrint('[AdminTokenService] Validating purchase: $purchaseId');

      final notes = adminNotes ??
          'Validé manuellement à ${DateTime.now().toIso8601String()}';

      await _supabase.rpc('validate_token_purchase', params: {
        'p_purchase_id': purchaseId,
        'p_admin_notes': notes,
      });

      debugPrint('[AdminTokenService] Purchase validated successfully');
      return true;
    } catch (e) {
      debugPrint('[AdminTokenService] Error validating purchase: $e');
      rethrow;
    }
  }

  /// Rejette/annule un paiement
  /// Appelle la fonction SQL cancel_token_purchase()
  Future<bool> rejectPurchase({
    required String purchaseId,
    required String reason,
  }) async {
    try {
      debugPrint('[AdminTokenService] Rejecting purchase: $purchaseId');

      await _supabase.rpc('cancel_token_purchase', params: {
        'p_purchase_id': purchaseId,
        'p_reason': reason,
      });

      debugPrint('[AdminTokenService] Purchase rejected successfully');
      return true;
    } catch (e) {
      debugPrint('[AdminTokenService] Error rejecting purchase: $e');
      rethrow;
    }
  }

  // =====================================================
  // VALIDATION PAR LOT (utile pour Phase 2)
  // =====================================================

  /// Valide plusieurs paiements en une seule opération
  Future<Map<String, dynamic>> validateMultiplePurchases({
    required List<String> purchaseIds,
    String? adminNotes,
  }) async {
    try {
      debugPrint(
          '[AdminTokenService] Validating ${purchaseIds.length} purchases...');

      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final purchaseId in purchaseIds) {
        try {
          await validatePurchase(
            purchaseId: purchaseId,
            adminNotes: adminNotes,
          );
          successCount++;
        } catch (e) {
          failureCount++;
          errors.add('$purchaseId: $e');
        }
      }

      debugPrint(
          '[AdminTokenService] Batch validation: $successCount success, $failureCount failed');

      return {
        'success': successCount,
        'failed': failureCount,
        'errors': errors,
      };
    } catch (e) {
      debugPrint('[AdminTokenService] Error in batch validation: $e');
      rethrow;
    }
  }

  // =====================================================
  // MATCHING SMS (préparation Phase 2)
  // =====================================================

  /// Recherche un paiement correspondant à un SMS reçu
  /// Utilisé pour l'auto-validation future
  Future<PendingTokenPurchase?> findMatchingPurchase({
    required int amount,
    String? senderPhone,
    Duration timeWindow = const Duration(minutes: 30),
  }) async {
    try {
      debugPrint(
          '[AdminTokenService] Searching matching purchase: $amount F from $senderPhone');

      final cutoffTime = DateTime.now().subtract(timeWindow).toIso8601String();

      final query = _supabase
          .from('pending_token_purchases')
          .select()
          .eq('total_amount', amount)
          .eq('status', 'pending')
          .gte('created_at', cutoffTime)
          .order('created_at', ascending: false);

      // Si numéro de téléphone fourni, filtrer aussi par celui-ci
      final response = await query;

      if (response.isEmpty) {
        debugPrint('[AdminTokenService] No matching purchase found');
        return null;
      }

      // Si plusieurs correspondances, prendre la plus récente
      final matches = (response as List)
          .map((json) => PendingTokenPurchase.fromJson(json))
          .toList();

      // Filtrage additionnel par téléphone si fourni
      if (senderPhone != null) {
        final phoneMatches = matches.where((p) {
          return p.driverPhone != null &&
              p.driverPhone!.replaceAll(RegExp(r'\s+'), '').contains(senderPhone
                  .replaceAll(RegExp(r'\s+'), '')
                  .substring(
                      senderPhone.length > 8 ? senderPhone.length - 8 : 0));
        }).toList();

        if (phoneMatches.isNotEmpty) {
          debugPrint(
              '[AdminTokenService] Found phone match: ${phoneMatches.first}');
          return phoneMatches.first;
        }
      }

      debugPrint('[AdminTokenService] Found amount match: ${matches.first}');
      return matches.first;
    } catch (e) {
      debugPrint('[AdminTokenService] Error finding matching purchase: $e');
      return null;
    }
  }

  /// Auto-valide un paiement basé sur un SMS reçu (Phase 2)
  /// Retourne true si un paiement a été trouvé et validé
  Future<bool> autoValidateFromSms({
    required int amount,
    required String senderPhone,
    required DateTime receivedAt,
  }) async {
    try {
      debugPrint('[AdminTokenService] Auto-validation from SMS: $amount F');

      final purchase = await findMatchingPurchase(
        amount: amount,
        senderPhone: senderPhone,
        timeWindow: Duration(minutes: 30),
      );

      if (purchase == null) {
        debugPrint(
            '[AdminTokenService] No matching purchase for auto-validation');
        return false;
      }

      await validatePurchase(
        purchaseId: purchase.id,
        adminNotes:
            'Auto-validé via SMS de $senderPhone à ${receivedAt.toIso8601String()}',
      );

      debugPrint('[AdminTokenService] Auto-validation successful!');
      return true;
    } catch (e) {
      debugPrint('[AdminTokenService] Error in auto-validation: $e');
      return false;
    }
  }
}
