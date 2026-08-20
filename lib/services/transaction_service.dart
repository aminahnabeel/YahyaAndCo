import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/journal_line_model.dart';
import '../models/journal_entry_model.dart';
import '../models/transaction_model.dart';
import 'accounting_service.dart';
import 'firestore_service.dart';
import 'reminder_service.dart';
import 'sync_service.dart';

class TransactionService {
  final FirestoreService _firestoreService = FirestoreService();
  final ReminderService _reminderService = ReminderService();
  final SyncService _syncService = SyncService();
  final AccountingService _accountingService = AccountingService();

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
      business = businesses.firstWhere(
        (b) => b.businessId == transaction.businessId,
      );
    } catch (e) {
      business = null;
    }

    if (business?.firestoreId == null) {
      print('⚠️  Firestore business ID not found');
    } else {
      print('✅ Firestore Business ID: ${business!.firestoreId}');
    }

    final transactionId = await DatabaseHelper.instance.insertTransaction(transaction);

    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        if (business != null && business.firestoreId != null) {
          final account = await DatabaseHelper.instance.getAccountById(transaction.accountId);
          final accountFirestoreId = account == null
              ? null
              : await DatabaseHelper.instance.getAccountFirestoreId(transaction.accountId);
          final toAccount = transaction.toAccountId == null
              ? null
              : await DatabaseHelper.instance.getAccountById(transaction.toAccountId!);
          final toAccountFirestoreId = transaction.toAccountId == null
              ? null
              : await DatabaseHelper.instance.getAccountFirestoreId(transaction.toAccountId!);
          print(
            '🔥 Syncing to Firestore at path: businesses/${business.firestoreId}/transactions/',
          );
          final firestoreTransactionId = await _firestoreService.createTransaction(
            businessId: business.firestoreId!,
            accountId: transaction.accountId,
            toAccountId: transaction.toAccountId,
            accountFirestoreId: accountFirestoreId,
            accountName: account?.name,
            toAccountFirestoreId: toAccountFirestoreId,
            toAccountName: toAccount?.name,
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
          await DatabaseHelper.instance.updateTransactionFirestoreId(
            transactionId,
            firestoreTransactionId,
          );
        } else {
          throw Exception('Firestore business ID not found');
        }
<<<<<<< HEAD
      },
      operationName: 'Create Transaction',
    );

    await _reminderService.refreshReminders(transaction.businessId);
=======
      } catch (e) {
        print('⚠️  Transaction created in SQLite, Firestore sync failed: $e');
      }
    }

