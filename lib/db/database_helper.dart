import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

    String path = join(
      await getDatabasesPath(),
      'ledger.db',
    );

    print("DATABASE PATH: $path");

    return await openDatabase(
      path,
      version: 1,
      onCreate: onCreate,
    );
  }

  Future onCreate(Database db, int version) async {

    await db.execute('''
    CREATE TABLE business(
      business_id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      created_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE accounts(
      account_id INTEGER PRIMARY KEY AUTOINCREMENT,
      business_id INTEGER,
      name TEXT,
      type TEXT,
      created_at TEXT
    )
    ''');
  }
}