import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/expense_category_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class ExpenseCategoryService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE CATEGORY
  // =========================

  Future<int> createExpenseCategory(
    ExpenseCategoryModel category,
  ) async {
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere((b) => b.businessId == category.businessId);
    } catch (e) {
      business = null;
    }

    return await _syncService.syncOperation<int>(
      sqliteOperation: () async {
        return await DatabaseHelper.instance.insertExpenseCategory(category);
      },
      firestoreOperation: () async {
        if (business != null && business.firestoreId != null) {
          print('🔥 Creating expense category in Firestore: businesses/${business.firestoreId}/expense_categories/');
          await _firestoreService.createExpenseCategory(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            name: category.name,
          );
        }
      },
      operationName: 'Create Expense Category',
    );
  }

  // =========================
  // GET CATEGORIES
  // =========================

  Future<List<ExpenseCategoryModel>> getExpenseCategories(
    int businessId,
  ) async {
    return await DatabaseHelper.instance.getExpenseCategories(businessId);
  }
}