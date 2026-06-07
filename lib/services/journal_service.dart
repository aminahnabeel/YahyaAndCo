import '../db/database_helper.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';

class JournalService {

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
    return await DatabaseHelper.instance.insertJournalEntry(journal);
  }

  // =========================
  // UPDATE JOURNAL ENTRY
  // =========================

  Future updateJournalEntry(
    JournalEntryModel journal,
  ) async {

    await DatabaseHelper
        .instance
        .updateJournalEntry(
      journal,
    );
  }

  // =========================
  // DELETE JOURNAL ENTRY
  // =========================

  Future deleteJournalEntry(
    int journalId,
  ) async {

    await DatabaseHelper
        .instance
        .deleteJournalEntry(
      journalId,
    );
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
    await DatabaseHelper.instance.insertJournalLine(line);
  }

  // =========================
  // GET JOURNAL ENTRIES
  // =========================

  Future<List<JournalEntryModel>>
      getJournalEntries(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getJournalEntries(
      businessId,
    );
  }

  Future<JournalEntryModel?> getJournalEntryById(int journalId) async {
    return await DatabaseHelper.instance.getJournalEntryById(journalId);
  }

  Future<List<Map<String, dynamic>>> getJournalRowsByBusiness(int businessId) async {
    return await DatabaseHelper.instance.getJournalLedgerRows(businessId);
  }

  // =========================
  // GET JOURNAL LINES
  // =========================

  Future<List<Map<String, dynamic>>>
      getJournalLines(
    int journalId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT
        journal_lines.*,
        accounts.name AS account_name
      FROM journal_lines
      LEFT JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_lines.journal_id = ?
      ORDER BY journal_lines.line_id ASC
    ''', [journalId]);
  }

  // =========================
  // GET JOURNAL BY TRANSACTION ID
  // =========================

  Future<JournalEntryModel?> getJournalByTransactionId(int transactionId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT je.* FROM journal_entry je
      INNER JOIN transactions t ON DATE(je.date) = DATE(t.date)
      WHERE t.transaction_id = ?
      LIMIT 1
    ''', [transactionId]);
    
    if (result.isEmpty) return null;
    return JournalEntryModel.fromMap(result.first);
  }
}