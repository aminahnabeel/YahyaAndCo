import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account_model.dart';
import '../models/business_model.dart';
import '../models/calculator_history_model.dart';
import '../models/expense_category_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/note_model.dart';
import '../models/reminder_model.dart';
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
      version: 7,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
      await _addColumnIfMissing(
        db,
        'transactions',
        'remaining_amount',
        'REAL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'journal_entry', 'due_date', 'TEXT');
      await _addColumnIfMissing(db, 'journal_entry', 'payment_status', 'TEXT');
      await _addColumnIfMissing(
        db,
        'journal_entry',
        'remaining_amount',
        'REAL DEFAULT 0',
      );
    }

    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'transactions', 'to_account_id', 'INTEGER');
    }

    if (oldVersion < 6) {
      // Add Firestore ID column to business table
      await _addColumnIfMissing(db, 'business', 'firestore_id', 'TEXT');
    }

    if (oldVersion < 7) {
      // Ensure Firestore ID columns exist for sync
      await _addColumnIfMissing(db, 'accounts', 'firestore_id', 'TEXT');
      await _addColumnIfMissing(db, 'transactions', 'firestore_id', 'TEXT');
      await _addColumnIfMissing(db, 'journal_entry', 'firestore_id', 'TEXT');
      await _addColumnIfMissing(db, 'journal_lines', 'firestore_id', 'TEXT');

      // Create indexes to speed up lookups by Firestore ID
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_business_firestore_id ON business(firestore_id);',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_firestore_id ON accounts(firestore_id);',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_firestore_id ON transactions(firestore_id);',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_entry_firestore_id ON journal_entry(firestore_id);',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_lines_firestore_id ON journal_lines(firestore_id);',
      );

      // Ensure reminders table exists for older DB versions
      await _createRemindersTable(db);
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
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
      );
    }
  }

  Future<void> _createRemindersTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS reminders(
      reminder_id TEXT PRIMARY KEY,
      business_id INTEGER NOT NULL,
      record_type TEXT NOT NULL,
      record_id INTEGER NOT NULL,
      account_id INTEGER,
      voucher_no TEXT,
      payment_method TEXT,
      voucher_type TEXT,
      account_name TEXT,
      date TEXT,
      transaction_id INTEGER,
      journal_id INTEGER,
      amount REAL NOT NULL DEFAULT 0,
      remaining_amount REAL NOT NULL DEFAULT 0,
      due_date TEXT,
      payment_status TEXT NOT NULL,
      description TEXT,
      source_table TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT NOT NULL,
      UNIQUE(business_id, record_type, record_id),
      FOREIGN KEY(business_id) REFERENCES business(business_id) ON DELETE CASCADE
    )
    ''');
  }
  // ======================================================
  // REMINDER METHODS
  // ======================================================

  Future onCreate(Database db, int version) async {
    // =========================
    // BUSINESS TABLE
    // =========================

    await db.execute('''
    CREATE TABLE business(

      business_id INTEGER
      PRIMARY KEY AUTOINCREMENT,

      firestore_id TEXT UNIQUE,

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

      firestore_id TEXT UNIQUE,

      name TEXT,

      type TEXT,

      phone TEXT,

      address TEXT,

      opening_balance REAL,

      created_at TEXT,

      FOREIGN KEY(business_id) REFERENCES business(business_id) ON DELETE CASCADE
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

      firestore_id TEXT UNIQUE,

      amount REAL,

      type TEXT,

      note TEXT,

      payment_method TEXT,

      due_date TEXT,

      payment_status TEXT,

      remaining_amount REAL DEFAULT 0,

      image_url TEXT,

      date TEXT,

      created_at TEXT,

      FOREIGN KEY(business_id) REFERENCES business(business_id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(account_id) ON DELETE SET NULL
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

      firestore_id TEXT UNIQUE,

      description TEXT,

      image_url TEXT,

      date TEXT,

      voucher_no TEXT,

      voucher_type TEXT,

      due_date TEXT,

      payment_status TEXT,

      remaining_amount REAL DEFAULT 0,

      created_at TEXT,

      FOREIGN KEY(business_id) REFERENCES business(business_id) ON DELETE CASCADE,
      FOREIGN KEY(transaction_id) REFERENCES transactions(transaction_id) ON DELETE SET NULL
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

      firestore_id TEXT UNIQUE,

      debit REAL,

      credit REAL,

      FOREIGN KEY(journal_id) REFERENCES journal_entry(journal_id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
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

    await _createRemindersTable(db);
  }

  // ======================================================
  // REMINDER METHODS
  // ======================================================

  Future<List<Map<String, dynamic>>> getReminderSourceRows(
    int businessId,
  ) async {
    final db = await database;

    return await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT
          'Transaction' AS record_type,
          t.transaction_id AS record_id,
          t.transaction_id AS transaction_id,
          NULL AS journal_id,
          t.account_id AS account_id,
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
          MIN(jl.account_id) AS account_id,
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

  Future<void> upsertReminder(ReminderModel reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReminderModel>> getRemindersByBusiness(int businessId) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'due_date DESC, updated_at DESC, record_id DESC',
    );
    return maps.map(ReminderModel.fromMap).toList();
  }

  Future<void> deleteReminder(String reminderId, int businessId) async {
    final db = await database;
    await db.delete(
      'reminders',
      where: 'reminder_id = ? AND business_id = ?',
      whereArgs: [reminderId, businessId],
    );
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

  Future<int> upsertBusiness(BusinessModel business) async {
    final db = await database;

    final map = business.toMap()..remove('business_id');
    if (business.firestoreId == null || business.firestoreId!.trim().isEmpty) {
      return await db.insert(
        'business',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existing = await db.query(
      'business',
      where: 'firestore_id = ?',
      whereArgs: [business.firestoreId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localBusinessId = existing.first['business_id'] as int;
      await db.update(
        'business',
        map,
        where: 'business_id = ?',
        whereArgs: [localBusinessId],
      );
      return localBusinessId;
    }

    return await db.insert(
      'business',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<void> updateAccountFirestoreId(
    int accountId,
    String firestoreId,
  ) async {
    final db = await database;

    await db.update(
      'accounts',
      {'firestore_id': firestoreId},
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  Future<String?> getAccountFirestoreId(int accountId) async {
    final db = await database;

    final maps = await db.query(
      'accounts',
      columns: ['firestore_id'],
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['firestore_id'] as String?;
  }

  Future<int> upsertAccount(Map<String, dynamic> account) async {
    final db = await database;
    final firestoreId = account['firestore_id'];

    final accountMap = Map<String, dynamic>.from(account)..remove('account_id');

    if (firestoreId == null || firestoreId.toString().trim().isEmpty) {
      return await db.insert(
        'accounts',
        accountMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existing = await db.query(
      'accounts',
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localAccountId = existing.first['account_id'] as int;
      await db.update(
        'accounts',
        accountMap,
        where: 'account_id = ?',
        whereArgs: [localAccountId],
      );
      return localAccountId;
    }

    return await db.insert(
      'accounts',
      accountMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

    // Ensure to_account_id column exists
    await _addColumnIfMissing(db, 'transactions', 'to_account_id', 'INTEGER');

    return await db.insert('transactions', transaction.toMap());
  }

  Future<void> updateTransactionFirestoreId(
    int transactionId,
    String firestoreId,
  ) async {
    final db = await database;

    await db.update(
      'transactions',
      {'firestore_id': firestoreId},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<String?> getTransactionFirestoreId(int transactionId) async {
    final db = await database;

    final maps = await db.query(
      'transactions',
      columns: ['firestore_id'],
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['firestore_id'] as String?;
  }

  Future<int> upsertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final firestoreId = transaction['firestore_id'];
    final sanitizedTransaction = <String, dynamic>{
      'business_id': transaction['business_id'],
      'account_id': transaction['account_id'],
      'to_account_id': transaction['to_account_id'],
      'firestore_id': transaction['firestore_id'],
      'amount': transaction['amount'],
      'type': transaction['type'],
      'note': transaction['note'],
      'payment_method': transaction['payment_method'],
      'due_date': transaction['due_date'],
      'payment_status': transaction['payment_status'],
      'remaining_amount': transaction['remaining_amount'],
      'image_url': transaction['image_url'],
      'date': transaction['date'],
      'created_at': transaction['created_at'],
    };

    if (firestoreId == null || firestoreId.toString().trim().isEmpty) {
      return await db.insert(
        'transactions',
        sanitizedTransaction,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existing = await db.query(
      'transactions',
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localTransactionId = existing.first['transaction_id'] as int;
      await db.update(
        'transactions',
        sanitizedTransaction,
        where: 'transaction_id = ?',
        whereArgs: [localTransactionId],
      );
      return localTransactionId;
    }

    return await db.insert(
      'transactions',
      sanitizedTransaction,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<TransactionModel?> getTransactionById(int transactionId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<int> upsertJournalEntry(Map<String, dynamic> journalEntry) async {
    final db = await database;
    final firestoreId = journalEntry['firestore_id'];
    final journalMap = Map<String, dynamic>.from(journalEntry)
      ..remove('journal_id');

    if (firestoreId == null || firestoreId.toString().trim().isEmpty) {
      return await db.insert(
        'journal_entry',
        journalMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existing = await db.query(
      'journal_entry',
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localJournalId = existing.first['journal_id'] as int;
      await db.update(
        'journal_entry',
        journalMap,
        where: 'journal_id = ?',
        whereArgs: [localJournalId],
      );
      return localJournalId;
    }

    return await db.insert(
      'journal_entry',
      journalMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateJournalFirestoreId(
    int journalId,
    String firestoreId,
  ) async {
    final db = await database;

    await db.update(
      'journal_entry',
      {'firestore_id': firestoreId},
      where: 'journal_id = ?',
      whereArgs: [journalId],
    );
  }

  Future<String?> getJournalFirestoreId(int journalId) async {
    final db = await database;

    final maps = await db.query(
      'journal_entry',
      columns: ['firestore_id'],
      where: 'journal_id = ?',
      whereArgs: [journalId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['firestore_id'] as String?;
  }

  Future<int> upsertJournalLine(Map<String, dynamic> journalLine) async {
    final db = await database;
    final firestoreId = journalLine['firestore_id'];
    final sanitizedLine = <String, dynamic>{
      'journal_id': journalLine['journal_id'],
      'account_id': journalLine['account_id'],
      'firestore_id': journalLine['firestore_id'],
      'debit': journalLine['debit'],
      'credit': journalLine['credit'],
    };
    sanitizedLine.remove('line_id');

    if (firestoreId == null || firestoreId.toString().trim().isEmpty) {
      return await db.insert(
        'journal_lines',
        sanitizedLine,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existing = await db.query(
      'journal_lines',
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localLineId = existing.first['line_id'] as int;
      await db.update(
        'journal_lines',
        sanitizedLine,
        where: 'line_id = ?',
        whereArgs: [localLineId],
      );
      return localLineId;
    }

    return await db.insert(
      'journal_lines',
      sanitizedLine,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionLedgerRows(
    int businessId,
  ) async {
    final db = await database;

    return await db.rawQuery(
      '''
      SELECT
        transactions.transaction_id,
        transactions.business_id,
        transactions.account_id,
        (SELECT voucher_no FROM journal_entry
         WHERE journal_entry.transaction_id = transactions.transaction_id
           AND UPPER(journal_entry.voucher_type) = 'CP'
         LIMIT 1) AS voucher_no,
        'CP' AS voucher_type,
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
      LEFT JOIN accounts ON accounts.account_id = transactions.account_id
      WHERE transactions.business_id = ?
        AND EXISTS (
          SELECT 1 FROM journal_entry
          WHERE journal_entry.transaction_id = transactions.transaction_id
            AND UPPER(journal_entry.voucher_type) = 'CP'
        )
      ORDER BY transactions.transaction_id DESC
      ''',
      [businessId],
    );
  }

  Future updateTransaction(TransactionModel transaction) async {
    final db = await database;

    // Ensure to_account_id column exists
    await _addColumnIfMissing(db, 'transactions', 'to_account_id', 'INTEGER');

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

  Future<JournalEntryModel?> getJournalEntryById(int journalId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entry',
      where: 'journal_id = ?',
      whereArgs: [journalId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return JournalEntryModel.fromMap(maps.first);
  }

  Future<List<Map<String, dynamic>>> getJournalLedgerRows(
    int businessId,
  ) async {
    final db = await database;

    return await db.rawQuery(
      '''
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
      ''',
      [businessId],
    );
  }

  Future<JournalEntryModel?> getJournalEntryByTransactionId(
    int transactionId,
  ) async {
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

  Future<int?> getJournalEntryByFirestoreId(String firestoreId) async {
    final db = await database;

    final maps = await db.query(
      'journal_entry',
      columns: ['journal_id'],
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['journal_id'] as int?;
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

  Future<void> updateJournalTransactionId(
    int journalId,
    int? transactionId,
  ) async {
    final db = await database;

    await db.update(
      'journal_entry',
      {'transaction_id': transactionId},
      where: 'journal_id = ?',
      whereArgs: [journalId],
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

  Future<void> deleteJournalLines(int journalId) async {
    final db = await database;

    await db.delete(
      'journal_lines',
      where: 'journal_id = ?',
      whereArgs: [journalId],
    );
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

  Future<List<TransactionModel>> getTransactionsByAccountId(
    int accountId,
  ) async {
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

  Future<List<JournalLineModel>> getJournalLinesByAccountId(
    int accountId,
  ) async {
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

  Future<int> getOrCreateOpeningBalanceEquityAccount(int businessId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'business_id = ? AND LOWER(name) = ?',
      whereArgs: [businessId, 'opening balance equity'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first['account_id'] as int;
    }

    final equityAccount = AccountModel(
      businessId: businessId,
      name: 'Opening Balance Equity',
      type: 'Equity',
      phone: null,
      address: null,
      openingBalance: 0,
      createdAt: DateTime.now().toIso8601String(),
    );

    return await insertAccount(equityAccount);
  }

  Future<int> insertOpeningBalanceJournalEntry(
    int businessId,
    int accountId,
    double amount,
  ) async {
    if (amount == 0) return 0;

    final now = DateTime.now().toIso8601String();

    final journalEntry = JournalEntryModel(
      businessId: businessId,
      transactionId: null,
      voucherNo: 'OB-${DateTime.now().millisecondsSinceEpoch}',
      voucherType: 'OB',
      description: 'Opening Balance',
      paymentStatus: 'Paid',
      remainingAmount: 0,
      date: now,
      createdAt: now,
    );

    final journalId = await insertJournalEntry(journalEntry);
    final equityAccountId = await getOrCreateOpeningBalanceEquityAccount(
      businessId,
    );

    final accountLine = JournalLineModel(
      journalId: journalId,
      accountId: accountId,
      debit: amount < 0 ? amount.abs() : 0.0,
      credit: amount > 0 ? amount : 0.0,
    );

    final equityLine = JournalLineModel(
      journalId: journalId,
      accountId: equityAccountId,
      debit: amount > 0 ? amount : 0.0,
      credit: amount < 0 ? amount.abs() : 0.0,
    );

    await insertJournalLine(accountLine);
    await insertJournalLine(equityLine);
    return journalId;
  }

  Future<double> getOpeningBalanceJournalTotal(int accountId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(jl.credit), 0) AS totalCredit,
        COALESCE(SUM(jl.debit), 0) AS totalDebit
      FROM journal_lines jl
      INNER JOIN journal_entry je ON je.journal_id = jl.journal_id
      WHERE jl.account_id = ?
        AND je.voucher_type = 'OB'
      ''',
      [accountId],
    );

    final totalCredit =
        (result.first['totalCredit'] as num?)?.toDouble() ?? 0.0;
    final totalDebit = (result.first['totalDebit'] as num?)?.toDouble() ?? 0.0;
    return totalCredit - totalDebit;
  }

  Future<double> getAccountClosingBalance(int accountId) async {
    final account = await getAccountById(accountId);
    if (account == null) return 0;

    double balance = account.openingBalance;

    // Get all journal lines for this account (source of truth)
    final journalLines = await getJournalLinesByAccountId(accountId);
    for (var line in journalLines) {
      balance -= line.debit; // Debit = Money OUT (decreases balance)
      balance += line.credit; // Credit = Money IN (increases balance)
    }

    return balance;
  }
}
