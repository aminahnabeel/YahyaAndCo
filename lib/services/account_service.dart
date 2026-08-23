import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../models/account_model.dart';
import '../models/journal_line_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class AccountService {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();

  // =========================
  // CREATE ACCOUNT
  // =========================

  Future<int> createAccount(AccountModel account) async {
    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere(
        (b) => b.businessId == account.businessId,
      );
    } catch (e) {
      business = null;
    }

    final accountId = await DatabaseHelper.instance.insertAccount(account);

    if (_syncService.isConnected && _firestoreService.isUserLoggedIn()) {
      try {
        if (business != null && business.firestoreId != null) {
          print(
            '🔥 Creating account in Firestore: businesses/${business.firestoreId}/accounts/',
          );
          final firestoreAccountId = await _firestoreService.createAccount(
            businessId: business.firestoreId!,
            name: account.name,
            type: account.type,
            phone: account.phone,
            address: account.address,
            openingBalance: account.openingBalance,
            createdAt: account.createdAt,
          );
          await DatabaseHelper.instance.updateAccountFirestoreId(
            accountId,
            firestoreAccountId,
          );
        }
      } catch (e) {
        print('⚠️  Account created in SQLite, Firestore sync failed: $e');
      }
    }

    return accountId;
  }

  // =========================
  // GET ACCOUNTS
  // =========================

  Future<List<AccountModel>> getAccountsByBusiness(int businessId) async {
    return await DatabaseHelper.instance.getAccountsByBusiness(businessId);
  }

  Future<bool> accountExists(int businessId, String accountName) async {
    final accounts = await getAccountsByBusiness(businessId);
    final normalizedName = accountName.trim().toLowerCase();

    return accounts.any(
      (account) => account.name.trim().toLowerCase() == normalizedName,
    );
  }

  // =========================
  // GET ACCOUNT BY ID
  // =========================

  Future<AccountModel?> getAccountById(int accountId) async {
    return await DatabaseHelper.instance.getAccountById(accountId);
  }

  // =========================
  // UPDATE ACCOUNT
  // =========================

  Future updateAccount(AccountModel account) async {
    if (account.accountId == null) {
      throw Exception('Account ID is required for update');
    }

    await updateOpeningBalance(
      account.accountId!,
      account.openingBalance,
      surfaceFirestoreFailure: true,
    );

    final firestoreOpeningBalance = account.openingBalance;

    final accountToUpdate = AccountModel(
      accountId: account.accountId,
      businessId: account.businessId,
      name: account.name,
      type: account.type,
      phone: account.phone,
      address: account.address,
      openingBalance: 0,
      createdAt: account.createdAt,
    );

    // Fetch business to get Firestore ID
    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere(
        (b) => b.businessId == account.businessId,
      );
    } catch (e) {
      business = null;
    }

    await _syncService.syncOperation<void>(
      sqliteOperation: () async {
        await DatabaseHelper.instance.updateAccount(accountToUpdate);
      },
      firestoreOperation: () async {
        final firestoreAccountId = account.accountId == null
            ? null
            : await DatabaseHelper.instance.getAccountFirestoreId(
                account.accountId!,
              );

        if (business != null &&
            business.firestoreId != null &&
            firestoreAccountId != null) {
          print(
            '🔄 Updating account in Firestore: businesses/${business.firestoreId}/accounts/$firestoreAccountId',
          );
          await _firestoreService.updateAccount(
            businessId: business.firestoreId!, // ✅ Use Firestore ID
            accountId: firestoreAccountId,
            name: account.name,
            type: account.type,
            phone: account.phone,
            address: account.address,
            openingBalance: firestoreOpeningBalance,
          );
        }
      },
      operationName: 'Update Account',
      surfaceFirestoreFailure: true,
    );
  }

  Future<void> updateOpeningBalance(
    int accountId,
    double newOpeningBalance, {
    bool surfaceFirestoreFailure = false,
  }) async {
    final account = await getAccountById(accountId);
    if (account == null) {
      throw Exception('Account not found');
    }

    final journalOpeningTotal = await DatabaseHelper.instance
        .getOpeningBalanceJournalTotal(accountId);
    final currentOpeningBalance = journalOpeningTotal + account.openingBalance;

    final businesses = await DatabaseHelper.instance.getBusinesses();
    BusinessModel? business;
    try {
      business = businesses.firstWhere(
        (b) => b.businessId == account.businessId,
      );
    } catch (e) {
      business = null;
    }

    Future<void> syncOpeningBalanceToFirestore(double amount) async {
      if (!_syncService.isConnected || !_firestoreService.isUserLoggedIn()) {
        return;
      }

      if (business == null || business.firestoreId == null) {
        return;
      }

      final firestoreBusinessId = business.firestoreId!;
      final firestoreAccountId = await _ensureFirestoreAccount(
        firestoreBusinessId,
        account,
      );
      final equityAccountId = await _ensureOpeningBalanceEquityAccount(
        firestoreBusinessId,
        account.businessId,
      );

      if (firestoreAccountId == null || equityAccountId == null) {
        return;
      }

      final now = DateTime.now().toIso8601String();
      final journalDocId = await _firestoreService.createJournalEntry(
        businessId: firestoreBusinessId,
        transactionId: null,
        voucherNo: 'OB-$accountId-${DateTime.now().millisecondsSinceEpoch}',
        voucherType: 'OB',
        description: 'Opening Balance',
        dueDate: null,
        paymentStatus: 'Paid',
        remainingAmount: 0,
        imageUrl: null,
        date: now,
        createdAt: now,
      );

      await _firestoreService.addJournalLines(
        businessId: firestoreBusinessId,
        journalId: journalDocId,
        journalLines: [
          {
            'account_id': account.accountId,
            'account_firestore_id': firestoreAccountId,
            'account_name': account.name,
            'debit': amount < 0 ? amount.abs() : 0.0,
            'credit': amount > 0 ? amount : 0.0,
          },
          {
            'account_id': equityAccountId['localAccountId'],
            'account_firestore_id': equityAccountId['firestoreAccountId'],
            'account_name': 'Opening Balance Equity',
            'debit': amount > 0 ? amount : 0.0,
            'credit': amount < 0 ? amount.abs() : 0.0,
          },
        ],
      );
    }

    final difference = newOpeningBalance - currentOpeningBalance;
    if (difference.abs() > 0.0001) {
      await DatabaseHelper.instance.insertOpeningBalanceJournalEntry(
        account.businessId,
        accountId,
        difference,
      );
      try {
        await syncOpeningBalanceToFirestore(difference);
      } catch (e) {
        if (surfaceFirestoreFailure) {
          rethrow;
        }
      }
    }

    final migratedAccount = AccountModel(
      accountId: account.accountId,
      businessId: account.businessId,
      name: account.name,
      type: account.type,
      phone: account.phone,
      address: account.address,
      openingBalance: 0,
      createdAt: account.createdAt,
    );
    await DatabaseHelper.instance.updateAccount(migratedAccount);
  }

  Future<String?> _ensureFirestoreAccount(
    String firestoreBusinessId,
    AccountModel account,
  ) async {
    final localFirestoreId = account.accountId == null
        ? null
        : await DatabaseHelper.instance.getAccountFirestoreId(
            account.accountId!,
          );
    if (localFirestoreId != null && localFirestoreId.isNotEmpty) {
      return localFirestoreId;
    }

    final firestoreAccounts = await _firestoreService.getAccountsByBusiness(
      firestoreBusinessId,
    );
    final normalizedName = account.name.trim().toLowerCase();
    final existing = firestoreAccounts.firstWhere(
      (item) =>
          (item['name'] ?? '').toString().trim().toLowerCase() ==
          normalizedName,
      orElse: () => <String, dynamic>{},
    );

    if (existing.isNotEmpty) {
      final firestoreId = existing['id']?.toString();
      if (firestoreId != null && account.accountId != null) {
        await DatabaseHelper.instance.updateAccountFirestoreId(
          account.accountId!,
          firestoreId,
        );
      }
      return firestoreId;
    }

    final firestoreId = await _firestoreService.createAccount(
      businessId: firestoreBusinessId,
      name: account.name,
      type: account.type,
      phone: account.phone,
      address: account.address,
      openingBalance: account.openingBalance,
      createdAt: account.createdAt,
    );

    if (account.accountId != null) {
      await DatabaseHelper.instance.updateAccountFirestoreId(
        account.accountId!,
        firestoreId,
      );
    }

    return firestoreId;
  }

  Future<Map<String, dynamic>?> _ensureOpeningBalanceEquityAccount(
    String firestoreBusinessId,
    int businessId,
  ) async {
    final localAccounts = await DatabaseHelper.instance.getAccountsByBusiness(
      businessId,
    );
    final localEquity = localAccounts.firstWhere(
      (account) =>
          account.name.trim().toLowerCase() == 'opening balance equity',
      orElse: () => AccountModel(
        businessId: businessId,
        name: 'Opening Balance Equity',
        type: 'Equity',
        openingBalance: 0,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final firestoreAccounts = await _firestoreService.getAccountsByBusiness(
      firestoreBusinessId,
    );
    final existing = firestoreAccounts.firstWhere(
      (item) =>
          (item['name'] ?? '').toString().trim().toLowerCase() ==
          'opening balance equity',
      orElse: () => <String, dynamic>{},
    );

    String? firestoreAccountId;
    if (existing.isNotEmpty) {
      firestoreAccountId = existing['id']?.toString();
    } else {
      firestoreAccountId = await _firestoreService.createAccount(
        businessId: firestoreBusinessId,
        name: 'Opening Balance Equity',
        type: 'Equity',
        phone: null,
        address: null,
        openingBalance: 0,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final localAccountId = localEquity.accountId;
    if (localAccountId != null && firestoreAccountId != null) {
      await DatabaseHelper.instance.updateAccountFirestoreId(
        localAccountId,
        firestoreAccountId,
      );
    }

    return {
      'localAccountId': localAccountId,
      'firestoreAccountId': firestoreAccountId,
    };
  }

  Future<double> getAccountOpeningBalanceFromJournal(int accountId) async {
    final account = await DatabaseHelper.instance.getAccountById(accountId);
    if (account == null) return 0;

    final journalOpeningTotal = await DatabaseHelper.instance
        .getOpeningBalanceJournalTotal(accountId);

    if (journalOpeningTotal != 0 || account.openingBalance == 0) {
      return journalOpeningTotal;
    }

    return account.openingBalance;
  }

  // =========================
  // DELETE ACCOUNT
  // =========================

  Future deleteAccount(int accountId) async {
    final account = await getAccountById(accountId);
    if (account != null) {
      // Fetch business to get Firestore ID
      final businesses = await DatabaseHelper.instance.getBusinesses();
      BusinessModel? business;
      try {
        business = businesses.firstWhere(
          (b) => b.businessId == account.businessId,
        );
      } catch (e) {
        business = null;
      }

      final firestoreAccountId = await DatabaseHelper.instance
          .getAccountFirestoreId(accountId);

      await _syncService.syncOperation<void>(
        sqliteOperation: () async {
          await DatabaseHelper.instance.deleteAccount(accountId);
        },
        firestoreOperation: () async {
          if (business != null &&
              business.firestoreId != null &&
              firestoreAccountId != null) {
            print(
              '🔄 Deleting account from Firestore: businesses/${business.firestoreId}/accounts/$firestoreAccountId',
            );
            await _firestoreService.deleteAccount(
              business.firestoreId!, // ✅ Use Firestore ID
              firestoreAccountId,
            );
          }
        },
        operationName: 'Delete Account',
      );
    }
  }

  // =========================
  // CREATE DEFAULT ACCOUNTS
  // =========================
  // Creates predefined system accounts when a new business is created
  // These accounts MUST exist for the app to function properly:
  // - Cash Account: Required for cash transactions and Cash Book reports
  // - General Expense Account: Required for expense tracking

  Future<void> createDefaultAccounts(int businessId) async {
    final existingCash = await accountExists(businessId, 'Cash');
    final existingExpense = await accountExists(businessId, 'General Expense');
    final existingOpeningBalanceEquity = await accountExists(
      businessId,
      'Opening Balance Equity',
    );

    if (existingCash && existingExpense && existingOpeningBalanceEquity) {
      return;
    }

    final defaultAccounts = [
      // Cash Account (Asset type for accounting purposes)
      // Used in: Dashboard Cash Card, Cash Book, Journal Entries
      AccountModel(
        businessId: businessId,
        name: 'Cash',
        type: 'Asset', // Accounting standard type
        phone: null,
        address: null,
        openingBalance: 0,
        createdAt: DateTime.now().toString(),
      ),
      // General Expense Account
      // Used for general expense tracking
      AccountModel(
        businessId: businessId,
        name: 'General Expense',
        type: 'Expense',
        phone: null,
        address: null,
        openingBalance: 0,
        createdAt: DateTime.now().toString(),
      ),
      // Opening Balance Equity Account
      // Used to balance opening balance journal entries for audit compliance
      AccountModel(
        businessId: businessId,
        name: 'Opening Balance Equity',
        type: 'Equity',
        phone: null,
        address: null,
        openingBalance: 0,
        createdAt: DateTime.now().toString(),
      ),
    ];

    for (final account in defaultAccounts) {
      if (await accountExists(businessId, account.name)) {
        continue;
      }

      await createAccount(account);
    }
  }

  Future<void> ensureDefaultAccounts(int businessId) async {
    await createDefaultAccounts(businessId);
  }

  // =========================
  // GET CLOSING BALANCE
  // =========================

  Future<double> getAccountClosingBalance(int accountId) async {
    return await DatabaseHelper.instance.getAccountClosingBalance(accountId);
  }

  Future<List<TransactionModel>> getTransactionsByAccountId(
    int accountId,
  ) async {
    return await DatabaseHelper.instance.getTransactionsByAccountId(accountId);
  }

  Future<List<JournalLineModel>> getJournalLinesByAccountId(
    int accountId,
  ) async {
    return await DatabaseHelper.instance.getJournalLinesByAccountId(accountId);
  }
}
