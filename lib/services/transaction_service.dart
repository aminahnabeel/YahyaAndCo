import '../db/database_helper.dart';
import '../models/transaction_model.dart';

class TransactionService {

  // =========================
  // CREATE TRANSACTION
  // =========================

  Future<int> createTransaction(
    TransactionModel transaction,
  ) async {

    return await DatabaseHelper
        .instance
        .insertTransaction(
      transaction,
    );
  }

  // =========================
  // GET TRANSACTIONS
  // =========================

  Future<List<TransactionModel>>
      getTransactionsByBusiness(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getTransactionsByBusiness(
      businessId,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionRowsByBusiness(int businessId) async {
    return await DatabaseHelper.instance.getTransactionLedgerRows(businessId);
  }

  Future<TransactionModel?> getTransactionById(int transactionId) async {
    return await DatabaseHelper.instance.getTransactionById(transactionId);
  }

  // =========================
  // UPDATE TRANSACTION
  // =========================

  Future updateTransaction(
    TransactionModel transaction,
  ) async {

    await DatabaseHelper
        .instance
        .updateTransaction(
      transaction,
    );
  }

  // =========================
  // DELETE TRANSACTION
  // =========================

  Future deleteTransaction(
    int transactionId,
  ) async {

    await DatabaseHelper
        .instance
        .deleteTransaction(
      transactionId,
    );
  }
}