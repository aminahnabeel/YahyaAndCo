import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import 'firestore_service.dart';
import 'reminder_service.dart';
import 'sync_service.dart';

class JournalService {
  final FirestoreService _firestoreService = FirestoreService();
  final ReminderService _reminderService = ReminderService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE JOURNAL ENTRY
  // =========================

  Future<int> createJournalEntry(
    int businessId,
    String voucher,
    String date,
    String description,
  ) async {
    final journal = JournalEntryModel(
      businessId: businessId,
      voucherNo: voucher,
      voucherType: 'JV',
      date: date,
      description: description,
      createdAt: DateTime.now().toIso8601String(),
    );

    print('📝 JournalService: Creating journal entry...');
    print('   SQLite Business ID: $businessId, Voucher: $voucher');

    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere((b) => b.businessId == businessId);
    } catch (e) {
      business = null;
    }

    if (business?.firestoreId == null) {
      print('⚠️  Firestore business ID not found');
    } else {
      print('✅ Firestore Business ID: ${business!.firestoreId}');
    }

    final journalId = await DatabaseHelper.instance.insertJournalEntry(journal);

    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        if (business != null && business.firestoreId != null) {
          print(
            '🔥 Syncing journal to Firestore at path: businesses/${business.firestoreId}/journal_entries/',
          );
          final firestoreJournalId = await _firestoreService.createJournalEntry(
            businessId: business.firestoreId!,
            transactionId: null,
            voucherNo: voucher,
            voucherType: 'JV',
            description: description,
            dueDate: null,
            paymentStatus: 'Paid',
            remainingAmount: 0,
            imageUrl: null,
            date: date,
            createdAt: journal.createdAt,
          );
          await DatabaseHelper.instance.updateJournalFirestoreId(
            journalId,
            firestoreJournalId,
          );
        } else {
          throw Exception('Firestore business ID not found');
        }
<<<<<<< HEAD
      },
      operationName: 'Create Journal Entry',
    );

    await _reminderService.refreshReminders(businessId);
=======
      } catch (e) {
        print('⚠️  Journal saved to SQLite, Firestore sync failed: $e');
      }
    }

