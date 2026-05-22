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

    await DatabaseHelper
        .instance
        .updateAccount(
      account,
    );
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

    if (existingCash && existingExpense) {
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