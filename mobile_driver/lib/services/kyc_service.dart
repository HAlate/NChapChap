import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kyc_document.dart';
import '../core/constants/kyc_types.dart';

class KYCService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's KYC status from driver profile
  Future<Map<String, dynamic>> getKYCStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('driver_profiles')
          .select('kyc_status, kyc_completed_at, kyc_expiry_date')
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get KYC status: $e');
    }
  }

  /// Get all submitted KYC documents for current user
  Future<List<KycDocument>> getDocuments() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('driver_kyc_documents')
          .select()
          .eq('driver_id', userId)
          .order('submitted_at', ascending: false);

      return (response as List)
          .map((doc) => KycDocument.fromJson(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get documents: $e');
    }
  }

  /// Upload a document image to Supabase Storage and create database record
  Future<KycDocument> uploadDocument({
    required KycDocumentType documentType,
    required File imageFile,
    File? backImageFile,
    File? selfieFile,
    String? documentNumber,
    DateTime? expiryDate,
    Map<String, dynamic>? microblinkData,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload front image
      final frontFileName =
          '${userId}_${documentType.value}_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final frontPath = await _supabase.storage
          .from('kyc-documents')
          .upload(frontFileName, imageFile);

      final frontImageUrl =
          _supabase.storage.from('kyc-documents').getPublicUrl(frontFileName);

      // Upload back image if provided
      String? backImageUrl;
      if (backImageFile != null) {
        final backFileName =
            '${userId}_${documentType.value}_back_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('kyc-documents')
            .upload(backFileName, backImageFile);

        backImageUrl =
            _supabase.storage.from('kyc-documents').getPublicUrl(backFileName);
      }

      // Upload selfie if provided
      String? selfieUrl;
      if (selfieFile != null) {
        final selfieFileName =
            '${userId}_selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('kyc-documents')
            .upload(selfieFileName, selfieFile);

        selfieUrl = _supabase.storage
            .from('kyc-documents')
            .getPublicUrl(selfieFileName);
      }

      // Create database record
      final documentData = {
        'driver_id': userId,
        'document_type': documentType.value,
        'document_number': documentNumber,
        'expiry_date': expiryDate?.toIso8601String(),
        'front_image_url': frontImageUrl,
        'back_image_url': backImageUrl,
        'selfie_url': selfieUrl,
        'microblink_data': microblinkData,
        'verification_status': 'pending',
      };

      final response = await _supabase
          .from('driver_kyc_documents')
          .insert(documentData)
          .select()
          .single();

      return KycDocument.fromJson(response);
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Check if user can accept trips (KYC approved and not expired)
  Future<bool> canAcceptTrips() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final response = await _supabase
          .rpc('can_driver_accept_trips', params: {'p_driver_id': userId});

      return response == true;
    } catch (e) {
      print('Error checking if driver can accept trips: $e');
      return false;
    }
  }

  /// Get required document types that haven't been approved yet
  Future<List<KycDocumentType>> getMissingDocuments() async {
    try {
      final documents = await getDocuments();

      // Required documents
      final requiredTypes = [
        KycDocumentType.nationalId, // or passport
        KycDocumentType.driversLicense,
        KycDocumentType.selfie,
      ];

      // Get approved document types
      final approvedTypes = documents
          .where((doc) => doc.verificationStatus == KycStatus.approved)
          .map((doc) => doc.documentType)
          .toSet();

      // Check if national_id OR passport is approved
      final hasIdentityDoc =
          approvedTypes.contains(KycDocumentType.nationalId) ||
              approvedTypes.contains(KycDocumentType.passport);

      final missing = <KycDocumentType>[];

      if (!hasIdentityDoc) {
        missing.add(KycDocumentType.nationalId);
      }

      if (!approvedTypes.contains(KycDocumentType.driversLicense)) {
        missing.add(KycDocumentType.driversLicense);
      }

      if (!approvedTypes.contains(KycDocumentType.selfie)) {
        missing.add(KycDocumentType.selfie);
      }

      return missing;
    } catch (e) {
      throw Exception('Failed to get missing documents: $e');
    }
  }

  /// Delete a document (only if not approved)
  Future<void> deleteDocument(String documentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get document to check ownership and status
      final doc = await _supabase
          .from('driver_kyc_documents')
          .select()
          .eq('id', documentId)
          .eq('driver_id', userId)
          .single();

      if (doc['verification_status'] == 'approved') {
        throw Exception('Cannot delete approved documents');
      }

      // Delete from database (images will be cleaned up separately if needed)
      await _supabase
          .from('driver_kyc_documents')
          .delete()
          .eq('id', documentId)
          .eq('driver_id', userId);
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  /// Stream KYC status changes
  Stream<Map<String, dynamic>> watchKYCStatus() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _supabase
        .from('driver_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.first);
  }

  /// Stream document changes
  Stream<List<KycDocument>> watchDocuments() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _supabase
        .from('driver_kyc_documents')
        .stream(primaryKey: ['id'])
        .eq('driver_id', userId)
        .order('submitted_at', ascending: false)
        .map((data) => data.map((doc) => KycDocument.fromJson(doc)).toList());
  }
}
