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

    final journalId = await _syncService.syncOperation<int>(
      sqliteOperation: () async {
        print('💾 Saving journal to SQLite...');
        return await DatabaseHelper.instance.insertJournalEntry(journal);
      },
      firestoreOperation: () async {
        if (business != null && business.firestoreId != null) {
          print(
            '🔥 Syncing journal to Firestore at path: businesses/${business.firestoreId}/journal_entries/',
          );
          await _firestoreService.createJournalEntry(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
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
        } else {
          throw Exception('Firestore business ID not found');
        }
      },
      operationName: 'Create Journal Entry',
    );

    await _reminderService.refreshReminders(businessId);
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
        if (journal.journalId != null &&
            business != null &&
            business.firestoreId != null) {
          print(
            '🔄 Updating journal entry in Firestore: businesses/${business.firestoreId}/journal_entries/${journal.journalId}',
          );
          await _firestoreService.updateJournalEntry(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            journalId: journal.journalId!.toString(),
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
          if (business != null && business.firestoreId != null) {
            print(
              '🔄 Deleting journal entry from Firestore: businesses/${business.firestoreId}/journal_entries/$journalId',
            );
            await _firestoreService.deleteJournalEntry(
              business.firestoreId!, // ✅ Use Firestore ID
              journalId.toString(),
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

          if (business != null && business.firestoreId != null) {
            final journalLinesData = [
              {'account_id': accountId, 'debit': debit, 'credit': credit},
            ];
            print(
              '🔥 Adding journal line to Firestore: businesses/${business.firestoreId}/journal_entries/$journalId/journal_lines/',
            );
            await _firestoreService.addJournalLines(
              businessId: business.firestoreId!, // ✅ Use Firestore ID
              journalId: journalId.toString(),
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
