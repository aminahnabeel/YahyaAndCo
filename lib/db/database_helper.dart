import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account_model.dart';
import '../models/business_model.dart';
import '../models/calculator_history_model.dart';
import '../models/expense_category_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/note_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initDB();

    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'ledger.db');

    print("DATABASE PATH: $path");

    return await openDatabase(
      path,
      version: 4,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'transactions', 'image_url', 'TEXT');
      await _addColumnIfMissing(db, 'journal_entry', 'image_url', 'TEXT');
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'journal_entry', 'created_at', 'TEXT');
    }

    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'transactions', 'due_date', 'TEXT');
      await _addColumnIfMissing(db, 'transactions', 'payment_status', 'TEXT');
      await _addColumnIfMissing(db, 'transactions', 'remaining_amount', 'REAL DEFAULT 0');
      await _addColumnIfMissing(db, 'journal_entry', 'due_date', 'TEXT');
      await _addColumnIfMissing(db, 'journal_entry', 'payment_status', 'TEXT');
      await _addColumnIfMissing(db, 'journal_entry', 'remaining_amount', 'REAL DEFAULT 0');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasColumn = columns.any((column) => column['name'] == columnName);

    if (!hasColumn) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
    }
  }

  Future onCreate(Database db, int version) async {
    // =========================
    // BUSINESS TABLE
    // =========================

    await db.execute('''
    CREATE TABLE business(

      business_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      name TEXT,

      type TEXT,

      pin TEXT,

      created_at TEXT
    )
    ''');

    // =========================
    // ACCOUNTS TABLE
    // =========================

    await db.execute('''
    CREATE TABLE accounts(

      account_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      business_id INTEGER,

      name TEXT,

      type TEXT,

      phone TEXT,

      address TEXT,

      opening_balance REAL,

      created_at TEXT
    )
    ''');

    // =========================
    // TRANSACTIONS TABLE
    // =========================

    await db.execute('''
    CREATE TABLE transactions(

      transaction_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      business_id INTEGER,

      account_id INTEGER,

      amount REAL,

      type TEXT,

      note TEXT,

      payment_method TEXT,

      due_date TEXT,

      payment_status TEXT,

      remaining_amount REAL DEFAULT 0,

      image_url TEXT,

      date TEXT,

      created_at TEXT
    )
    ''');

    // =========================
    // JOURNAL ENTRY TABLE
    // =========================

    await db.execute('''
    CREATE TABLE journal_entry(

      journal_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      business_id INTEGER,

      transaction_id INTEGER,

      description TEXT,

      image_url TEXT,

      date TEXT,

      voucher_no TEXT,

      voucher_type TEXT,

      due_date TEXT,

      payment_status TEXT,

      remaining_amount REAL DEFAULT 0,

      created_at TEXT
    )
    ''');

    // =========================
    // JOURNAL LINES TABLE
    // =========================

    await db.execute('''
    CREATE TABLE journal_lines(

      line_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      journal_id INTEGER,

      account_id INTEGER,

      debit REAL,

      credit REAL
    )
    ''');

    // =========================
    // EXPENSE CATEGORY TABLE
    // =========================

    await db.execute('''
    CREATE TABLE expense_categories(

      category_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      business_id INTEGER,

      name TEXT
    )
    ''');

    // =========================
    // CALCULATOR HISTORY TABLE
    // =========================

    await db.execute('''
    CREATE TABLE calculator_history(

      history_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      expression TEXT,

      result TEXT,

      created_at TEXT
    )
    ''');

    // =========================
    // NOTES TABLE
    // =========================

    await db.execute('''
    CREATE TABLE notes(

      note_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      business_id INTEGER,

      title TEXT,

      description TEXT,

      created_at TEXT
    )
    ''');

    // =========================
    // USERS TABLE
    // =========================

    await db.execute('''
    CREATE TABLE users(

      user_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      firebase_uid TEXT,

      name TEXT,

      email TEXT,

      password TEXT,

      is_verified INTEGER,

      created_at TEXT
    )
    ''');
  }

  // ======================================================
  // USER METHODS
  // ======================================================

  Future<int> insertUser(UserModel user) async {
    final db = await database;

    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserByFirebaseUid(String uid) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'firebase_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return UserModel.fromMap(maps.first);
  }

  Future updateUser(UserModel user) async {
    final db = await database;

    await db.update(
      'users',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  // ======================================================
  // BUSINESS METHODS
  // ======================================================

  Future<int> insertBusiness(BusinessModel business) async {
    final db = await database;

    // Insert business and create default system accounts atomically
    return await db.transaction<int>((txn) async {
      final businessId = await txn.insert('business', business.toMap());

      final now = business.createdAt;

      // Default accounts: Cash (Asset), General Expense (Expense), Owner Capital (Equity)
      await txn.insert('accounts', {
        'business_id': businessId,
        'name': 'Cash',
        'type': 'Asset',
        'phone': null,
        'address': null,
        'opening_balance': 0,
        'created_at': now,
      });

      await txn.insert('accounts', {
        'business_id': businessId,
        'name': 'General Expense',
        'type': 'Expense',
        'phone': null,
        'address': null,
        'opening_balance': 0,
        'created_at': now,
      });

      await txn.insert('accounts', {
        'business_id': businessId,
        'name': 'Owner Capital',
        'type': 'Equity',
        'phone': null,
        'address': null,
        'opening_balance': 0,
        'created_at': now,
      });

      return businessId;
    });
  }

  Future<List<BusinessModel>> getBusinesses() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'business',

      orderBy: 'business_id DESC',
    );

    return List.generate(maps.length, (index) {
      return BusinessModel.fromMap(maps[index]);
    });
  }

  Future<BusinessModel?> getBusinessById(int businessId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'business',
      where: 'business_id = ?',
      whereArgs: [businessId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return BusinessModel.fromMap(maps.first);
  }

  Future<BusinessModel?> getLatestBusiness() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'business',
      orderBy: 'business_id DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return BusinessModel.fromMap(maps.first);
  }

  Future updateBusiness(BusinessModel business) async {
    final db = await database;

    await db.update(
      'business',

      business.toMap(),

      where: 'business_id = ?',

      whereArgs: [business.businessId],
    );
  }

  Future deleteBusiness(int businessId) async {
    final db = await database;

    await db.delete(
      'business',

      where: 'business_id = ?',

      whereArgs: [businessId],
    );
  }

  // ======================================================
  // ACCOUNT METHODS
  // ======================================================

  Future<int> insertAccount(AccountModel account) async {
    final db = await database;

    return await db.insert('accounts', account.toMap());
  }

  Future<List<AccountModel>> getAccountsByBusiness(int businessId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',

      where: 'business_id = ?',

      whereArgs: [businessId],

      orderBy: 'account_id DESC',
    );

    return List.generate(maps.length, (index) {
      return AccountModel.fromMap(maps[index]);
    });
  }

  Future<AccountModel?> getAccountById(int accountId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return AccountModel.fromMap(maps.first);
  }

  Future updateAccount(AccountModel account) async {
    final db = await database;

    await db.update(
      'accounts',

      account.toMap(),

      where: 'account_id = ?',

      whereArgs: [account.accountId],
    );
  }

  Future deleteAccount(int accountId) async {
    final db = await database;

    await db.delete(
      'accounts',

      where: 'account_id = ?',

      whereArgs: [accountId],
    );
  }

  // ======================================================
  // TRANSACTION METHODS
  // ======================================================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;

    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getTransactionsByBusiness(
    int businessId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',

      where: 'business_id = ?',

      whereArgs: [businessId],

      orderBy: 'transaction_id DESC',
    );

    return List.generate(maps.length, (index) {
      return TransactionModel.fromMap(maps[index]);
    });
  }

  Future<List<Map<String, dynamic>>> getTransactionLedgerRows(int businessId) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT
        transactions.transaction_id,
        transactions.business_id,
        transactions.account_id,
        transactions.amount,
        transactions.type,
        transactions.note,
        transactions.payment_method,
        transactions.due_date,
        transactions.payment_status,
        transactions.remaining_amount,
        transactions.image_url,
        transactions.date,
        transactions.created_at,
        accounts.name AS account_name
      FROM transactions
      INNER JOIN accounts ON accounts.account_id = transactions.account_id
      WHERE transactions.business_id = ?
      ORDER BY transactions.transaction_id DESC
      ''', [businessId]);
  }

  Future updateTransaction(TransactionModel transaction) async {
    final db = await database;

    await db.update(
      'transactions',

      transaction.toMap(),

      where: 'transaction_id = ?',

      whereArgs: [transaction.transactionId],
    );
  }

  Future deleteTransaction(int transactionId) async {
    final db = await database;

    await db.delete(
      'transactions',

      where: 'transaction_id = ?',

      whereArgs: [transactionId],
    );
  }

  // ======================================================
  // JOURNAL ENTRY METHODS
  // ======================================================

  Future<int> insertJournalEntry(JournalEntryModel journal) async {
    final db = await database;

    return await db.insert('journal_entry', journal.toMap());
  }

  Future<List<JournalEntryModel>> getJournalEntries(int businessId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entry',

      where: 'business_id = ?',

      whereArgs: [businessId],
    );

    return List.generate(maps.length, (index) {
      return JournalEntryModel.fromMap(maps[index]);
    });
  }

  Future<List<Map<String, dynamic>>> getJournalLedgerRows(int businessId) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT
        journal_entry.journal_id,
        journal_entry.business_id,
        journal_entry.transaction_id,
        journal_entry.description,
        journal_entry.voucher_no,
        journal_entry.voucher_type,
        journal_entry.due_date,
        journal_entry.payment_status,
        journal_entry.remaining_amount,
        journal_entry.image_url,
        journal_entry.date,
        journal_entry.created_at,
        journal_lines.account_id,
        journal_lines.debit,
        journal_lines.credit,
        accounts.name AS account_name
      FROM journal_entry
      INNER JOIN journal_lines ON journal_lines.journal_id = journal_entry.journal_id
      INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
      WHERE journal_entry.business_id = ?
      ORDER BY journal_entry.journal_id DESC, journal_lines.line_id ASC
      ''', [businessId]);
  }

  Future<JournalEntryModel?> getJournalEntryByTransactionId(int transactionId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entry',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return JournalEntryModel.fromMap(maps.first);
  }

  Future updateJournalEntry(JournalEntryModel journal) async {
    final db = await database;

    return await db.update(
      'journal_entry',
      journal.toMap(),
      where: 'journal_id = ?',
      whereArgs: [journal.journalId],
    );
  }

  Future deleteJournalEntry(int journalId) async {
    final db = await database;

    return await db.delete(
      'journal_entry',
      where: 'journal_id = ?',
      whereArgs: [journalId],
    );
  }

  // ======================================================
  // JOURNAL LINE METHODS
  // ======================================================

  Future<int> insertJournalLine(JournalLineModel line) async {
    final db = await database;

    return await db.insert('journal_lines', line.toMap());
  }

  Future<List<JournalLineModel>> getJournalLines(int journalId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_lines',

      where: 'journal_id = ?',

      whereArgs: [journalId],
    );

    return List.generate(maps.length, (index) {
      return JournalLineModel.fromMap(maps[index]);
    });
  }

  // ======================================================
  // EXPENSE CATEGORY METHODS
  // ======================================================

  Future<int> insertExpenseCategory(ExpenseCategoryModel category) async {
    final db = await database;

    return await db.insert('expense_categories', category.toMap());
  }

  Future<List<ExpenseCategoryModel>> getExpenseCategories(
    int businessId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'expense_categories',

      where: 'business_id = ?',

      whereArgs: [businessId],
    );

    return List.generate(maps.length, (index) {
      return ExpenseCategoryModel.fromMap(maps[index]);
    });
  }

  // ======================================================
  // NOTE METHODS
  // ======================================================

  Future<int> insertNote(NoteModel note) async {
    final db = await database;

    return await db.insert('notes', note.toMap());
  }

  Future<List<NoteModel>> getNotes(int businessId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'notes',

      where: 'business_id = ?',

      whereArgs: [businessId],

      orderBy: 'note_id DESC',
    );

    return List.generate(maps.length, (index) {
      return NoteModel.fromMap(maps[index]);
    });
  }

  // ======================================================
  // CALCULATOR HISTORY METHODS
  // ======================================================

  Future<void> insertCalculatorHistory(CalculatorHistoryModel history) async {
    final db = await database;

    // INSERT NEW HISTORY

    await db.insert('calculator_history', history.toMap());

    // TOTAL COUNT

    final List<Map<String, dynamic>> countResult = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM calculator_history
      ''');

    int total = countResult.first['total'] as int;

    // KEEP ONLY LATEST 10

    if (total > 10) {
      await db.rawDelete('''
        DELETE FROM calculator_history

        WHERE history_id NOT IN (

          SELECT history_id

          FROM calculator_history

          ORDER BY history_id DESC

          LIMIT 10
        )
        ''');
    }
  }

  Future<List<CalculatorHistoryModel>> getCalculatorHistory() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'calculator_history',

      orderBy: 'history_id DESC',
    );

    return List.generate(maps.length, (index) {
      return CalculatorHistoryModel.fromMap(maps[index]);
    });
  }

  Future clearCalculatorHistory() async {
    final db = await database;

    await db.delete('calculator_history');
  }

  // ======================================================
  // ACCOUNT BALANCE METHODS
  // ======================================================

  Future<List<TransactionModel>> getTransactionsByAccountId(int accountId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (index) {
      return TransactionModel.fromMap(maps[index]);
    });
  }

  Future<List<JournalLineModel>> getJournalLinesByAccountId(int accountId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_lines',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    return List.generate(maps.length, (index) {
      return JournalLineModel.fromMap(maps[index]);
    });
  }

  Future<double> getAccountClosingBalance(int accountId) async {
    final account = await getAccountById(accountId);
    if (account == null) return 0;

    double balance = account.openingBalance;

    // Get all journal lines for this account
    final journalLines = await getJournalLinesByAccountId(accountId);
    for (var line in journalLines) {
      balance += line.debit;
      balance -= line.credit;
    }

    // Get all transactions for this account
    final transactions = await getTransactionsByAccountId(accountId);
    for (var transaction in transactions) {
      if (transaction.type.toLowerCase() == 'debit' || transaction.type.toLowerCase() == 'deposit') {
        balance += transaction.amount;
      } else if (transaction.type.toLowerCase() == 'credit' || transaction.type.toLowerCase() == 'withdrawal') {
        balance -= transaction.amount;
      }
    }

    return balance;
  }
}
