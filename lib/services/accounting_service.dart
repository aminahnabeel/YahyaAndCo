import '../db/database_helper.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';

class AccountingService {
  // =====================================================
  // GENERATE JOURNAL VOUCHER
  // =====================================================

  Future<String> generateJournalVoucher() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT voucher_no
      FROM journal_entry

      WHERE voucher_type = 'JV'

      ORDER BY journal_id DESC

      LIMIT 1
      ''');

    if (result.isEmpty) {
      return 'JV-1';
    }

    String lastVoucher = result.first['voucher_no'];

    int number = int.parse(lastVoucher.replaceAll('JV-', ''));

    number++;

    return 'JV-$number';
  }

  // =====================================================
  // GENERATE CASH VOUCHER
  // =====================================================

  Future<String> generateCashVoucher() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT voucher_no
      FROM journal_entry

      WHERE voucher_type = 'CP'

      ORDER BY journal_id DESC

      LIMIT 1
      ''');

    if (result.isEmpty) {
      return 'CP-1';
    }

    String lastVoucher = result.first['voucher_no'];

    int number = int.parse(lastVoucher.replaceAll('CP-', ''));

    number++;

    return 'CP-$number';
  }

  // =====================================================
  // CREATE COMPLETE JOURNAL
  // =====================================================

  Future createCompleteJournal({
    required JournalEntryModel journalEntry,

    required List<JournalLineModel> journalLines,
  }) async {
    final db = await DatabaseHelper.instance.database;

    double totalDebit = 0;

    double totalCredit = 0;

    for (var line in journalLines) {
      totalDebit += line.debit;

      totalCredit += line.credit;
    }

    // VALIDATION

    if (totalDebit != totalCredit) {
      throw Exception('Debit and Credit must be equal');
    }

    await db.transaction((txn) async {
      // INSERT JOURNAL ENTRY

      int journalId = await txn.insert('journal_entry', journalEntry.toMap());

      // INSERT JOURNAL LINES

      for (var line in journalLines) {
        await txn.insert('journal_lines', {
          'journal_id': journalId,

          'account_id': line.accountId,

          'debit': line.debit,

          'credit': line.credit,
        });
      }
    });
  }

  // =====================================================
  // GET ACCOUNT BALANCE
  // =====================================================

  Future<double> getAccountBalance(int accountId) async {
    final db = await DatabaseHelper.instance.database;

    final debitResult = await db.rawQuery(
      '''
      SELECT SUM(debit)
      as totalDebit

      FROM journal_lines

      WHERE account_id = ?
      ''',

      [accountId],
    );

    final creditResult = await db.rawQuery(
      '''
      SELECT SUM(credit)
      as totalCredit

      FROM journal_lines

      WHERE account_id = ?
      ''',

      [accountId],
    );

    double totalDebit = debitResult.first['totalDebit'] == null
        ? 0
        : debitResult.first['totalDebit'] as double;

    double totalCredit = creditResult.first['totalCredit'] == null
        ? 0
        : creditResult.first['totalCredit'] as double;

    return totalDebit - totalCredit;
  }

  // =====================================================
  // GET CASH IN HAND
  // =====================================================

  Future<double> getCashInHand(int cashAccountId) async {
    return await getAccountBalance(cashAccountId);
  }

  // =====================================================
  // GET TRIAL BALANCE
  // =====================================================

  Future<List<Map<String, dynamic>>> getTrialBalance() async {
    final db = await DatabaseHelper.instance.database;

    return await db.rawQuery('''
      SELECT

      accounts.account_id,
      accounts.name,

      SUM(
        journal_lines.debit
      ) as total_debit,

      SUM(
        journal_lines.credit
      ) as total_credit

      FROM journal_lines

      INNER JOIN accounts

      ON accounts.account_id =
      journal_lines.account_id

      GROUP BY accounts.account_id
      ''');
  }

  // =====================================================
  // GET LEDGER
  // =====================================================

  Future<List<Map<String, dynamic>>> getLedger(int accountId) async {
    final db = await DatabaseHelper.instance.database;

    return await db.rawQuery(
      '''
      SELECT

      journal_entry.voucher_no,
      journal_entry.description,
      journal_entry.date,

      journal_lines.debit,
      journal_lines.credit

      FROM journal_lines

      INNER JOIN journal_entry

      ON journal_entry.journal_id =
      journal_lines.journal_id

      WHERE journal_lines.account_id
      = ?

      ORDER BY
      journal_entry.journal_id DESC
      ''',

      [accountId],
    );
  }
}