>>>>>>> 8c487b1 (Sync Firestore writes and restore flow)
    return journalId;
  }

  // =========================
  // UPDATE JOURNAL ENTRY
  // =========================

  Future updateJournalEntry(JournalEntryModel journal) async {
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere(
        (b) => b.businessId == journal.businessId,
      );
    } catch (e) {
      business = null;
    }

    await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateJournalEntry(journal);
      },
      firestoreOperation: () async {
        final firestoreJournalId = journal.journalId == null
            ? null
            : await DatabaseHelper.instance.getJournalFirestoreId(journal.journalId!);

        if (firestoreJournalId != null &&
            business != null &&
            business.firestoreId != null) {
          print(
            '🔄 Updating journal entry in Firestore: businesses/${business.firestoreId}/journal_entries/$firestoreJournalId',
          );
          await _firestoreService.updateJournalEntry(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            journalId: firestoreJournalId,
            voucherNo: journal.voucherNo,
            voucherType: journal.voucherType,
            description: journal.description,
            dueDate: journal.dueDate,
            paymentStatus: journal.paymentStatus,
            remainingAmount: journal.remainingAmount,
            imageUrl: journal.imageUrl,
            date: journal.date,
          );
        } else {
          print('⚠️  Firestore ID not found - update skipped');
        }
      },
      operationName: 'Update Journal Entry',
    );

    await _reminderService.refreshReminders(journal.businessId);
  }

  // =========================
  // DELETE JOURNAL ENTRY
  // =========================

  Future deleteJournalEntry(int journalId) async {
    final journal = await getJournalEntryById(journalId);
    if (journal != null) {
      // Fetch business to get Firestore ID
      final businesses = await DatabaseHelper.instance.getBusinesses();
      BusinessModel? business;
      try {
        business = businesses.firstWhere(
          (b) => b.businessId == journal.businessId,
        );
      } catch (e) {
        business = null;
      }

      return await _syncService.syncOperation<void>(
        sqliteOperation: () async {
          await DatabaseHelper.instance.deleteJournalEntry(journalId);
        },
        firestoreOperation: () async {
            final firestoreJournalId = journal.journalId == null
                ? null
                : await DatabaseHelper.instance.getJournalFirestoreId(journal.journalId!);

            if (business != null && business.firestoreId != null && firestoreJournalId != null) {
            print(
                '🔄 Deleting journal entry from Firestore: businesses/${business.firestoreId}/journal_entries/$firestoreJournalId',
            );
            await _firestoreService.deleteJournalEntry(
              business.firestoreId!, // ✅ Use Firestore ID
                firestoreJournalId,
            );
          } else {
            print('⚠️  Firestore ID not found - delete skipped');
          }
        },
        operationName: 'Delete Journal Entry',
      );
    }
  }

  // =========================
  // CREATE JOURNAL LINE
  // =========================

  Future<void> createJournalLine(
    int journalId,
    int accountId,
    double debit,
    double credit,
  ) async {
    final line = JournalLineModel(
      journalId: journalId,
      accountId: accountId,
      debit: debit,
      credit: credit,
    );

    return await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.insertJournalLine(line);
      },
      firestoreOperation: () async {
        // Get the journal entry to get businessId
        final journal = await getJournalEntryById(journalId);
        if (journal != null) {
          // Fetch business to get Firestore ID
          final businesses = await DatabaseHelper.instance.getBusinesses();
          BusinessModel? business;
          try {
            business = businesses.firstWhere(
              (b) => b.businessId == journal.businessId,
            );
          } catch (e) {
            business = null;
          }

          final firestoreJournalId = await DatabaseHelper.instance.getJournalFirestoreId(journalId);
          if (business != null && business.firestoreId != null && firestoreJournalId != null) {
            final journalLinesData = [
              {
                'account_id': accountId,
                'account_name': (await DatabaseHelper.instance.getAccountById(accountId))?.name,
                'account_firestore_id': await DatabaseHelper.instance.getAccountFirestoreId(accountId),
                'debit': debit,
                'credit': credit,
              },
            ];
            print(
              '🔥 Adding journal line to Firestore: businesses/${business.firestoreId}/journal_entries/$firestoreJournalId/journal_lines/',
            );
            await _firestoreService.addJournalLines(
              businessId: business.firestoreId!, // ✅ Use Firestore ID
              journalId: firestoreJournalId,
              journalLines: journalLinesData,
            );
          }
        }
      },
      operationName: 'Create Journal Line',
    );
  }

  // =========================
  // GET JOURNAL ENTRIES
  // =========================

  Future<List<JournalEntryModel>> getJournalEntries(int businessId) async {
    return await DatabaseHelper.instance.getJournalEntries(businessId);
  }

  Future<JournalEntryModel?> getJournalEntryById(int journalId) async {
    return await DatabaseHelper.instance.getJournalEntryById(journalId);
  }

  Future<List<Map<String, dynamic>>> getJournalRowsByBusiness(
    int businessId,
  ) async {
    return await DatabaseHelper.instance.getJournalLedgerRows(businessId);
  }

  // =========================
  // GET JOURNAL LINES
  // =========================

  Future<List<Map<String, dynamic>>> getJournalLines(int journalId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT
        journal_lines.*,
        accounts.name AS account_name
      FROM journal_lines
      LEFT JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_lines.journal_id = ?
      ORDER BY journal_lines.line_id ASC
    ''',
      [journalId],
    );
  }

  // =========================
  // GET JOURNAL BY TRANSACTION ID
  // =========================

  Future<JournalEntryModel?> getJournalByTransactionId(
    int transactionId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT je.* FROM journal_entry je
      INNER JOIN transactions t ON DATE(je.date) = DATE(t.date)
      WHERE t.transaction_id = ?
      LIMIT 1
    ''',
      [transactionId],
    );

    if (result.isEmpty) return null;
    return JournalEntryModel.fromMap(result.first);
  }
}
