import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'military_app.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL
          )
        ''');
      },
      onOpen: (db) async {
        await _seedDefaultUser(db);
      },
    );
  }

  Future<void> _seedDefaultUser(Database db) async {
    final existingUsers = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
      limit: 1,
    );

    if (existingUsers.isEmpty) {
      await db.insert('users', {
        'username': 'admin',
        'password': '123',
      });
    }
  }

  Future<bool> authenticate({
    required String username,
    required String password,
  }) async {
    final db = await database;
    final users = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    return users.isNotEmpty;
  }
}
