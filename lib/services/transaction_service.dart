import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class TransactionService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE TRANSACTION
  // =========================

  Future<int> createTransaction(TransactionModel transaction) async {
    print('📝 TransactionService: Creating transaction...');
    print('   SQLite Business ID: ${transaction.businessId}');
    
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere((b) => b.businessId == transaction.businessId);
    } catch (e) {
      business = null;
    }

    if (business?.firestoreId == null) {
      print('⚠️  Firestore business ID not found');
    } else {
      print('✅ Firestore Business ID: ${business!.firestoreId}');
    }

    return await _syncService.syncOperation<int>(
      sqliteOperation: () async {
        print('💾 Saving to SQLite...');
        return await DatabaseHelper.instance.insertTransaction(transaction);
      },
      firestoreOperation: () async {
        if (business != null && business.firestoreId != null) {
          print('🔥 Syncing to Firestore at path: businesses/${business.firestoreId}/transactions/');
          await _firestoreService.createTransaction(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            accountId: transaction.accountId,
            toAccountId: transaction.toAccountId,
            amount: transaction.amount,
            type: transaction.type,
            note: transaction.note,
            paymentMethod: transaction.paymentMethod,
            dueDate: transaction.dueDate,
            paymentStatus: transaction.paymentStatus,
            remainingAmount: transaction.remainingAmount,
            imageUrl: transaction.imageUrl,
            date: transaction.date,
            createdAt: transaction.createdAt,
          );
        } else {
          throw Exception('Firestore business ID not found');
        }
      },
      operationName: 'Create Transaction',
    );
  }

  // =========================
  // GET TRANSACTIONS
  // =========================

  Future<List<TransactionModel>> getTransactionsByBusiness(
      int businessId) async {
    return await DatabaseHelper.instance.getTransactionsByBusiness(businessId);
  }

  Future<List<Map<String, dynamic>>> getTransactionRowsByBusiness(
      int businessId) async {
    return await DatabaseHelper.instance.getTransactionLedgerRows(businessId);
  }

  Future<TransactionModel?> getTransactionById(int transactionId) async {
    return await DatabaseHelper.instance.getTransactionById(transactionId);
  }

  // =========================
  // UPDATE TRANSACTION
  // =========================

  Future updateTransaction(TransactionModel transaction) async {
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere((b) => b.businessId == transaction.businessId);
    } catch (e) {
      business = null;
    }

    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateTransaction(transaction);
      },
      firestoreOperation: () async {
        if (transaction.transactionId != null && business != null && business.firestoreId != null) {
          print('🔄 Updating transaction in Firestore: businesses/${business.firestoreId}/transactions/${transaction.transactionId}');
          await _firestoreService.updateTransaction(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            transactionId: transaction.transactionId!.toString(),
            amount: transaction.amount,
            type: transaction.type,
            note: transaction.note,
            paymentMethod: transaction.paymentMethod,
            dueDate: transaction.dueDate,
            paymentStatus: transaction.paymentStatus,
            remainingAmount: transaction.remainingAmount,
            imageUrl: transaction.imageUrl,
            date: transaction.date,
          );
        } else {
          print('⚠️  Firestore ID not found - update skipped');
        }
      },
      operationName: 'Update Transaction',
    );
  }

  // =========================
  // DELETE TRANSACTION
  // =========================

  Future deleteTransaction(int transactionId) async {
    // Get transaction to get businessId
    final transaction = await getTransactionById(transactionId);
    if (transaction != null) {
      // Fetch business to get Firestore ID
      final businesses = await DatabaseHelper.instance.getBusinesses();
      BusinessModel? business;
      try {
        business = businesses.firstWhere((b) => b.businessId == transaction.businessId);
      } catch (e) {
        business = null;
      }

      return await _syncService.syncOperation<void>(
        sqliteOperation: () async {
          await DatabaseHelper.instance.deleteTransaction(transactionId);
        },
        firestoreOperation: () async {
          if (business != null && business.firestoreId != null) {
            print('🔄 Deleting transaction from Firestore: businesses/${business.firestoreId}/transactions/$transactionId');
            await _firestoreService.deleteTransaction(
              business.firestoreId!, // ✅ Use Firestore ID
              transactionId.toString(),
            );
          } else {
            print('⚠️  Firestore ID not found - delete skipped');
          }
        },
        operationName: 'Delete Transaction',
      );
    }
  }
}