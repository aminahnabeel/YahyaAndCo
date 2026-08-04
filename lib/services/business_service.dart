import '../db/database_helper.dart';
import '../models/business_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class BusinessService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE BUSINESS
  // =========================

  Future<int> createBusiness(BusinessModel business) async {
    // Step 1: Create in SQLite
    final businessId = await DatabaseHelper.instance.insertBusiness(business);
    
    // Step 2: Create in Firestore and capture the document ID
    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        final uid = _firestoreService.getCurrentUserUid();
        if (uid != null) {
          final firestoreDocId = await _firestoreService.createBusiness(
            firebaseUid: uid,
            name: business.name,
            type: business.type,
            pin: business.pin,
            createdAt: business.createdAt,
          );
          
          print('📝 Firestore business created with ID: $firestoreDocId');
          
          // Step 3: Update the business record with the Firestore ID
          final updatedBusiness = BusinessModel(
            businessId: businessId,
            firestoreId: firestoreDocId, // ✅ Store the Firestore ID
            name: business.name,
            type: business.type,
            pin: business.pin,
            createdAt: business.createdAt,
          );
          
          await DatabaseHelper.instance.updateBusiness(updatedBusiness);
          print('✅ Firestore ID stored in SQLite: $firestoreDocId');
        }
      } catch (e) {
        print('⚠️  Business created in SQLite, Firestore sync failed: $e');
      }
    }
    
    return businessId;
  }

  // =========================
  // GET ALL BUSINESSES
  // =========================

  Future<List<BusinessModel>> getBusinesses() async {
    return await DatabaseHelper.instance.getBusinesses();
  }

  // =========================
  // UPDATE BUSINESS
  // =========================

  Future updateBusiness(BusinessModel business) async {
    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateBusiness(business);
      },
      firestoreOperation: () async {
        // ✅ Use firestoreId instead of businessId
        if (business.firestoreId != null) {
          print('🔄 Updating business in Firestore: ${business.firestoreId}');
          await _firestoreService.updateBusiness(
            businessId: business.firestoreId!, // Use Firestore ID
            name: business.name,
            type: business.type,
            pin: business.pin,
          );
        } else {
          print('⚠️  Firestore ID not found - update skipped');
        }
      },
      operationName: 'Update Business',
    );
  }

  // =========================
  // DELETE BUSINESS
  // =========================

  Future deleteBusiness(int businessId) async {
    // Fetch the business to get firestoreId
    final businesses = await DatabaseHelper.instance.getBusinesses();
    final business = businesses.firstWhere(
      (b) => b.businessId == businessId,
      orElse: () => BusinessModel(name: '', type: '', createdAt: ''),
    );

    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.deleteBusiness(businessId);
      },
      firestoreOperation: () async {
        // ✅ Use firestoreId instead of businessId
        if (business.firestoreId != null) {
          print('🔄 Deleting business from Firestore: ${business.firestoreId}');
          await _firestoreService.deleteBusiness(business.firestoreId!);
        } else {
          print('⚠️  Firestore ID not found - Firestore delete skipped');
        }
      },
      operationName: 'Delete Business',
    );
  }
}