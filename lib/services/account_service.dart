import '../db/database_helper.dart';
import '../models/account_model.dart';

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
}