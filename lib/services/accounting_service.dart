import '../db/database_helper.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/account_model.dart';

class AccountingService {
  // =====================================================
  // HELPER: Convert value to double safely
  // =====================================================
  // Handles null, int, double, and string conversions

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String calculatePaymentStatus({
    required double amount,
    required double remainingAmount,
    String? dueDate,
  }) {
    final parsedDueDate = _asDate(dueDate);
    final today = DateTime.now();
    final isOverdue =
        parsedDueDate != null &&
        parsedDueDate.isBefore(DateTime(today.year, today.month, today.day)) &&
        remainingAmount > 0;

    if (remainingAmount <= 0) return 'Paid';
    return isOverdue ? 'Overdue' : 'Pending';
  }

  // =====================================================
  // GENERATE JOURNAL VOUCHER
  // =====================================================
  // Auto-generates sequential voucher numbers for journal entries
  // Pattern: JV-1, JV-2, JV-3, etc.
  // These are required for audit trail and accounting standards

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
  // Auto-generates sequential voucher numbers for cash transactions
  // Pattern: CP-1, CP-2, CP-3, etc. (CP = Cash Payment/Receipt)

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
  // UPDATE COMPLETE JOURNAL
  // =====================================================

  Future<void> updateCompleteJournal({
    required int journalId,
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
      // UPDATE JOURNAL ENTRY

      await txn.update(
        'journal_entry',
        journalEntry.toMap(),
        where: 'journal_id = ?',
        whereArgs: [journalId],
      );

      // DELETE OLD JOURNAL LINES

      await txn.delete(
        'journal_lines',
        where: 'journal_id = ?',
        whereArgs: [journalId],
      );

      // INSERT NEW JOURNAL LINES

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

  Future<void> updatePaymentStatus({
    required String tableName,
    required int id,
    required double amount,
    required double remainingAmount,
    String? dueDate,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final status = calculatePaymentStatus(
      amount: amount,
      remainingAmount: remainingAmount,
      dueDate: dueDate,
    );

    final payload = {
      'payment_status': status,
      'remaining_amount': remainingAmount,
      'due_date': dueDate,
    };

    final idColumn = tableName == 'transactions'
        ? 'transaction_id'
        : 'journal_id';
    await db.update(
      tableName,
      payload,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  // =====================================================
  // GET ACCOUNT BALANCE
  // =====================================================
  // Calculates balance for a specific account using double-entry bookkeeping
  // Formula: SUM(debit) - SUM(credit)
  //
  // This works for all account types:
  // - Assets: Debit positive = increase
  // - Liabilities/Equity: Credit positive = increase
  // - Income: Credit positive = increase
  // - Expense: Debit positive = increase
  //
  // Includes opening balance through account's opening_balance field

  Future<double> getAccountBalance(int accountId) async {
    final account = await DatabaseHelper.instance.getAccountById(accountId);
    if (account == null) return 0;

    double balance = account.openingBalance;

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

    final double totalDebit = _asDouble(debitResult.first['totalDebit']);
    final double totalCredit = _asDouble(creditResult.first['totalCredit']);

    return balance - totalDebit + totalCredit;
  }

  Future<double> getOutstandingAmount(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(remaining_amount) AS total
      FROM (
        SELECT remaining_amount FROM transactions WHERE business_id = ?
        UNION ALL
        SELECT remaining_amount FROM journal_entry WHERE business_id = ?
      )
      ''',
      [businessId, businessId],
    );
    return _asDouble(result.first['total']);
  }

  // =====================================================
  // GET CASH ACCOUNT ID
  // =====================================================
  // Finds the Cash account for a business
  // The Cash account is a required system account created automatically

  Future<int?> getCashAccountId(int businessId) async {
    final accounts = await DatabaseHelper.instance.getAccountsByBusiness(
      businessId,
    );

    for (final account in accounts) {
      final name = account.name.toLowerCase();
      // Look for account with "Cash" in name (primary lookup)
      if (name == 'cash') {
        return account.accountId;
      }
    }

    return null;
  }

  Future<double> getCashBalanceForBusiness(int businessId) async {
    final cashAccountId = await getCashAccountId(businessId);

    if (cashAccountId == null) {
      return 0;
    }

    // Get account opening balance
    final account = await DatabaseHelper.instance.getAccountById(cashAccountId);
    double balance = account?.openingBalance ?? 0;

    // Add journal entries balance (debit - credit)
    balance += await getAccountBalance(cashAccountId);

    return balance;
  }

  // =====================================================
  // GET TOTAL BALANCE (Cash + Bank Accounts Only)
  // =====================================================
  // Calculates total balance by summing closing balances
  // of only Cash and Bank accounts.
  // Used for Dashboard "Total Balance" card.

  Future<double> getTotalCashAndBankBalance(int businessId) async {
    try {
      final accounts = await DatabaseHelper.instance.getAccountsByBusiness(businessId);
      
      double totalBalance = 0;
      
      for (final account in accounts) {
        final name = account.name.toLowerCase();
        // Only include accounts with "cash" or "bank" in their name
        if (name.contains('cash') || name.contains('bank')) {
          final closingBalance = await DatabaseHelper.instance.getAccountClosingBalance(account.accountId!);
          totalBalance += closingBalance;
        }
      }
      
      return totalBalance;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions(
    int businessId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT t.*, a.name AS account_name
      FROM transactions t
      INNER JOIN accounts a ON a.account_id = t.account_id
      LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
      WHERE t.business_id = ?
        AND t.remaining_amount > 0
        AND LOWER(COALESCE(t.payment_status, '')) = 'pending'
      ORDER BY COALESCE(t.due_date, t.date) ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueTransactions(
    int businessId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT t.*, a.name AS account_name
      FROM transactions t
      INNER JOIN accounts a ON a.account_id = t.account_id
      LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
      WHERE t.business_id = ?
        AND t.remaining_amount > 0
        AND (
          LOWER(COALESCE(t.payment_status, '')) = 'overdue'
          OR DATE(t.due_date) < DATE('now')
        )
      ORDER BY t.due_date ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingJournals(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT je.*, a.name AS account_name
      FROM journal_entry je
      LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
      LEFT JOIN accounts a ON a.account_id = jl.account_id
      WHERE je.business_id = ?
        AND je.remaining_amount > 0
        AND LOWER(COALESCE(je.payment_status, '')) = 'pending'
      GROUP BY je.journal_id
      ORDER BY COALESCE(je.due_date, je.date) ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueJournals(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT je.*, a.name AS account_name
      FROM journal_entry je
      LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
      LEFT JOIN accounts a ON a.account_id = jl.account_id
      WHERE je.business_id = ?
        AND je.remaining_amount > 0
        AND (
          LOWER(COALESCE(je.payment_status, '')) = 'overdue'
          OR DATE(je.due_date) < DATE('now')
        )
      GROUP BY je.journal_id
      ORDER BY je.due_date ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getDueToday(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT 'Transaction' AS record_type, t.transaction_id AS record_id, COALESCE(je.voucher_no, 'TX-' || t.transaction_id) AS voucher_no,
               t.amount AS amount, t.remaining_amount AS remaining_amount, t.due_date AS due_date,
               t.payment_status AS payment_status, t.type AS voucher_type, t.payment_method AS payment_method,
               t.note AS description, a.name AS account_name
        FROM transactions t
        INNER JOIN accounts a ON a.account_id = t.account_id
        LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
        WHERE t.business_id = ?
        UNION ALL
        SELECT 'Journal' AS record_type, je.journal_id AS record_id, je.voucher_no AS voucher_no,
               je.remaining_amount AS amount, je.remaining_amount AS remaining_amount, je.due_date AS due_date,
               je.payment_status AS payment_status, je.voucher_type AS voucher_type,
               NULL AS payment_method, je.description AS description, a.name AS account_name
        FROM journal_entry je
        LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
        LEFT JOIN accounts a ON a.account_id = jl.account_id
        WHERE je.business_id = ?
      )
      WHERE DATE(due_date) = DATE('now')
        AND remaining_amount > 0
      ORDER BY due_date ASC
      ''',
      [businessId, businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingDuePayments(
    int businessId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT 'Transaction' AS record_type, t.transaction_id AS record_id, COALESCE(je.voucher_no, 'TX-' || t.transaction_id) AS voucher_no,
               t.amount AS amount, t.remaining_amount AS remaining_amount, t.due_date AS due_date,
               t.payment_status AS payment_status, t.type AS voucher_type, t.payment_method AS payment_method,
               t.note AS description, a.name AS account_name
        FROM transactions t
        INNER JOIN accounts a ON a.account_id = t.account_id
        LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
        WHERE t.business_id = ?
        UNION ALL
        SELECT 'Journal' AS record_type, je.journal_id AS record_id, je.voucher_no AS voucher_no,
               je.remaining_amount AS amount, je.remaining_amount AS remaining_amount, je.due_date AS due_date,
               je.payment_status AS payment_status, je.voucher_type AS voucher_type,
               NULL AS payment_method, je.description AS description, a.name AS account_name
        FROM journal_entry je
        LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
        LEFT JOIN accounts a ON a.account_id = jl.account_id
        WHERE je.business_id = ?
      )
      WHERE DATE(due_date) > DATE('now')
        AND DATE(due_date) <= DATE('now', '+7 day')
        AND remaining_amount > 0
      ORDER BY due_date ASC
      ''',
      [businessId, businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllOutstandingRecords(
    int businessId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT 'Transaction' AS record_type, t.transaction_id AS record_id, COALESCE(je.voucher_no, 'TX-' || t.transaction_id) AS voucher_no,
               t.amount AS amount, t.remaining_amount AS remaining_amount, t.due_date AS due_date,
               t.payment_status AS payment_status, t.type AS voucher_type, t.payment_method AS payment_method,
               t.note AS description, a.name AS account_name
        FROM transactions t
        INNER JOIN accounts a ON a.account_id = t.account_id
        LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
        WHERE t.business_id = ?
        UNION ALL
        SELECT 'Journal' AS record_type, je.journal_id AS record_id, je.voucher_no AS voucher_no,
               je.remaining_amount AS amount, je.remaining_amount AS remaining_amount, je.due_date AS due_date,
               je.payment_status AS payment_status, je.voucher_type AS voucher_type,
               NULL AS payment_method, je.description AS description, a.name AS account_name
        FROM journal_entry je
        LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
        LEFT JOIN accounts a ON a.account_id = jl.account_id
        WHERE je.business_id = ?
      )
      WHERE remaining_amount > 0
      ORDER BY COALESCE(due_date, '') ASC
      ''',
      [businessId, businessId],
    );
  }

  Future<List<Map<String, dynamic>>> getReminderEntries(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT
          'Transaction' AS record_type,
          t.transaction_id AS record_id,
          t.transaction_id AS transaction_id,
          NULL AS journal_id,
          COALESCE(je.voucher_no, 'TX-' || t.transaction_id) AS voucher_no,
          t.amount AS amount,
          t.remaining_amount AS remaining_amount,
          t.due_date AS due_date,
          t.payment_status AS payment_status,
          t.payment_method AS payment_method,
          t.type AS voucher_type,
          t.note AS description,
          a.name AS account_name,
          t.date AS date,
          t.created_at AS created_at,
          'transactions' AS source_table
        FROM transactions t
        INNER JOIN accounts a ON a.account_id = t.account_id
        LEFT JOIN journal_entry je ON je.transaction_id = t.transaction_id
        WHERE t.business_id = ?
        UNION ALL
        SELECT
          'Journal' AS record_type,
          je.journal_id AS record_id,
          NULL AS transaction_id,
          je.journal_id AS journal_id,
          je.voucher_no AS voucher_no,
          je.remaining_amount AS amount,
          je.remaining_amount AS remaining_amount,
          je.due_date AS due_date,
          je.payment_status AS payment_status,
          NULL AS payment_method,
          je.voucher_type AS voucher_type,
          je.description AS description,
          COALESCE(MIN(a.name), 'Journal Entry') AS account_name,
          je.date AS date,
          je.created_at AS created_at,
          'journal_entry' AS source_table
        FROM journal_entry je
        LEFT JOIN journal_lines jl ON jl.journal_id = je.journal_id
        LEFT JOIN accounts a ON a.account_id = jl.account_id
        WHERE je.business_id = ?
        GROUP BY je.journal_id
      )
      ORDER BY COALESCE(due_date, date) DESC, record_type ASC, record_id DESC
      ''',
      [businessId, businessId],
    );
  }

  // =====================================================
  // GET BUSINESS TOTAL DEBIT
  // =====================================================
  // Calculates total debit from all journal entries for a business
  // Query: SUM(journal_lines.debit) WHERE business_id = ?

  Future<double> getBusinessTotalDebit(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(journal_lines.debit) AS total
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      WHERE journal_entry.business_id = ?
      ''',
      [businessId],
    );
    return _asDouble(result.first['total']);
  }

  Future<double> getBusinessTotalCredit(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(journal_lines.credit) AS total
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      WHERE journal_entry.business_id = ?
      ''',
      [businessId],
    );
    return _asDouble(result.first['total']);
  }

  Future<double> getBusinessIncome(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(journal_lines.credit) AS total
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND LOWER(accounts.type) IN ('revenue', 'income')
      ''',
      [businessId],
    );
    return _asDouble(result.first['total']);
  }

  Future<double> getBusinessExpense(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(journal_lines.debit) AS total
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND LOWER(accounts.type) = 'expense'
      ''',
      [businessId],
    );
    return _asDouble(result.first['total']);
  }

  Future<Map<String, double>> getDashboardSummary(int businessId) async {
    final results = await Future.wait<double>([
      getTotalCashAndBankBalance(businessId),
      getCashBalanceForBusiness(businessId),
      getBusinessTotalCredit(businessId),
      getBusinessTotalDebit(businessId),
      getBusinessIncome(businessId),
      getBusinessExpense(businessId),
    ]);

    return {
      'totalBalance': results[0],
      'totalCash': results[1],
      'totalCredit': results[2],
      'totalDebit': results[3],
      'totalIncome': results[4],
      'totalExpense': results[5],
    };
  }

  // =====================================================
  // GET TRIAL BALANCE FOR A BUSINESS
  // Returns account-wise total debit and credit for the specified business
  // =====================================================

  Future<List<Map<String, dynamic>>> getTrialBalanceForBusiness(
    int businessId,
  ) async {
    final db = await DatabaseHelper.instance.database;

    // Get account totals and their latest journal line side
    final rows = await db.rawQuery(
      '''
      SELECT
        accounts.account_id,
        accounts.name,
        SUM(journal_lines.debit) as total_debit,
        SUM(journal_lines.credit) as total_credit,
        (
          SELECT CASE
            WHEN (
              SELECT debit FROM journal_lines
              INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
              WHERE journal_lines.account_id = accounts.account_id
                AND journal_entry.business_id = ?
              ORDER BY journal_entry.date DESC, journal_lines.line_id DESC
              LIMIT 1
            ) > 0 THEN 'debit'
            ELSE 'credit'
          END
        ) as last_entry_side
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
      GROUP BY accounts.account_id
      ''',
      [businessId, businessId],
    );

    // Process rows to show balance on the side of the last entry
    final processedRows = <Map<String, dynamic>>[];
    
    for (final row in rows) {
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);
      // Calculate closing balance: balance = totalCredit - totalDebit
      final closingBalance = totalCredit - totalDebit;
      
      final displayRow = {...row};
      final lastEntrySide = (row['last_entry_side'] ?? 'credit').toString().toLowerCase();
      
      // Display balance on the side of the last entry
      if (lastEntrySide == 'debit') {
        // Last entry was debit, show full closing balance on debit side
        displayRow['total_debit'] = closingBalance.abs();
        displayRow['total_credit'] = 0.0;
      } else {
        // Last entry was credit, show full closing balance on credit side
        displayRow['total_debit'] = 0.0;
        displayRow['total_credit'] = closingBalance.abs();
      }
      
      processedRows.add(displayRow);
    }
    
    return processedRows;
  }

  // =====================================================
  // GET CASH BOOK (ledger rows for Cash account only)
  // =====================================================

  Future<List<Map<String, dynamic>>> getCashBook(int businessId) async {
    final cashId = await getCashAccountId(businessId);
    if (cashId == null) return [];

    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT journal_entry.date as date,
             journal_entry.voucher_no as voucher_no,
             journal_entry.due_date as due_date,
             journal_entry.payment_status as payment_status,
             journal_entry.remaining_amount as remaining_amount,
             journal_lines.debit as debit,
             journal_lines.credit as credit,
             journal_entry.description as description,
             accounts.name as account_name
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND journal_lines.account_id = ?
        AND LOWER(COALESCE(journal_entry.payment_status, 'paid')) = 'paid'
      ORDER BY journal_entry.date ASC, journal_entry.journal_id ASC
      ''',
      [businessId, cashId],
    );
  }

  // =====================================================
  // GET LEDGER FOR ACCOUNT
  // =====================================================

  Future<List<Map<String, dynamic>>> getLedgerForAccount(
    int businessId,
    int accountId,
  ) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery(
      '''
        SELECT journal_entry.date as date,
          journal_entry.voucher_no as voucher_no,
          journal_entry.due_date as due_date,
          journal_entry.payment_status as payment_status,
          journal_entry.remaining_amount as remaining_amount,
          journal_lines.debit as debit,
          journal_lines.credit as credit,
          journal_entry.description as description,
          accounts.name as account_name
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ? AND journal_lines.account_id = ?
      ORDER BY journal_entry.date ASC, journal_entry.journal_id ASC
    ''',
      [businessId, accountId],
    );

    return rows;
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
  // GET PROFIT & LOSS
  // =====================================================

  Future<Map<String, dynamic>> getProfitLoss(int businessId) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        accounts.account_id,
        accounts.name,
        accounts.type,
        SUM(journal_lines.debit) as total_debit,
        SUM(journal_lines.credit) as total_credit
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND LOWER(accounts.type) IN ('income', 'revenue', 'expense')
      GROUP BY accounts.account_id
      ORDER BY accounts.type, accounts.name
      ''',
      [businessId],
    );

    double income = 0;
    double expense = 0;

    final incomeAccounts = <Map<String, dynamic>>[];
    final expenseAccounts = <Map<String, dynamic>>[];

    for (final row in rows) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);

      if (type == 'expense') {
        expense += totalDebit;
        expenseAccounts.add({...row, 'net_balance': totalDebit - totalCredit});
      } else if (type == 'income' || type == 'revenue') {
        income += totalCredit;
        incomeAccounts.add({...row, 'net_balance': totalCredit - totalDebit});
      }
    }

    return {
      'income': income,
      'expense': expense,
      'profit': income - expense,
      'incomeAccounts': incomeAccounts,
      'expenseAccounts': expenseAccounts,
    };
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

  // =====================================================
  // Compatibility / Requested API
  // =====================================================

  Future<double> getTotalCash(int businessId) async {
    return await getCashBalanceForBusiness(businessId);
  }

  Future<double> getTotalDebit(int businessId) async {
    return await getBusinessTotalDebit(businessId);
  }

  Future<double> getTotalCredit(int businessId) async {
    return await getBusinessTotalCredit(businessId);
  }

  Future<double> getTotalIncome(int businessId) async {
    return await getBusinessIncome(businessId);
  }

  Future<double> getTotalExpense(int businessId) async {
    return await getBusinessExpense(businessId);
  }

  // =====================================================
  // GET REPORTS CARD DATA
  // =====================================================
  // Fetches all necessary data for the Reports screen cards

  Future<Map<String, dynamic>> getReportsCardData(int businessId) async {
    final results = await Future.wait<dynamic>([
      getTrialBalanceForBusiness(businessId), // For Trial Balance
      getCashBalanceForBusiness(businessId), // For Cash Book
      _calculateProfitMargin(businessId), // For Profit & Loss
      _getBalanceSheetStatus(businessId), // For Balance Sheet
    ]);

    return {
      'trialBalance': results[0] as List<Map<String, dynamic>>,
      'cashBalance': results[1] as double,
      'profitMargin': results[2] as String,
      'balanceSheetStatus': results[3] as String,
    };
  }

  Future<String> _calculateProfitMargin(int businessId) async {
    try {
      final income = await getBusinessIncome(businessId);
      final expense = await getBusinessExpense(businessId);

      if (income == 0) return '0%';

      final margin = ((income - expense) / income) * 100;
      return '${margin.toStringAsFixed(0)}%';
    } catch (e) {
      return '0%';
    }
  }

  Future<String> _getBalanceSheetStatus(int businessId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final result = await db.rawQuery(
        '''
        SELECT
          SUM(CASE WHEN LOWER(accounts.type) = 'asset' THEN 
            (COALESCE(journal_lines.debit, 0) - COALESCE(journal_lines.credit, 0)) 
            ELSE 0 END) as total_assets,
          SUM(CASE WHEN LOWER(accounts.type) IN ('liability', 'payable') THEN 
            (COALESCE(journal_lines.credit, 0) - COALESCE(journal_lines.debit, 0)) 
            ELSE 0 END) as total_liabilities,
          SUM(CASE WHEN LOWER(accounts.type) = 'equity' THEN 
            (COALESCE(journal_lines.credit, 0) - COALESCE(journal_lines.debit, 0)) 
            ELSE 0 END) as total_equity
        FROM journal_lines
        INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
        WHERE journal_entry.business_id = ?
      ''',
        [businessId],
      );

      if (result.isEmpty) return 'Healthy';

      final assets = _asDouble(result.first['total_assets']);
      final liabilities = _asDouble(result.first['total_liabilities']);
      final equity = _asDouble(result.first['total_equity']);

      // Check if the balance sheet equation holds: Assets = Liabilities + Equity
      final difference = (assets - (liabilities + equity)).abs();
      if (difference < 0.01) return 'Healthy';

      return 'Review';
    } catch (e) {
      return 'Healthy';
    }
  }

  // Create default system accounts for a newly created business
  Future<void> createDefaultAccounts(int businessId) async {
    final now = DateTime.now().toIso8601String();

    final defaultAccounts = <AccountModel>[
      AccountModel(
        businessId: businessId,
        name: 'Cash',
        type: 'Asset',
        openingBalance: 0,
        createdAt: now,
      ),
      AccountModel(
        businessId: businessId,
        name: 'General Expense',
        type: 'Expense',
        openingBalance: 0,
        createdAt: now,
      ),
      AccountModel(
        businessId: businessId,
        name: 'Owner Capital',
        type: 'Equity',
        openingBalance: 0,
        createdAt: now,
      ),
    ];

    for (final acc in defaultAccounts) {
      await DatabaseHelper.instance.insertAccount(acc);
    }
  }

  // =====================================================
  // ADD TEST DATA FOR PREVIEW
  // =====================================================
  Future<void> addTestData(int businessId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    try {
      await db.transaction((txn) async {
        // Create test accounts
        final testAccounts = [
          // Bank Accounts
          {'name': 'Faysal Bank', 'type': 'Asset'},
          {'name': 'Askari Bank', 'type': 'Asset'},
          {'name': 'Mian Trust Bank', 'type': 'Asset'},
          // Capital
          {'name': 'Mian Ehtesham Ahmad', 'type': 'Equity'},
          {'name': 'Mian Abdul Majid', 'type': 'Equity'},
          // Employee/Payable
          {'name': 'Muhammad Asif Khana Abbasi', 'type': 'Payable'},
          {'name': 'Abdul Kareem Shah', 'type': 'Payable'},
          // Owner Drawing
          {'name': 'Mian Gul Tahir', 'type': 'Drawing'},
          // Income
          {'name': 'Flour Mill Commission', 'type': 'Revenue'},
          {'name': 'Sales Income', 'type': 'Revenue'},
          {'name': 'Brokerage', 'type': 'Revenue'},
          // Expenses
          {'name': 'Taj Flour Mills', 'type': 'Expense'},
          {'name': 'United Flour Mills', 'type': 'Expense'},
          {'name': 'Ameen Cotton Factory', 'type': 'Expense'},
          {'name': 'AHMAD Cotton Factory', 'type': 'Expense'},
          // Cash
          {'name': 'Cash in Hand', 'type': 'Asset'},
        ];

        Map<String, int> accountIds = {};

        for (final acc in testAccounts) {
          final result = await txn.insert('accounts', {
            'business_id': businessId,
            'name': acc['name'],
            'type': acc['type'],
            'opening_balance': 0,
            'created_at': now,
          });
          accountIds[acc['name'] ?? ''] = result;
        }

        // Create balanced journal entries
        // Entry 1: Opening balances (Total = 5,000,000)
        final entry1 = await txn.insert('journal_entry', {
          'business_id': businessId,
          'date': now,
          'description': 'Opening balances - Banks',
          'voucher_no': 'JV-1',
          'voucher_type': 'JV',
          'created_at': now,
        });

        // Bank accounts: Debit 3,000,000
        await txn.insert('journal_lines', {
          'journal_id': entry1,
          'account_id': accountIds['Faysal Bank'],
          'debit': 1500000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry1,
          'account_id': accountIds['Askari Bank'],
          'debit': 800000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry1,
          'account_id': accountIds['Mian Trust Bank'],
          'debit': 700000,
          'credit': 0,
        });

        // Capital: Credit 3,000,000
        await txn.insert('journal_lines', {
          'journal_id': entry1,
          'account_id': accountIds['Mian Ehtesham Ahmad'],
          'debit': 0,
          'credit': 2000000,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry1,
          'account_id': accountIds['Mian Abdul Majid'],
          'debit': 0,
          'credit': 1000000,
        });

        // Entry 2: Expenses and Sales (Total = 2,500,000)
        final entry2 = await txn.insert('journal_entry', {
          'business_id': businessId,
          'date': now,
          'description': 'Purchase from suppliers',
          'voucher_no': 'JV-2',
          'voucher_type': 'JV',
          'created_at': now,
        });

        // Expenses: Debit 1,500,000
        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['Taj Flour Mills'],
          'debit': 500000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['United Flour Mills'],
          'debit': 600000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['Ameen Cotton Factory'],
          'debit': 300000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['AHMAD Cotton Factory'],
          'debit': 100000,
          'credit': 0,
        });

        // Income: Credit 1,500,000
        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['Flour Mill Commission'],
          'debit': 0,
          'credit': 600000,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['Sales Income'],
          'debit': 0,
          'credit': 700000,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry2,
          'account_id': accountIds['Brokerage'],
          'debit': 0,
          'credit': 200000,
        });

        // Entry 3: Employee payments (Total = 500,000)
        final entry3 = await txn.insert('journal_entry', {
          'business_id': businessId,
          'date': now,
          'description': 'Employee salary payments',
          'voucher_no': 'JV-3',
          'voucher_type': 'JV',
          'created_at': now,
        });

        // Expenses to Employee accounts: Debit 300,000
        await txn.insert('journal_lines', {
          'journal_id': entry3,
          'account_id': accountIds['Muhammad Asif Khana Abbasi'],
          'debit': 200000,
          'credit': 0,
        });

        await txn.insert('journal_lines', {
          'journal_id': entry3,
          'account_id': accountIds['Abdul Kareem Shah'],
          'debit': 100000,
          'credit': 0,
        });

        // Bank payment: Credit 300,000
        await txn.insert('journal_lines', {
          'journal_id': entry3,
          'account_id': accountIds['Faysal Bank'],
          'debit': 0,
          'credit': 300000,
        });

        // Entry 4: Owner withdrawals (Total = 200,000)
        final entry4 = await txn.insert('journal_entry', {
          'business_id': businessId,
          'date': now,
          'description': 'Owner withdrawals',
          'voucher_no': 'JV-4',
          'voucher_type': 'JV',
          'created_at': now,
        });

        // Owner Drawing: Debit 200,000
        await txn.insert('journal_lines', {
          'journal_id': entry4,
          'account_id': accountIds['Mian Gul Tahir'],
          'debit': 200000,
          'credit': 0,
        });

        // Bank payment: Credit 200,000
        await txn.insert('journal_lines', {
          'journal_id': entry4,
          'account_id': accountIds['Askari Bank'],
          'debit': 0,
          'credit': 200000,
        });

        // Entry 5: Cash account (Total = 100,000)
        final entry5 = await txn.insert('journal_entry', {
          'business_id': businessId,
          'date': now,
          'description': 'Cash handling',
          'voucher_no': 'JV-5',
          'voucher_type': 'JV',
          'created_at': now,
        });

        // Cash: Debit 100,000
        await txn.insert('journal_lines', {
          'journal_id': entry5,
          'account_id': accountIds['Cash in Hand'],
          'debit': 100000,
          'credit': 0,
        });

        // Bank payment: Credit 100,000
        await txn.insert('journal_lines', {
          'journal_id': entry5,
          'account_id': accountIds['Mian Trust Bank'],
          'debit': 0,
          'credit': 100000,
        });
      });
    } catch (e) {
      print('Error adding test data: $e');
    }
  }

  // =====================================================
  // GET BALANCE SHEET
  // =====================================================
  Future<Map<String, dynamic>> getBalanceSheet(int businessId) async {
    final db = await DatabaseHelper.instance.database;

    // Get all assets, liabilities, and equity
    final rows = await db.rawQuery(
      '''
      SELECT
        accounts.account_id,
        accounts.name,
        accounts.type,
        SUM(journal_lines.debit) as total_debit,
        SUM(journal_lines.credit) as total_credit
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND LOWER(accounts.type) IN ('asset', 'liability', 'equity', 'payable', 'drawing')
      GROUP BY accounts.account_id
      ORDER BY accounts.type, accounts.name
      ''',
      [businessId],
    );

    double totalAssets = 0;
    double totalLiabilities = 0;
    double totalEquity = 0;

    final assets = <Map<String, dynamic>>[];
    final liabilities = <Map<String, dynamic>>[];
    final equity = <Map<String, dynamic>>[];

    for (final row in rows) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);
      // Use consistent formula: balance = totalCredit - totalDebit
      // Debit = Money OUT (decreases balance)
      // Credit = Money IN (increases balance)
      final balance = totalCredit - totalDebit;

      if (type == 'asset') {
        totalAssets += balance;
        assets.add({...row, 'balance': balance});
      } else if (type == 'liability' || type == 'payable') {
        totalLiabilities += balance;
        liabilities.add({...row, 'balance': balance});
      } else if (type == 'equity' || type == 'drawing') {
        // Equity includes capital accounts, drawing is deducted
        if (type == 'drawing') {
          totalEquity -= balance;
        } else {
          totalEquity += balance;
        }
        equity.add({
          ...row,
          'balance': type == 'drawing' ? -balance : balance,
        });
      }
    }

    final isBalanced =
        (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;

    return {
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'totalEquity': totalEquity,
      'isBalanced': isBalanced,
    };
  }
}
