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

          await _syncDefaultAccountsToFirestore(updatedBusiness);
        }
      } catch (e) {
        print('⚠️  Business created in SQLite, Firestore sync failed: $e');
      }
    }

    return businessId;
  }

  Future<void> _syncDefaultAccountsToFirestore(BusinessModel business) async {
    if (business.firestoreId == null) return;

    final firestoreAccounts = await _firestoreService.getAccountsByBusiness(
      business.firestoreId!,
    );
    final existingNames = firestoreAccounts
        .map(
          (account) => (account['name'] ?? '').toString().trim().toLowerCase(),
        )
        .toSet();

    final localAccounts = await DatabaseHelper.instance.getAccountsByBusiness(
      business.businessId!,
    );

    for (final account in localAccounts) {
      final normalizedName = account.name.trim().toLowerCase();
      if (existingNames.contains(normalizedName)) {
        final matched = firestoreAccounts.firstWhere(
          (item) =>
              (item['name'] ?? '').toString().trim().toLowerCase() ==
              normalizedName,
          orElse: () => <String, dynamic>{},
        );
        final firestoreId = matched['id']?.toString();
        if (firestoreId != null &&
            firestoreId.isNotEmpty &&
            account.accountId != null) {
          await DatabaseHelper.instance.updateAccountFirestoreId(
            account.accountId!,
            firestoreId,
          );
        }
        continue;
      }

      final firestoreId = await _firestoreService.createAccount(
        businessId: business.firestoreId!,
        name: account.name,
        type: account.type,
        phone: account.phone,
        address: account.address,
        openingBalance: account.openingBalance,
        createdAt: account.createdAt,
      );

      if (account.accountId != null) {
        await DatabaseHelper.instance.updateAccountFirestoreId(
          account.accountId!,
          firestoreId,
        );
      }
    }
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
    final firestoreBusinessId = business.firestoreId;

    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.deleteBusiness(businessId);
      },
      firestoreOperation: () async {
        // ✅ Use firestoreId instead of businessId
        if (firestoreBusinessId != null) {
          print('🔄 Deleting business from Firestore: $firestoreBusinessId');
          await _firestoreService.deleteBusiness(firestoreBusinessId);
        } else {
          print('⚠️  Firestore ID not found - Firestore delete skipped');
        }
      },
      operationName: 'Delete Business',
    );
  }
}