>>>>>>> 8c487b1 (Sync Firestore writes and restore flow)
    return transactionId;
  }

  // =========================
  // GET TRANSACTIONS
  // =========================

  Future<List<TransactionModel>> getTransactionsByBusiness(
    int businessId,
  ) async {
    return await DatabaseHelper.instance.getTransactionsByBusiness(businessId);
  }

  Future<List<Map<String, dynamic>>> getTransactionRowsByBusiness(
    int businessId,
  ) async {
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
      business = businesses.firstWhere(
        (b) => b.businessId == transaction.businessId,
      );
    } catch (e) {
      business = null;
    }

    await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateTransaction(transaction);

        final linkedJournal = await DatabaseHelper.instance.getJournalEntryByTransactionId(
          transaction.transactionId!,
        );
        if (linkedJournal != null) {
          final cashAccountId = await _accountingService.getCashAccountId(transaction.businessId);
          if (cashAccountId == null) {
            throw Exception('Cash account not found for transaction update');
          }

          await DatabaseHelper.instance.deleteJournalLines(linkedJournal.journalId!);

          final isDebitSide = transaction.type.toLowerCase() == 'debit';
          final journalLines = <JournalLineModel>[
            JournalLineModel(
              journalId: linkedJournal.journalId!,
              accountId: transaction.accountId,
              debit: isDebitSide ? transaction.amount : 0,
              credit: isDebitSide ? 0 : transaction.amount,
            ),
            JournalLineModel(
              journalId: linkedJournal.journalId!,
              accountId: cashAccountId,
              debit: isDebitSide ? 0 : transaction.amount,
              credit: isDebitSide ? transaction.amount : 0,
            ),
          ];

          for (final line in journalLines) {
            await DatabaseHelper.instance.insertJournalLine(line);
          }

          final updatedJournal = JournalEntryModel(
            journalId: linkedJournal.journalId,
            businessId: linkedJournal.businessId,
            transactionId: linkedJournal.transactionId,
            voucherNo: linkedJournal.voucherNo,
            voucherType: linkedJournal.voucherType,
            description: transaction.note,
            dueDate: transaction.dueDate,
            paymentStatus: transaction.paymentStatus,
            remainingAmount: transaction.remainingAmount,
            imageUrl: transaction.imageUrl,
            date: transaction.date,
            createdAt: linkedJournal.createdAt,
          );
          await DatabaseHelper.instance.updateJournalEntry(updatedJournal);
        }
      },
      firestoreOperation: () async {
        final firestoreTransactionId = transaction.transactionId == null
            ? null
            : await DatabaseHelper.instance.getTransactionFirestoreId(transaction.transactionId!);

        if (firestoreTransactionId != null &&
            business != null &&
            business.firestoreId != null) {
          final account = await DatabaseHelper.instance.getAccountById(transaction.accountId);
          final accountFirestoreId = await DatabaseHelper.instance.getAccountFirestoreId(transaction.accountId);
          final toAccount = transaction.toAccountId == null
              ? null
              : await DatabaseHelper.instance.getAccountById(transaction.toAccountId!);
          final toAccountFirestoreId = transaction.toAccountId == null
              ? null
              : await DatabaseHelper.instance.getAccountFirestoreId(transaction.toAccountId!);
          print(
            '🔄 Updating transaction in Firestore: businesses/${business.firestoreId}/transactions/$firestoreTransactionId',
          );
          await _firestoreService.updateTransaction(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            transactionId: firestoreTransactionId,
            accountId: transaction.accountId,
            accountFirestoreId: accountFirestoreId,
            accountName: account?.name,
            toAccountId: transaction.toAccountId,
            toAccountFirestoreId: toAccountFirestoreId,
            toAccountName: toAccount?.name,
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

          final linkedJournal = transaction.transactionId == null
              ? null
              : await DatabaseHelper.instance.getJournalEntryByTransactionId(transaction.transactionId!);
          if (linkedJournal != null) {
            final firestoreJournalId = await DatabaseHelper.instance.getJournalFirestoreId(linkedJournal.journalId!);
            if (firestoreJournalId != null) {
              final cashAccountId = await _accountingService.getCashAccountId(transaction.businessId);
              if (cashAccountId == null) {
                throw Exception('Cash account not found for transaction update');
              }

              final isDebitSide = transaction.type.toLowerCase() == 'debit';
              final account = await DatabaseHelper.instance.getAccountById(transaction.accountId);
              final cashAccount = await DatabaseHelper.instance.getAccountById(cashAccountId);
              final accountFirestoreId = await DatabaseHelper.instance.getAccountFirestoreId(transaction.accountId);
              final cashAccountFirestoreId = await DatabaseHelper.instance.getAccountFirestoreId(cashAccountId);

              await _firestoreService.deleteJournalLines(
                businessId: business.firestoreId!,
                journalId: firestoreJournalId,
              );

              await _firestoreService.addJournalLines(
                businessId: business.firestoreId!,
                journalId: firestoreJournalId,
                journalLines: [
                  {
                    'account_id': transaction.accountId,
                    'account_firestore_id': accountFirestoreId,
                    'account_name': account?.name,
                    'debit': isDebitSide ? transaction.amount : 0,
                    'credit': isDebitSide ? 0 : transaction.amount,
                  },
                  {
                    'account_id': cashAccountId,
                    'account_firestore_id': cashAccountFirestoreId,
                    'account_name': cashAccount?.name,
                    'debit': isDebitSide ? 0 : transaction.amount,
                    'credit': isDebitSide ? transaction.amount : 0,
                  },
                ],
              );

              await _firestoreService.updateJournalEntry(
                businessId: business.firestoreId!,
                journalId: firestoreJournalId,
                voucherNo: linkedJournal.voucherNo,
                voucherType: linkedJournal.voucherType,
                description: transaction.note,
                dueDate: transaction.dueDate,
                paymentStatus: transaction.paymentStatus,
                remainingAmount: transaction.remainingAmount,
                imageUrl: transaction.imageUrl,
                date: transaction.date,
              );
            }
          }
        } else {
          print('⚠️  Firestore ID not found - update skipped');
        }
      },
      operationName: 'Update Transaction',
      surfaceFirestoreFailure: true,
    );

    await _reminderService.refreshReminders(transaction.businessId);
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
        business = businesses.firstWhere(
          (b) => b.businessId == transaction.businessId,
        );
      } catch (e) {
        business = null;
      }

      return await _syncService.syncOperation<void>(
        sqliteOperation: () async {
          await DatabaseHelper.instance.deleteTransaction(transactionId);
        },
        firestoreOperation: () async {
            final firestoreTransactionId = transaction.transactionId == null
                ? null
                : await DatabaseHelper.instance.getTransactionFirestoreId(transaction.transactionId!);

            if (business != null && business.firestoreId != null && firestoreTransactionId != null) {
            print(
                '🔄 Deleting transaction from Firestore: businesses/${business.firestoreId}/transactions/$firestoreTransactionId',
            );
            await _firestoreService.deleteTransaction(
              business.firestoreId!, // ✅ Use Firestore ID
                firestoreTransactionId,
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
