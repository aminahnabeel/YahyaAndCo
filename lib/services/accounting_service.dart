import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/account_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class AccountingService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();
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

    // First, save to SQLite
    int journalId = 0;
    await db.transaction((txn) async {
      // INSERT JOURNAL ENTRY
      journalId = await txn.insert('journal_entry', journalEntry.toMap());

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

    print('📝 Journal created in SQLite with ID: $journalId');

    // Then, sync with Firestore if connected
    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        // Fetch business to get Firestore ID
        final businesses = await DatabaseHelper.instance.getBusinesses();
        BusinessModel? business;
        try {
          business = businesses.firstWhere((b) => b.businessId == journalEntry.businessId);
        } catch (e) {
          business = null;
        }

        if (business == null || business.firestoreId == null) {
          throw Exception('Firestore business ID not found');
        }

        print('🔄 Syncing journal to Firestore at: businesses/${business.firestoreId}/journal_entries/');
        
        // Create journal entry in Firestore
        await _firestoreService.createJournalEntry(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          transactionId: journalEntry.transactionId,
          voucherNo: journalEntry.voucherNo,
          voucherType: journalEntry.voucherType,
          description: journalEntry.description,
          dueDate: journalEntry.dueDate,
          paymentStatus: journalEntry.paymentStatus,
          remainingAmount: journalEntry.remainingAmount,
          imageUrl: journalEntry.imageUrl,
          date: journalEntry.date,
          createdAt: journalEntry.createdAt,
        );

        // Add journal lines
        final journalLinesData = journalLines
            .map((line) => {
          'account_id': line.accountId,
          'debit': line.debit,
          'credit': line.credit,
        })
            .toList();

        await _firestoreService.addJournalLines(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: journalId.toString(),
          journalLines: journalLinesData,
        );

        print('✅ Journal synced to Firestore');
      } catch (e) {
        print('⚠️  Journal saved to SQLite, Firestore sync failed: $e');
      }
    } else {
      print('⚠️  Offline mode - Journal saved to SQLite only');
    }
  }

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

    // First, update in SQLite
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

    // Then, sync with Firestore if connected
    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        // Fetch business to get Firestore ID
        final businesses = await DatabaseHelper.instance.getBusinesses();
        BusinessModel? business;
        try {
          business = businesses.firstWhere((b) => b.businessId == journalEntry.businessId);
        } catch (e) {
          business = null;
        }

        if (business == null || business.firestoreId == null) {
          throw Exception('Firestore business ID not found');
        }

        print('🔄 Updating journal in Firestore at: businesses/${business.firestoreId}/journal_entries/$journalId');
        
        // Update journal entry in Firestore
        await _firestoreService.updateJournalEntry(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: journalId.toString(),
          voucherNo: journalEntry.voucherNo,
          voucherType: journalEntry.voucherType,
          description: journalEntry.description,
          dueDate: journalEntry.dueDate,
          paymentStatus: journalEntry.paymentStatus,
          remainingAmount: journalEntry.remainingAmount,
          imageUrl: journalEntry.imageUrl,
          date: journalEntry.date,
        );

        // Delete old journal lines and add new ones
        await _firestoreService.deleteJournalLines(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: journalId.toString(),
        );

        final journalLinesData = journalLines
            .map((line) => {
          'account_id': line.accountId,
          'debit': line.debit,
          'credit': line.credit,
        })
            .toList();

        await _firestoreService.addJournalLines(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: journalId.toString(),
          journalLines: journalLinesData,
        );

        print('✅ Journal updated and synced to Firestore');
      } catch (e) {
        print('⚠️  Journal updated in SQLite, Firestore sync failed: $e');
      }
    }
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

  Future<double> getAccountBalance(
    int accountId, {
    bool paidOnly = true,
  }) async {
    final account = await DatabaseHelper.instance.getAccountById(accountId);
    if (account == null) return 0;

    double balance = account.openingBalance;

    final db = await DatabaseHelper.instance.database;

    final debitQuery = paidOnly
        ? '''
      SELECT SUM(jl.debit) as totalDebit
      FROM journal_lines jl
      INNER JOIN journal_entry je ON je.journal_id = jl.journal_id
      WHERE jl.account_id = ?
        AND LOWER(COALESCE(je.payment_status, '')) = 'paid'
      '''
        : '''
      SELECT SUM(debit) as totalDebit
      FROM journal_lines
      WHERE account_id = ?
      ''';

    final creditQuery = paidOnly
        ? '''
      SELECT SUM(jl.credit) as totalCredit
      FROM journal_lines jl
      INNER JOIN journal_entry je ON je.journal_id = jl.journal_id
      WHERE jl.account_id = ?
        AND LOWER(COALESCE(je.payment_status, '')) = 'paid'
      '''
        : '''
      SELECT SUM(credit) as totalCredit
      FROM journal_lines
      WHERE account_id = ?
      ''';

    final debitResult = await db.rawQuery(debitQuery, [accountId]);
    final creditResult = await db.rawQuery(creditQuery, [accountId]);

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
      // Look for account with "cash" in name (primary lookup)
      if (name.contains('cash')) {
        return account.accountId;
      }
    }

    return null;
  }

  Future<double> getCashBalanceForBusiness(int businessId) async {
    // Use the same dynamic cash-total calculation as getCashTotalBalance
    return await getCashTotalBalance(businessId);
  }

  Future<double> getBusinessTotalBalance(int businessId) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(
        COALESCE(accounts.opening_balance, 0)
        - COALESCE(journal_sums.total_debit, 0)
        + COALESCE(journal_sums.total_credit, 0)
      ) AS total
      FROM accounts
      LEFT JOIN (
        SELECT journal_lines.account_id,
               SUM(journal_lines.debit) AS total_debit,
               SUM(journal_lines.credit) AS total_credit
        FROM journal_lines
        INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        WHERE journal_entry.business_id = ?
        GROUP BY journal_lines.account_id
      ) AS journal_sums ON journal_sums.account_id = accounts.account_id
      WHERE accounts.business_id = ?
      ''',
      [businessId, businessId],
    );

    return _asDouble(result.first['total']);
  }

  // =====================================================
  // GET BANK ACCOUNTS TOTAL BALANCE
  // Sum of closing balances for accounts whose name contains 'bank'
  // =====================================================
  Future<double> getBankTotalBalance(int businessId) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(
        COALESCE(accounts.opening_balance, 0)
        - COALESCE(journal_sums.total_debit, 0)
        + COALESCE(journal_sums.total_credit, 0)
      ) AS total
      FROM accounts
      LEFT JOIN (
        SELECT journal_lines.account_id,
               SUM(journal_lines.debit) AS total_debit,
               SUM(journal_lines.credit) AS total_credit
        FROM journal_lines
        INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        WHERE journal_entry.business_id = ?
          AND LOWER(COALESCE(journal_entry.payment_status, '')) = 'paid'
        GROUP BY journal_lines.account_id
      ) AS journal_sums ON journal_sums.account_id = accounts.account_id
      WHERE accounts.business_id = ?
        AND LOWER(accounts.name) LIKE '%bank%'
      ''',
      [businessId, businessId],
    );

    return _asDouble(result.first['total']);
  }

  Future<double> getCashTotalBalance(int businessId) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(
        COALESCE(accounts.opening_balance, 0)
        - COALESCE(journal_sums.total_debit, 0)
        + COALESCE(journal_sums.total_credit, 0)
      ) AS total
      FROM accounts
      LEFT JOIN (
        SELECT journal_lines.account_id,
               SUM(journal_lines.debit) AS total_debit,
               SUM(journal_lines.credit) AS total_credit
        FROM journal_lines
        INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        WHERE journal_entry.business_id = ?
          AND LOWER(COALESCE(journal_entry.payment_status, '')) = 'paid'
        GROUP BY journal_lines.account_id
      ) AS journal_sums ON journal_sums.account_id = accounts.account_id
      WHERE accounts.business_id = ?
        AND LOWER(accounts.name) LIKE '%cash%'
      ''',
      [businessId, businessId],
    );

    return _asDouble(result.first['total']);
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
        AND LOWER(COALESCE(journal_entry.payment_status, '')) = 'paid'
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
        AND LOWER(COALESCE(journal_entry.payment_status, '')) = 'paid'
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
      getCashTotalBalance(businessId),
      getBankTotalBalance(businessId),
      getCashBalanceForBusiness(businessId),
      getBusinessTotalCredit(businessId),
      getBusinessTotalDebit(businessId),
      getBusinessIncome(businessId),
      getBusinessExpense(businessId),
    ]);

    final bankTotal = results[1];
    final cashInHand = results[2];

    return {
      // Total Balance = dynamic cash balance from vouchers + bank account closing balances
      'totalBalance': cashInHand + bankTotal,
      'totalCash': cashInHand,
      'totalCredit': results[3],
      'totalDebit': results[4],
      'totalIncome': results[5],
      'totalExpense': results[6],
    };
  }

  // =====================================================
  // GET TRIAL BALANCE FOR A BUSINESS
  // Returns account-wise total debit and credit for the specified business
  // =====================================================

  Future<List<Map<String, dynamic>>> getTrialBalanceForBusiness(
    int businessId, {
    int? year,
    int? month,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Build date filter if month/year provided
    String dateFilter = '';
    List<dynamic> params = [businessId, businessId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      dateFilter = 'AND je.date >= ? AND je.date <= ?';
      params = [businessId, businessId, startDate, endDate];
    }

    final rows = await db.rawQuery('''
      SELECT
        accounts.account_id,
        accounts.name,
        COALESCE(SUM(jl.debit), 0) AS total_debit,
        COALESCE(SUM(jl.credit), 0) AS total_credit
      FROM accounts
      LEFT JOIN journal_lines jl ON jl.account_id = accounts.account_id
      LEFT JOIN journal_entry je ON je.journal_id = jl.journal_id
        AND je.business_id = ?
      WHERE accounts.business_id = ? $dateFilter
      GROUP BY accounts.account_id
      ''', params);
    final List<Map<String, dynamic>> result = [];

    for (final row in rows) {
      final accountId = row['account_id'];
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);
      final closingBalance = totalCredit - totalDebit;

      // Find the last journal line for this account by date DESC and line_id DESC.
      final lastLine = await db.rawQuery(
        '''
        SELECT jl.debit AS debit, jl.credit AS credit
        FROM journal_lines jl
        INNER JOIN journal_entry je ON je.journal_id = jl.journal_id
        WHERE je.business_id = ? AND jl.account_id = ?
        ORDER BY je.date DESC, jl.line_id DESC
        LIMIT 1
        ''',
        [businessId, accountId],
      );

      double displayDebit = 0;
      double displayCredit = 0;

      if (lastLine.isNotEmpty) {
        final lastDebit = _asDouble(lastLine.first['debit']);
        final lastCredit = _asDouble(lastLine.first['credit']);

        if (lastDebit > 0) {
          displayDebit = closingBalance;
        } else if (lastCredit > 0) {
          displayCredit = closingBalance;
        }
      } else {
        displayCredit = 0;
      }

      result.add({
        'account_id': accountId,
        'name': row['name'],
        'total_debit': displayDebit,
        'total_credit': displayCredit,
        'net_balance': closingBalance,
      });
    }

    return result;
  }

  // =====================================================
  // GET CASH BOOK (ledger rows for Cash account only)
  // =====================================================

  Future<List<Map<String, dynamic>>> getCashBook(
    int businessId, {
    int? year,
    int? month,
  }) async {
    final cashId = await getCashAccountId(businessId);
    if (cashId == null) return [];

    final db = await DatabaseHelper.instance.database;

    // Build date filter if month/year provided
    String dateFilter = '';
    List<dynamic> params = [businessId, cashId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      dateFilter = 'AND journal_entry.date >= ? AND journal_entry.date <= ?';
      params = [businessId, cashId, startDate, endDate];
    }

    return await db.rawQuery('''
      SELECT journal_entry.journal_id as journal_id,
             journal_entry.date as date,
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
        AND journal_entry.voucher_type = 'CP'
        AND journal_lines.account_id = ?
        $dateFilter
      ORDER BY journal_entry.date ASC, journal_entry.journal_id ASC
      ''', params);
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
        SELECT journal_entry.journal_id as journal_id,
          journal_lines.line_id as line_id,
          journal_entry.date as date,
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
      -- Preserve insertion/chronological sequence: order by journal_id then journal line id
      ORDER BY journal_entry.journal_id ASC, journal_lines.line_id ASC
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

  Future<Map<String, dynamic>> getProfitLoss(
    int businessId, {
    int? year,
    int? month,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Build date filter if month/year provided
    String dateFilter = '';
    List<dynamic> params = [businessId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      dateFilter = 'AND journal_entry.date >= ? AND journal_entry.date <= ?';
      params = [businessId, startDate, endDate];
    }

    final rows = await db.rawQuery('''
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
        $dateFilter
      GROUP BY accounts.account_id
      ORDER BY accounts.type, accounts.name
      ''', params);

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
      final balanceSheet = await getBalanceSheet(businessId);

      final assets = _asDouble(balanceSheet['totalAssets']);
      final liabilities = _asDouble(balanceSheet['totalLiabilities']);
      final equity = _asDouble(balanceSheet['totalEquity']);

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
  // ADD MULTI-MONTH TEST DATA (Jan 2026 - June 2026)
  // =====================================================
  Future<void> addMultiMonthTestData(int businessId) async {
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

        // Generate data for each month: Jan 2026 to June 2026
        // Each month has VERY DIFFERENT amounts so filter works clearly
        final monthsData = [
          // January 2026 - LOW sales month
          {
            'month': 1,
            'sales': 500000,
            'commission': 50000,
            'flour_cost': 250000,
            'cotton_cost': 150000,
            'salary': 40000,
            'cash_in': 30000,
          },
          // February 2026 - LOW-MEDIUM sales month
          {
            'month': 2,
            'sales': 750000,
            'commission': 100000,
            'flour_cost': 400000,
            'cotton_cost': 250000,
            'salary': 40000,
            'cash_in': 50000,
          },
          // March 2026 - MEDIUM sales month
          {
            'month': 3,
            'sales': 1200000,
            'commission': 150000,
            'flour_cost': 600000,
            'cotton_cost': 400000,
            'salary': 45000,
            'cash_in': 80000,
          },
          // April 2026 - MEDIUM-HIGH sales month
          {
            'month': 4,
            'sales': 1800000,
            'commission': 250000,
            'flour_cost': 850000,
            'cotton_cost': 550000,
            'salary': 50000,
            'cash_in': 120000,
          },
          // May 2026 - HIGH sales month
          {
            'month': 5,
            'sales': 2500000,
            'commission': 350000,
            'flour_cost': 1200000,
            'cotton_cost': 750000,
            'salary': 55000,
            'cash_in': 170000,
          },
          // June 2026 (Latest) - HIGHEST sales month
          {
            'month': 6,
            'sales': 3200000,
            'commission': 450000,
            'flour_cost': 1500000,
            'cotton_cost': 950000,
            'salary': 60000,
            'cash_in': 220000,
          },
        ];

        int voucherNumber = 1;

        for (final monthData in monthsData) {
          final month = monthData['month'] as int;
          final date = DateTime(2026, month, 15).toIso8601String();

          // Entry 1: Sales Income
          final entryIncome = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': date,
            'description':
                'Monthly sales income - ${_getMonthName(month)} 2026',
            'voucher_no': 'JV-${voucherNumber++}',
            'voucher_type': 'JV',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Sales: Debit
          await txn.insert('journal_lines', {
            'journal_id': entryIncome,
            'account_id': accountIds['Faysal Bank'],
            'debit': monthData['sales'],
            'credit': 0,
          });

          // Revenue: Credit
          await txn.insert('journal_lines', {
            'journal_id': entryIncome,
            'account_id': accountIds['Sales Income'],
            'debit': 0,
            'credit': monthData['sales'],
          });

          // Entry 2: Flour Mill Expense
          final entryFlour = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': DateTime(2026, month, 10).toIso8601String(),
            'description': 'Taj Flour Mills - ${_getMonthName(month)} 2026',
            'voucher_no': 'CP-${voucherNumber++}',
            'voucher_type': 'CP',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Expense: Debit
          await txn.insert('journal_lines', {
            'journal_id': entryFlour,
            'account_id': accountIds['Taj Flour Mills'],
            'debit': monthData['flour_cost'],
            'credit': 0,
          });

          // Cash: Credit
          await txn.insert('journal_lines', {
            'journal_id': entryFlour,
            'account_id': accountIds['Cash in Hand'],
            'debit': 0,
            'credit': monthData['flour_cost'],
          });

          // Entry 3: Cotton Expense
          final entryCotton = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': DateTime(2026, month, 12).toIso8601String(),
            'description':
                'Ameen Cotton Factory - ${_getMonthName(month)} 2026',
            'voucher_no': 'CP-${voucherNumber++}',
            'voucher_type': 'CP',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Expense: Debit
          await txn.insert('journal_lines', {
            'journal_id': entryCotton,
            'account_id': accountIds['Ameen Cotton Factory'],
            'debit': monthData['cotton_cost'],
            'credit': 0,
          });

          // Bank: Credit
          await txn.insert('journal_lines', {
            'journal_id': entryCotton,
            'account_id': accountIds['Askari Bank'],
            'debit': 0,
            'credit': monthData['cotton_cost'],
          });

          // Entry 4: Commission Income
          final entryComm = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': DateTime(2026, month, 20).toIso8601String(),
            'description':
                'Flour Mill Commission - ${_getMonthName(month)} 2026',
            'voucher_no': 'JV-${voucherNumber++}',
            'voucher_type': 'JV',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Bank: Debit
          await txn.insert('journal_lines', {
            'journal_id': entryComm,
            'account_id': accountIds['Mian Trust Bank'],
            'debit': monthData['commission'],
            'credit': 0,
          });

          // Revenue: Credit
          await txn.insert('journal_lines', {
            'journal_id': entryComm,
            'account_id': accountIds['Flour Mill Commission'],
            'debit': 0,
            'credit': monthData['commission'],
          });

          // Entry 5: Salary Payment
          final entrySalary = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': DateTime(2026, month, 25).toIso8601String(),
            'description':
                'Monthly salary payment - ${_getMonthName(month)} 2026',
            'voucher_no': 'CP-${voucherNumber++}',
            'voucher_type': 'CP',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Expense: Debit
          await txn.insert('journal_lines', {
            'journal_id': entrySalary,
            'account_id': accountIds['Muhammad Asif Khana Abbasi'],
            'debit': monthData['salary'],
            'credit': 0,
          });

          // Cash: Credit
          await txn.insert('journal_lines', {
            'journal_id': entrySalary,
            'account_id': accountIds['Cash in Hand'],
            'debit': 0,
            'credit': monthData['salary'],
          });

          // Entry 6: Cash Deposit
          final entryCash = await txn.insert('journal_entry', {
            'business_id': businessId,
            'date': DateTime(2026, month, 28).toIso8601String(),
            'description':
                'Cash deposit to bank - ${_getMonthName(month)} 2026',
            'voucher_no': 'JV-${voucherNumber++}',
            'voucher_type': 'JV',
            'payment_status': 'Paid',
            'created_at': now,
          });

          // Bank: Debit
          await txn.insert('journal_lines', {
            'journal_id': entryCash,
            'account_id': accountIds['Faysal Bank'],
            'debit': monthData['cash_in'],
            'credit': 0,
          });

          // Cash: Credit
          await txn.insert('journal_lines', {
            'journal_id': entryCash,
            'account_id': accountIds['Cash in Hand'],
            'debit': 0,
            'credit': monthData['cash_in'],
          });
        }
      });

      print('Multi-month test data added successfully');
    } catch (e) {
      print('Error adding multi-month test data: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // =====================================================
  // GET BALANCE SHEET
  // =====================================================
  Future<Map<String, dynamic>> getBalanceSheet(
    int businessId, {
    int? year,
    int? month,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Build date filter if month/year provided
    String dateFilter = '';
    List<dynamic> params = [businessId, businessId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      dateFilter = 'AND journal_entry.date >= ? AND journal_entry.date <= ?';
      params = [businessId, businessId, startDate, endDate];
    }

    // Get all assets, liabilities, and equity
    final rows = await db.rawQuery('''
      SELECT
        accounts.account_id,
        accounts.name,
        accounts.type,
        COALESCE(accounts.opening_balance, 0) AS opening_balance,
        COALESCE(SUM(journal_lines.debit), 0) as total_debit,
        COALESCE(SUM(journal_lines.credit), 0) as total_credit
      FROM accounts
      LEFT JOIN journal_lines ON journal_lines.account_id = accounts.account_id
      LEFT JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        AND journal_entry.business_id = ?
      WHERE accounts.business_id = ?
        AND LOWER(accounts.type) IN ('asset', 'liability', 'equity', 'payable', 'drawing')
        $dateFilter
      GROUP BY accounts.account_id
      ORDER BY accounts.type, accounts.name
      ''', params);

    double totalAssets = 0;
    double totalLiabilities = 0;
    double totalEquity = 0;

    final assets = <Map<String, dynamic>>[];
    final liabilities = <Map<String, dynamic>>[];
    final equity = <Map<String, dynamic>>[];

    for (final row in rows) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final openingBalance = _asDouble(row['opening_balance']);
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);
      final balance = openingBalance - totalDebit + totalCredit;

      if (type == 'asset') {
        totalAssets += balance;
        assets.add({...row, 'balance': balance});
      } else if (type == 'liability' || type == 'payable') {
        totalLiabilities += balance;
        liabilities.add({...row, 'balance': balance});
      } else if (type == 'equity' || type == 'drawing') {
        totalEquity += balance;
        equity.add({...row, 'balance': balance});
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
