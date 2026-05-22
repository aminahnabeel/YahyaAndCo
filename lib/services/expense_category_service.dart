import '../db/database_helper.dart';
import '../models/expense_category_model.dart';

class ExpenseCategoryService {

  // =========================
  // CREATE CATEGORY
  // =========================

  Future<int>
      createExpenseCategory(
    ExpenseCategoryModel category,
  ) async {

    return await DatabaseHelper
        .instance
        .insertExpenseCategory(
      category,
    );
  }

  // =========================
  // GET CATEGORIES
  // =========================

  Future<List<ExpenseCategoryModel>>
      getExpenseCategories(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getExpenseCategories(
      businessId,
    );
  }
}