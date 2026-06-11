import '../db/database_helper.dart';
import '../models/account_model.dart';
import '../models/journal_line_model.dart';
import '../models/transaction_model.dart';

class AccountService {

  // =========================
  // CREATE ACCOUNT
  // =========================

  Future<int> createAccount(
    AccountModel account,
  ) async {

    return await DatabaseHelper
        .instance
        .insertAccount(
      account,
    );
  }

  // =========================
  // GET ACCOUNTS
  // =========================

  Future<List<AccountModel>>
      getAccountsByBusiness(
    int businessId,
  ) async {

    return await DatabaseHelper
        .instance
        .getAccountsByBusiness(
      businessId,
    );
  }

  Future<bool> accountExists(int businessId, String accountName) async {
    final accounts = await getAccountsByBusiness(businessId);
    final normalizedName = accountName.trim().toLowerCase();

    return accounts.any((account) => account.name.trim().toLowerCase() == normalizedName);
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

  Future updateAccount(
    AccountModel account,
  ) async {
    if (account.accountId == null) {
      throw Exception('Account ID is required for update');
    }

    await updateOpeningBalance(account.accountId!, account.openingBalance);

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

    await DatabaseHelper.instance.updateAccount(accountToUpdate);
  }

  Future<void> updateOpeningBalance(
    int accountId,
    double newOpeningBalance,
  ) async {
    final account = await getAccountById(accountId);
    if (account == null) {
      throw Exception('Account not found');
    }

    final journalOpeningTotal =
        await DatabaseHelper.instance.getOpeningBalanceJournalTotal(accountId);
    final currentOpeningBalance = journalOpeningTotal + account.openingBalance;

    if (account.openingBalance != 0) {
      await DatabaseHelper.instance.insertOpeningBalanceJournalEntry(
        account.businessId,
        accountId,
        account.openingBalance,
      );
    }

    final difference = newOpeningBalance - currentOpeningBalance;
    if (difference != 0) {
      await DatabaseHelper.instance.insertOpeningBalanceJournalEntry(
        account.businessId,
        accountId,
        difference,
      );
    }

    if (account.openingBalance != 0) {
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
  }

  Future<double> getAccountOpeningBalanceFromJournal(int accountId) async {
    final account = await DatabaseHelper.instance.getAccountById(accountId);
    if (account == null) return 0;

    final journalOpeningTotal =
        await DatabaseHelper.instance.getOpeningBalanceJournalTotal(accountId);

    if (journalOpeningTotal != 0 || account.openingBalance == 0) {
      return journalOpeningTotal;
    }

    return account.openingBalance;
  }

  // =========================
  // DELETE ACCOUNT
  // =========================

  Future deleteAccount(
    int accountId,
  ) async {

    await DatabaseHelper
        .instance
        .deleteAccount(
      accountId,
    );
  }

  // =========================
  // CREATE DEFAULT ACCOUNTS
  // =========================
  // Creates predefined system accounts when a new business is created
  // These accounts MUST exist for the app to function properly:
  // - Cash Account: Required for cash transactions and Cash Book reports
  // - General Expense Account: Required for expense tracking

  Future<void> createDefaultAccounts(
    int businessId,
  ) async {
    final existingCash = await accountExists(businessId, 'Cash');
    final existingExpense = await accountExists(businessId, 'General Expense');
    final existingOpeningBalanceEquity = await accountExists(businessId, 'Opening Balance Equity');

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

  Future<List<TransactionModel>> getTransactionsByAccountId(int accountId) async {
    return await DatabaseHelper.instance.getTransactionsByAccountId(accountId);
  }

  Future<List<JournalLineModel>> getJournalLinesByAccountId(int accountId) async {
    return await DatabaseHelper.instance.getJournalLinesByAccountId(accountId);
  }
}