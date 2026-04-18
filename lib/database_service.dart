import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static Database? _database;
  static bool _isFactoryInitialized = false;

  Future<void> initialize() async {
    if (_isFactoryInitialized) {
      return;
    }

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          break;
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          break;
      }
    }

    _isFactoryInitialized = true;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    await initialize();
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await databaseFactory.getDatabasesPath();
    final path = p.join(databasesPath, 'military_app.db');

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
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
      ),
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
