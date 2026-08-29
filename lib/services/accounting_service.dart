import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';
import 'reminder_service.dart';
import 'sync_service.dart';

class AccountingService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();
  final ReminderService _reminderService = ReminderService();
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

  static Map<String, double> calculateTrialBalancePlacement({
    required double totalDebit,
    required double totalCredit,
  }) {
    final netDiff = totalCredit - totalDebit;

    if (netDiff < 0) {
      return {
        'netDiff': netDiff,
        'tbDebit': netDiff.abs(),
        'tbCredit': 0.0,
      };
    }

    if (netDiff > 0) {
      return {
        'netDiff': netDiff,
        'tbDebit': 0.0,
        'tbCredit': netDiff,
      };
    }

    return {
      'netDiff': 0.0,
      'tbDebit': 0.0,
      'tbCredit': 0.0,
    };
  }

  // =====================================================
  // GENERATE JOURNAL VOUCHER
  // =====================================================
  // Auto-generates sequential voucher numbers for journal entries
  // Pattern: JV-1, JV-2, JV-3, etc.
  // These are required for audit trail and accounting standards

  Future<String> generateJournalVoucher() {
    return _generateNextVoucher('JV');
  }

  // =====================================================
  // GENERATE CASH VOUCHER
  // =====================================================
  // Auto-generates sequential voucher numbers for cash transactions
  // Pattern: CP-1, CP-2, CP-3, etc. (CP = Cash Payment/Receipt)

  Future<String> generateCashVoucher() {
    return _generateNextVoucher('CP');
  }

  Future<String> _generateNextVoucher(String voucherType) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'journal_entry',
      columns: ['voucher_no'],
      where: 'voucher_type = ?',
      whereArgs: [voucherType],
    );

    var highestNumber = 0;
    final prefix = '$voucherType-';
    for (final row in rows) {
      final voucherNo = row['voucher_no']?.toString() ?? '';
      if (!voucherNo.startsWith(prefix)) continue;

      final number = int.tryParse(voucherNo.substring(prefix.length));
      if (number != null && number > highestNumber) {
        highestNumber = number;
      }
    }

    return '$prefix${highestNumber + 1}';
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

    await _validateNonNegativeBalancesForJournal(
      journalLines: journalLines,
      excludeJournalId: null,
    );

    // First, save to SQLite
    int journalId = 0;
    await db.transaction((txn) async {
      var voucherNumber = journalEntry.voucherNo;
      var suffix = int.tryParse(
        voucherNumber.replaceFirst('${journalEntry.voucherType}-', ''),
      );
      final prefix = '${journalEntry.voucherType}-';

      while (true) {
        final existing = await txn.query(
          'journal_entry',
          columns: ['journal_id'],
          where: 'voucher_type = ? AND voucher_no = ?',
          whereArgs: [journalEntry.voucherType, voucherNumber],
          limit: 1,
        );
        if (existing.isEmpty) break;

        suffix = (suffix ?? 0) + 1;
        voucherNumber = '$prefix$suffix';
      }

      journalEntry.voucherNo = voucherNumber;

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
          business = businesses.firstWhere(
            (b) => b.businessId == journalEntry.businessId,
          );
        } catch (e) {
          business = null;
        }

        if (business == null || business.firestoreId == null) {
          throw Exception('Firestore business ID not found');
        }

        print(
          '🔄 Syncing journal to Firestore at: businesses/${business.firestoreId}/journal_entries/',
        );

        final firestoreJournalId = await _firestoreService.createJournalEntry(
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

        await DatabaseHelper.instance.updateJournalFirestoreId(
          journalId,
          firestoreJournalId,
        );

        // Add journal lines
        final journalLinesData = journalLines
            .map(
              (line) async {
                final account = await DatabaseHelper.instance.getAccountById(line.accountId);
                final firestoreAccountId = account == null
                    ? null
                    : await DatabaseHelper.instance.getAccountFirestoreId(line.accountId);

                return {
                  'account_id': line.accountId,
                  'account_name': account?.name,
                  'account_firestore_id': firestoreAccountId,
                  'debit': line.debit,
                  'credit': line.credit,
                };
              },
            )
            .toList();

        final resolvedJournalLinesData = <Map<String, dynamic>>[];
        for (final item in journalLinesData) {
          resolvedJournalLinesData.add(await item);
        }

        await _firestoreService.addJournalLines(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: firestoreJournalId,
          journalLines: resolvedJournalLinesData,
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

    await _validateNonNegativeBalancesForJournal(
      journalLines: journalLines,
      excludeJournalId: journalId,
    );

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
          business = businesses.firstWhere(
            (b) => b.businessId == journalEntry.businessId,
          );
        } catch (e) {
          business = null;
        }

        if (business == null || business.firestoreId == null) {
          throw Exception('Firestore business ID not found');
        }

        final firestoreJournalId = await DatabaseHelper.instance.getJournalFirestoreId(journalId);

        if (firestoreJournalId == null) {
          throw Exception('Firestore journal ID not found');
        }

        print(
          '🔄 Updating journal in Firestore at: businesses/${business.firestoreId}/journal_entries/$firestoreJournalId',
        );

        // Update journal entry in Firestore
        await _firestoreService.updateJournalEntry(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: firestoreJournalId,
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
          journalId: firestoreJournalId,
        );

        final journalLinesData = <Map<String, dynamic>>[];
        for (final line in journalLines) {
          final account = await DatabaseHelper.instance.getAccountById(line.accountId);
          journalLinesData.add({
            'account_id': line.accountId,
            'account_name': account?.name,
            'account_firestore_id': account == null
                ? null
                : await DatabaseHelper.instance.getAccountFirestoreId(line.accountId),
            'debit': line.debit,
            'credit': line.credit,
          });
        }

        await _firestoreService.addJournalLines(
          businessId: business.firestoreId!, // ✅ Use Firestore ID
          journalId: firestoreJournalId,
          journalLines: journalLinesData,
        );

        print('✅ Journal updated and synced to Firestore');
      } catch (e) {
        print('⚠️  Journal updated in SQLite, Firestore sync failed: $e');
      }
    }
  }

  Future<void> _validateNonNegativeBalancesForJournal({
    required List<JournalLineModel> journalLines,
    int? excludeJournalId,
  }) async {
    if (journalLines.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    final Map<int, double> debitByAccount = {};
    final Map<int, double> creditByAccount = {};

    for (final line in journalLines) {
      debitByAccount[line.accountId] =
          (debitByAccount[line.accountId] ?? 0) + line.debit;
      creditByAccount[line.accountId] =
          (creditByAccount[line.accountId] ?? 0) + line.credit;
    }

    final affectedAccountIds = {
      ...debitByAccount.keys,
      ...creditByAccount.keys,
    };

    for (final accountId in affectedAccountIds) {
      double balanceWithoutOldLines = await getAccountBalance(
        accountId,
        paidOnly: false,
      );

      if (excludeJournalId != null) {
        final oldLineResult = await db.rawQuery(
          '''
          SELECT
            COALESCE(SUM(debit), 0) AS old_debit,
            COALESCE(SUM(credit), 0) AS old_credit
          FROM journal_lines
          WHERE journal_id = ? AND account_id = ?
          ''',
          [excludeJournalId, accountId],
        );

        final oldDebit = _asDouble(oldLineResult.first['old_debit']);
        final oldCredit = _asDouble(oldLineResult.first['old_credit']);
        balanceWithoutOldLines = balanceWithoutOldLines + oldDebit - oldCredit;
      }

      final projectedBalance =
          balanceWithoutOldLines -
          (debitByAccount[accountId] ?? 0) +
          (creditByAccount[accountId] ?? 0);

      if (projectedBalance < -0.0001) {
        final account = await DatabaseHelper.instance.getAccountById(accountId);
        final accountName = account?.name ?? 'Selected account';
        throw Exception(
          "$accountName doesn't have enough amount for this debit",
        );
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

    final idColumn = tableName == 'transactions' ? 'transaction_id' : 'journal_id';

    // Update SQLite first
    await db.update(
      tableName,
      payload,
      where: '$idColumn = ?',
      whereArgs: [id],
    );

    // Refresh reminders locally
    final sourceRows = await db.query(
      tableName,
      columns: ['business_id'],
      where: '$idColumn = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sourceRows.isNotEmpty) {
      final businessId = (sourceRows.first['business_id'] as num).toInt();
      await _reminderService.refreshReminders(businessId);
    }

    // Then attempt to sync to Firestore (surface failures to caller)
    await _syncService.syncOperation<void>(
      sqliteOperation: () async => null,
      firestoreOperation: () async {
        final recordRows = await db.query(
          tableName,
          where: '$idColumn = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (recordRows.isEmpty) {
          throw Exception('Record not found for payment status sync');
        }

        final record = recordRows.first;
        final businessId = (record['business_id'] as num?)?.toInt();
        if (businessId == null) throw Exception('Business ID missing for payment status sync');

        final businesses = await DatabaseHelper.instance.getBusinesses();
        BusinessModel? business;
        try {
          business = businesses.firstWhere((item) => item.businessId == businessId);
        } catch (e) {
          business = null;
        }

        if (business == null || business.firestoreId == null) throw Exception('Firestore business ID not found');

        if (tableName == 'transactions') {
          final firestoreTransactionId = await DatabaseHelper.instance.getTransactionFirestoreId(id);
          if (firestoreTransactionId == null) throw Exception('Firestore transaction ID not found');

          final accountId = (record['account_id'] as num?)?.toInt();
          final toAccountId = (record['to_account_id'] as num?)?.toInt();
          final account = accountId == null ? null : await DatabaseHelper.instance.getAccountById(accountId);
          final toAccount = toAccountId == null ? null : await DatabaseHelper.instance.getAccountById(toAccountId);
          final accountFirestoreId = accountId == null ? null : await DatabaseHelper.instance.getAccountFirestoreId(accountId);
          final toAccountFirestoreId = toAccountId == null ? null : await DatabaseHelper.instance.getAccountFirestoreId(toAccountId);

          await _firestoreService.updateTransaction(
            businessId: business.firestoreId!,
            transactionId: firestoreTransactionId,
            amount: amount,
            type: (record['type'] ?? '').toString(),
            note: (record['note'] ?? '').toString(),
            paymentMethod: (record['payment_method'] ?? '').toString(),
            dueDate: dueDate,
            paymentStatus: status,
            remainingAmount: remainingAmount,
            imageUrl: record['image_url']?.toString(),
            date: (record['date'] ?? '').toString(),
            accountId: accountId,
            accountFirestoreId: accountFirestoreId,
            accountName: account?.name,
            toAccountId: toAccountId,
            toAccountFirestoreId: toAccountFirestoreId,
            toAccountName: toAccount?.name,
          );

          final linkedJournal = await DatabaseHelper.instance.getJournalEntryByTransactionId(id);
          if (linkedJournal != null) {
            await db.update('journal_entry', payload, where: 'journal_id = ?', whereArgs: [linkedJournal.journalId]);

            final firestoreJournalId = await DatabaseHelper.instance.getJournalFirestoreId(linkedJournal.journalId!);
            if (firestoreJournalId != null) {
              await _firestoreService.updateJournalEntry(
                businessId: business.firestoreId!,
                journalId: firestoreJournalId,
                voucherNo: linkedJournal.voucherNo,
                voucherType: linkedJournal.voucherType,
                description: linkedJournal.description,
                dueDate: dueDate,
                paymentStatus: status,
                remainingAmount: remainingAmount,
                imageUrl: linkedJournal.imageUrl,
                date: linkedJournal.date,
              );
            }
          }

          return;
        }

        final firestoreJournalId = await DatabaseHelper.instance.getJournalFirestoreId(id);
        if (firestoreJournalId == null) throw Exception('Firestore journal ID not found');

        final linkedTransactionId = (record['transaction_id'] as num?)?.toInt();
        await _firestoreService.updateJournalEntry(
          businessId: business.firestoreId!,
          journalId: firestoreJournalId,
          voucherNo: (record['voucher_no'] ?? '').toString(),
          voucherType: (record['voucher_type'] ?? '').toString(),
          description: (record['description'] ?? '').toString(),
          dueDate: dueDate,
          paymentStatus: status,
          remainingAmount: remainingAmount,
          imageUrl: record['image_url']?.toString(),
          date: (record['date'] ?? '').toString(),
        );

        if (linkedTransactionId != null) {
          final linkedTransaction = await DatabaseHelper.instance.getTransactionById(linkedTransactionId);
          final transactionFirestoreId = await DatabaseHelper.instance.getTransactionFirestoreId(linkedTransactionId);
          if (transactionFirestoreId != null && linkedTransaction != null) {
            final accountId = linkedTransaction.accountId;
            final toAccountId = linkedTransaction.toAccountId;
            final account = accountId == null ? null : await DatabaseHelper.instance.getAccountById(accountId);
            final toAccount = toAccountId == null ? null : await DatabaseHelper.instance.getAccountById(toAccountId);
            final accountFirestoreId = accountId == null ? null : await DatabaseHelper.instance.getAccountFirestoreId(accountId);
            final toAccountFirestoreId = toAccountId == null ? null : await DatabaseHelper.instance.getAccountFirestoreId(toAccountId);

            await DatabaseHelper.instance.updateTransaction(
              TransactionModel(
                transactionId: linkedTransaction.transactionId,
                businessId: linkedTransaction.businessId,
                accountId: linkedTransaction.accountId,
                toAccountId: linkedTransaction.toAccountId,
                amount: linkedTransaction.amount,
                type: linkedTransaction.type,
                note: linkedTransaction.note,
                paymentMethod: linkedTransaction.paymentMethod,
                dueDate: dueDate,
                paymentStatus: status,
                remainingAmount: remainingAmount,
                imageUrl: linkedTransaction.imageUrl,
                date: linkedTransaction.date,
                createdAt: linkedTransaction.createdAt,
              ),
            );

            await _firestoreService.updateTransaction(
              businessId: business.firestoreId!,
              transactionId: transactionFirestoreId,
              amount: linkedTransaction.amount,
              type: linkedTransaction.type,
              note: linkedTransaction.note,
              paymentMethod: linkedTransaction.paymentMethod,
              dueDate: dueDate,
              paymentStatus: status,
              remainingAmount: remainingAmount,
              imageUrl: linkedTransaction.imageUrl,
              date: linkedTransaction.date,
              accountId: accountId,
              accountFirestoreId: accountFirestoreId,
              accountName: account?.name,
              toAccountId: toAccountId,
              toAccountFirestoreId: toAccountFirestoreId,
              toAccountName: toAccount?.name,
            );
          }
        }
      },
      operationName: 'Update Payment Status',
      surfaceFirestoreFailure: true,
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

    // 1) Prefer exact system cash account first.
    for (final account in accounts) {
      final name = account.name.trim().toLowerCase();
      final type = account.type.trim().toLowerCase();
      if (name == 'cash' && (type == 'asset' || type == 'cash')) {
        return account.accountId;
      }
    }

    // 2) Then exact "cash in hand" style account.
    for (final account in accounts) {
      final name = account.name.trim().toLowerCase();
      final type = account.type.trim().toLowerCase();
      if (name == 'cash in hand' && (type == 'asset' || type == 'cash')) {
        return account.accountId;
      }
    }

    // 3) Fallback to any asset/cash-type account containing "cash".
    for (final account in accounts) {
      final name = account.name.trim().toLowerCase();
      final type = account.type.trim().toLowerCase();
      if (name.contains('cash') && (type == 'asset' || type == 'cash')) {
        return account.accountId;
      }
    }

    return null;
  }

  Future<double> getCashBalanceForBusiness(int businessId) async {
    // Cash in hand should represent only the main cash account balance.
    return await getCashInHandForBusiness(businessId);
  }

  Future<double> getCashInHandForBusiness(int businessId) async {
    final cashAccountId = await getCashAccountId(businessId);
    if (cashAccountId == null) return 0;

    return await getAccountBalance(cashAccountId);
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
        AND (
          LOWER(accounts.type) = 'bank'
          OR LOWER(accounts.name) LIKE '%bank%'
        )
      ''',
      [businessId, businessId],
    );

    return _asDouble(result.first['total']);
  }

  Future<double> getCashTotalBalance(int businessId) async {
    final cashInHand = await getCashInHandForBusiness(businessId);
    final bankTotal = await getBankTotalBalance(businessId);
    final ownerCapital = await getOwnerCapitalBalance(businessId);

    // Total financial liquidity/equity view required on dashboard:
    // cash account + all bank accounts + owner capital.
    return cashInHand + bankTotal + ownerCapital;
  }

  Future<double> getOwnerCapitalBalance(int businessId) async {
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
        AND LOWER(accounts.type) = 'equity'
        AND LOWER(accounts.name) LIKE '%capital%'
        AND LOWER(accounts.name) NOT LIKE '%opening balance%'
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
      getBankTotalBalance(businessId),
      getCashInHandForBusiness(businessId),
      getBusinessTotalCredit(businessId),
      getBusinessTotalDebit(businessId),
      getBusinessIncome(businessId),
      getBusinessExpense(businessId),
    ]);

    final bankBalance = results[0];
    final cashBalance = results[1];
    final ownerCapital = await getOwnerCapitalBalance(businessId);

    return {
      'totalBalance': bankBalance,
      'totalBankBalance': bankBalance,
      'totalCash': cashBalance + ownerCapital,
      'cashInHand': cashBalance + ownerCapital,
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
    int businessId, {
    int? year,
    int? month,
  }) async {
    final db = await DatabaseHelper.instance.database;

    String joinDateFilter = '';
    List<dynamic> params = [businessId, businessId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
      joinDateFilter = 'AND je.date >= ? AND je.date <= ?';
      params = [businessId, startDate, endDate, businessId];
    }

    final rows = await db.rawQuery('''
      SELECT
        accounts.account_id,
        accounts.name,
        accounts.type,
        COALESCE(SUM(jl.debit), 0) AS total_debit,
        COALESCE(SUM(jl.credit), 0) AS total_credit
      FROM accounts
      LEFT JOIN journal_lines jl ON jl.account_id = accounts.account_id
      LEFT JOIN journal_entry je ON je.journal_id = jl.journal_id
        AND je.business_id = ?
        $joinDateFilter
      WHERE accounts.business_id = ?
      GROUP BY accounts.account_id
      ''', params);

    final List<Map<String, dynamic>> result = [];
    double totalTbDebit = 0;
    double totalTbCredit = 0;

    for (final row in rows) {
      final accountId = row['account_id'] as int;
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);
      final placement = calculateTrialBalancePlacement(
        totalDebit: totalDebit,
        totalCredit: totalCredit,
      );

      final tbDebit = placement['tbDebit'] ?? 0.0;
      final tbCredit = placement['tbCredit'] ?? 0.0;
      final netDiff = placement['netDiff'] ?? 0.0;

      totalTbDebit += tbDebit;
      totalTbCredit += tbCredit;

      result.add({
        'account_id': accountId,
        'name': row['name'],
        'type': row['type'],
        'total_debit': totalDebit,
        'total_credit': totalCredit,
        'tb_debit': tbDebit,
        'tb_credit': tbCredit,
        'net_diff': netDiff,
      });
    }

    final isBalanced = (totalTbDebit - totalTbCredit).abs() < 0.01;

    return result
      ..add({
        'account_id': -1,
        'name': 'TOTAL',
        'type': 'TOTAL',
        'total_debit': totalTbDebit,
        'total_credit': totalTbCredit,
        'tb_debit': totalTbDebit,
        'tb_credit': totalTbCredit,
        'net_diff': totalTbCredit - totalTbDebit,
        'is_balanced': isBalanced,
      });
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

    String dateFilter = '';
    List<dynamic> params = [businessId, cashId];

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1).toIso8601String();
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      dateFilter = 'AND journal_entry.date >= ? AND journal_entry.date <= ?';
      params = [businessId, cashId, startDate, endDate];
    }

    return await db.rawQuery('''
      SELECT
        journal_entry.journal_id AS journal_id,
        journal_entry.date AS date,
        journal_entry.created_at AS created_at,
        journal_entry.voucher_no AS voucher_no,
        journal_entry.due_date AS due_date,
        journal_entry.payment_status AS payment_status,
        journal_entry.remaining_amount AS remaining_amount,
        journal_lines.line_id AS line_id,
        journal_lines.debit AS debit,
        journal_lines.credit AS credit,
        journal_entry.description AS description,
        accounts.name AS account_name
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND journal_lines.account_id = ?
        $dateFilter
      ORDER BY journal_entry.date ASC, journal_entry.created_at ASC, journal_entry.journal_id ASC, journal_lines.line_id ASC
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
        SELECT
          journal_entry.journal_id AS journal_id,
          journal_entry.created_at AS created_at,
          journal_lines.line_id AS line_id,
          journal_entry.date AS date,
          journal_entry.voucher_no AS voucher_no,
          journal_entry.voucher_type AS voucher_type,
          journal_entry.due_date AS due_date,
          journal_entry.payment_status AS payment_status,
          journal_entry.remaining_amount AS remaining_amount,
          journal_lines.debit AS debit,
          journal_lines.credit AS credit,
          journal_entry.description AS description,
          accounts.name AS account_name
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ? AND journal_lines.account_id = ?
      ORDER BY journal_entry.date ASC, journal_entry.created_at ASC, journal_entry.journal_id ASC, journal_lines.line_id ASC
    ''',
      [businessId, accountId],
    );

    double runningBalance = 0;
    final orderedRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      final debit = _asDouble(row['debit']);
      final credit = _asDouble(row['credit']);
      runningBalance = runningBalance + credit - debit;

      orderedRows.add({
        ...row,
        'running_balance': runningBalance,
      });
    }

    return orderedRows;
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
        SUM(journal_lines.debit) AS total_debit,
        SUM(journal_lines.credit) AS total_credit
      FROM journal_lines
      INNER JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
        AND LOWER(accounts.type) IN ('income', 'revenue', 'expense')
        $dateFilter
      GROUP BY accounts.account_id
      ORDER BY accounts.type, accounts.name
      ''', params);

    double totalIncome = 0;
    double totalExpense = 0;
    final incomeAccounts = <Map<String, dynamic>>[];
    final expenseAccounts = <Map<String, dynamic>>[];

    for (final row in rows) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final totalDebit = _asDouble(row['total_debit']);
      final totalCredit = _asDouble(row['total_credit']);

      if (type == 'expense') {
        final netBalance = totalDebit - totalCredit;
        totalExpense += netBalance;
        expenseAccounts.add({
          ...row,
          'net_balance': netBalance,
        });
      } else if (type == 'income' || type == 'revenue') {
        final netBalance = totalCredit - totalDebit;
        totalIncome += netBalance;
        incomeAccounts.add({
          ...row,
          'net_balance': netBalance,
        });
      }
    }

    final netProfit = totalIncome - totalExpense;

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'netProfit': netProfit,
      'profit': netProfit,
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
    return await getCashTotalBalance(businessId);
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

    String joinDateFilter = '';
    List<dynamic> params = [businessId, businessId];

    if (year != null && month != null) {
      final endDate = DateTime(year, month + 1, 0).toIso8601String();
      joinDateFilter = 'AND journal_entry.date <= ?';
      params = [businessId, businessId, endDate];
    }

    final rows = await db.rawQuery('''
      SELECT
        accounts.account_id,
        accounts.name,
        accounts.type,
        COALESCE(accounts.opening_balance, 0) AS opening_balance,
        COALESCE(SUM(journal_lines.debit), 0) AS total_debit,
        COALESCE(SUM(journal_lines.credit), 0) AS total_credit
      FROM accounts
      LEFT JOIN journal_lines ON journal_lines.account_id = accounts.account_id
      LEFT JOIN journal_entry ON journal_entry.journal_id = journal_lines.journal_id
        AND journal_entry.business_id = ?
        $joinDateFilter
      WHERE accounts.business_id = ?
        AND LOWER(accounts.type) IN ('asset', 'liability', 'equity', 'payable', 'drawing')
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
      final balance = openingBalance + (totalCredit - totalDebit);

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

    final pnl = await getProfitLoss(businessId, year: year, month: month);
    final netProfit = _asDouble(pnl['netProfit']);
    totalEquity += netProfit;

    final isBalanced =
        (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;

    return {
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'totalEquity': totalEquity,
      'netProfit': netProfit,
      'isBalanced': isBalanced,
    };
  }
}
