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
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  void notifyDataChanged() {
    dataVersion.value++;
  }

  int? firstIntValue(List<Map<String, Object?>> rows) {
    return Sqflite.firstIntValue(rows);
  }

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
        version: 6,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createInventoryTables(db);
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE items ADD COLUMN image_data TEXT');
          }
          if (oldVersion < 4) {
            await _createCadetTables(db);
          }
          if (oldVersion < 5) {
            await _createTransferTables(db);
          }
          if (oldVersion < 6) {
            await db.execute("ALTER TABLE users ADD COLUMN full_name TEXT NOT NULL DEFAULT ''");
            await db.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'staff'");
            await db.execute("ALTER TABLE users ADD COLUMN can_manage_inventory INTEGER NOT NULL DEFAULT 1");
            await db.execute("ALTER TABLE users ADD COLUMN can_cadet_import_export INTEGER NOT NULL DEFAULT 0");
            await db.execute("ALTER TABLE users ADD COLUMN can_view_collected_inventory INTEGER NOT NULL DEFAULT 0");
          }
        },
        onOpen: (db) async {
          await _seedDefaultUser(db);
          await _seedInventory(db);
          await _seedCadets(db);
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL DEFAULT 'staff',
        can_manage_inventory INTEGER NOT NULL DEFAULT 1,
        can_cadet_import_export INTEGER NOT NULL DEFAULT 0,
        can_view_collected_inventory INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createInventoryTables(db);
    await _createCadetTables(db);
    await _createTransferTables(db);
  }

  Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        box_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        image_key TEXT NOT NULL,
        image_data TEXT,
        FOREIGN KEY (box_id) REFERENCES boxes(id)
      )
    ''');
  }

  Future<void> _createCadetTables(Database db) async {
    await db.execute('''
      CREATE TABLE cadets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cadet_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        photo_data TEXT
      )
    ''');
  }

  Future<void> _createTransferTables(Database db) async {
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cadet_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        action TEXT NOT NULL,
        status TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (cadet_id) REFERENCES cadets(id),
        FOREIGN KEY (item_id) REFERENCES items(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_transfers_cadet ON transfers(cadet_id)');
    await db.execute('CREATE INDEX idx_transfers_item ON transfers(item_id)');
    await db.execute('CREATE INDEX idx_transfers_created ON transfers(created_at)');
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
        'full_name': 'Administrator',
        'role': 'admin',
        'can_manage_inventory': 1,
        'can_cadet_import_export': 1,
        'can_view_collected_inventory': 1,
      });
      return;
    }

    await db.update(
      'users',
      {
        'role': 'admin',
        'can_manage_inventory': 1,
        'can_cadet_import_export': 1,
        'can_view_collected_inventory': 1,
      },
      where: 'username = ?',
      whereArgs: ['admin'],
    );
  }

  Future<void> _seedInventory(Database db) async {
    final batchCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM batches')) ?? 0;
    if (batchCount > 0) {
      return;
    }

    final batchNames = ['Batch A', 'Batch B', 'Batch C', 'Batch D', 'Batch E'];
    final batchIds = <String, int>{};

    for (final batchName in batchNames) {
      final batchId = await db.insert('batches', {'name': batchName});
      batchIds[batchName] = batchId;
    }

    final boxIds = <String, int>{};
    for (final batchName in batchNames) {
      final batchId = batchIds[batchName]!;
      for (var index = 1; index <= 4; index++) {
        final boxName = 'Box ${index.toString().padLeft(2, '0')}';
        final boxId = await db.insert('boxes', {
          'batch_id': batchId,
          'name': boxName,
        });
        boxIds['$batchName-$boxName'] = boxId;
      }
    }

    final items = <Map<String, Object>>[
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Water Bottle',
        'quantity': 35,
        'image_key': 'water_drop',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Gun',
        'quantity': 15,
        'image_key': 'gun',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Vest',
        'quantity': 25,
        'image_key': 'shield',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Binoculars',
        'quantity': 10,
        'image_key': 'visibility',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Walkie Talkie',
        'quantity': 35,
        'image_key': 'radio',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Boots',
        'quantity': 13,
        'image_key': 'hiking',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Hat',
        'quantity': 19,
        'image_key': 'military_tech',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Grenade',
        'quantity': 9,
        'image_key': 'brightness_low',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Helmet',
        'quantity': 33,
        'image_key': 'health_and_safety',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Goggles',
        'quantity': 10,
        'image_key': 'goggles',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Uniform',
        'quantity': 15,
        'image_key': 'checkroom',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Knife',
        'quantity': 8,
        'image_key': 'knife',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Torch',
        'quantity': 33,
        'image_key': 'flashlight_on',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Bullets',
        'quantity': 10,
        'image_key': 'bullets',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Bag',
        'quantity': 15,
        'image_key': 'backpack',
      },
      {
        'box_id': boxIds['Batch A-Box 01']!,
        'name': 'Rope',
        'quantity': 8,
        'image_key': 'rope',
      },
      {
        'box_id': boxIds['Batch A-Box 02']!,
        'name': 'Compass',
        'quantity': 12,
        'image_key': 'explore',
      },
      {
        'box_id': boxIds['Batch A-Box 02']!,
        'name': 'Map Kit',
        'quantity': 7,
        'image_key': 'map',
      },
      {
        'box_id': boxIds['Batch B-Box 01']!,
        'name': 'Medical Pack',
        'quantity': 18,
        'image_key': 'medical_services',
      },
      {
        'box_id': boxIds['Batch B-Box 02']!,
        'name': 'Ration Pack',
        'quantity': 40,
        'image_key': 'lunch_dining',
      },
      {
        'box_id': boxIds['Batch C-Box 01']!,
        'name': 'Signal Light',
        'quantity': 11,
        'image_key': 'light_mode',
      },
      {
        'box_id': boxIds['Batch D-Box 03']!,
        'name': 'Training Manual',
        'quantity': 22,
        'image_key': 'menu_book',
      },
      {
        'box_id': boxIds['Batch E-Box 04']!,
        'name': 'Field Gloves',
        'quantity': 16,
        'image_key': 'front_hand',
      },
    ];

    for (final item in items) {
      await db.insert('items', item);
    }
  }

  Future<void> _seedCadets(Database db) async {
    final cadetCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cadets')) ?? 0;
    if (cadetCount > 0) {
      return;
    }

    const seed = [
      {'cadet_id': '24023100', 'name': 'Daniel'},
      {'cadet_id': '24023141', 'name': 'Swathi'},
      {'cadet_id': '24023200', 'name': 'Kavi'},
      {'cadet_id': '24023167', 'name': 'Subash'},
      {'cadet_id': '24023121', 'name': 'Hanif'},
    ];

    for (final cadet in seed) {
      await db.insert('cadets', cadet);
    }
  }

  Future<bool> authenticate({
    required String username,
    required String password,
  }) async {
    final user = await authenticateUser(username: username, password: password);
    return user != null;
  }

  Future<AppUser?> authenticateUser({
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
    if (users.isEmpty) return null;
    _currentUser = _appUserFromRow(users.first);
    return _currentUser;
  }

  void logoutUser() {
    _currentUser = null;
  }

  Future<void> updateCurrentUserProfile({
    required String fullName,
    String? password,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    final db = await database;
    final values = <String, Object?>{
      'full_name': fullName.trim(),
    };
    if (password != null && password.trim().isNotEmpty) {
      values['password'] = password;
    }
    await db.update(
      'users',
      values,
      where: 'id = ?',
      whereArgs: [user.id],
    );
    _currentUser = user.copyWith(
      fullName: fullName.trim(),
      password: (password != null && password.trim().isNotEmpty) ? password : user.password,
    );
  }

  Future<List<AppUser>> getStaffUsers() async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['staff'],
      orderBy: 'username COLLATE NOCASE',
    );
    return rows.map(_appUserFromRow).toList();
  }

  Future<void> createStaffUser({
    required String username,
    required String password,
    required String fullName,
    required bool canManageInventory,
    required bool canCadetImportExport,
    required bool canViewCollectedInventory,
  }) async {
    final db = await database;
    await db.insert('users', {
      'username': username.trim(),
      'password': password,
      'full_name': fullName.trim(),
      'role': 'staff',
      'can_manage_inventory': canManageInventory ? 1 : 0,
      'can_cadet_import_export': canCadetImportExport ? 1 : 0,
      'can_view_collected_inventory': canViewCollectedInventory ? 1 : 0,
    });
  }

  Future<void> updateStaffPermissions({
    required int userId,
    required bool canManageInventory,
    required bool canCadetImportExport,
    required bool canViewCollectedInventory,
  }) async {
    final db = await database;
    await db.update(
      'users',
      {
        'can_manage_inventory': canManageInventory ? 1 : 0,
        'can_cadet_import_export': canCadetImportExport ? 1 : 0,
        'can_view_collected_inventory': canViewCollectedInventory ? 1 : 0,
      },
      where: 'id = ? AND role = ?',
      whereArgs: [userId, 'staff'],
    );
  }

  Future<void> resetStaffPassword({
    required int userId,
    required String newPassword,
  }) async {
    final db = await database;
    await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ? AND role = ?',
      whereArgs: [userId, 'staff'],
    );
  }

  AppUser _appUserFromRow(Map<String, Object?> row) {
    return AppUser(
      id: row['id'] as int,
      username: row['username'] as String,
      password: row['password'] as String,
      fullName: (row['full_name'] as String?) ?? '',
      role: (row['role'] as String?) ?? 'staff',
      canManageInventory: ((row['can_manage_inventory'] as int?) ?? 1) == 1,
      canCadetImportExport: ((row['can_cadet_import_export'] as int?) ?? 0) == 1,
      canViewCollectedInventory: ((row['can_view_collected_inventory'] as int?) ?? 0) == 1,
    );
  }

  Future<DashboardCounts> getDashboardCounts() async {
    final db = await database;
    final cadetCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cadets')) ?? 0;
    final batchCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM batches')) ?? 0;
    final boxCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM boxes')) ?? 0;
    final itemRowCount = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM items')) ?? 0;
    final itemQuantityCount =
        firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(quantity), 0) FROM items')) ?? 0;
    final givenCount =
        firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(quantity), 0) FROM transfers WHERE action = 'give'")) ??
            0;
    final collectedCount =
        firstIntValue(await db.rawQuery("SELECT COALESCE(SUM(quantity), 0) FROM transfers WHERE action = 'collect'")) ??
            0;

    return DashboardCounts(
      cadets: cadetCount,
      givenItems: givenCount,
      collectedItems: collectedCount,
      batches: batchCount,
      boxes: boxCount,
      itemRows: itemRowCount,
      itemQuantity: itemQuantityCount,
    );
  }

  Future<List<BatchRecord>> getBatches() async {
    final db = await database;
    final rows = await db.query('batches', orderBy: 'name');
    return rows
        .map(
          (row) => BatchRecord(
            id: row['id'] as int,
            name: row['name'] as String,
          ),
        )
        .toList();
  }

  Future<List<BoxRecord>> getBoxesForBatch(int batchId) async {
    final db = await database;
    final rows = await db.query(
      'boxes',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'name',
    );

    return rows
        .map(
          (row) => BoxRecord(
            id: row['id'] as int,
            batchId: row['batch_id'] as int,
            name: row['name'] as String,
          ),
        )
        .toList();
  }

  Future<int> addBatch(String name) async {
    final db = await database;
    final id = await db.insert('batches', {'name': name.trim()});
    notifyDataChanged();
    return id;
  }

  Future<void> renameBatch({
    required int batchId,
    required String name,
  }) async {
    final db = await database;
    await db.update(
      'batches',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [batchId],
    );
    notifyDataChanged();
  }

  Future<int> addBox({
    required int batchId,
    required String name,
  }) async {
    final db = await database;
    final id = await db.insert('boxes', {
      'batch_id': batchId,
      'name': name.trim(),
    });
    notifyDataChanged();
    return id;
  }

  Future<void> renameBox({
    required int boxId,
    required String name,
  }) async {
    final db = await database;
    await db.update(
      'boxes',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [boxId],
    );
    notifyDataChanged();
  }

  Future<List<ItemRecord>> getItemsForBox(
    int boxId, {
    String searchQuery = '',
  }) async {
    final db = await database;
    final trimmedQuery = searchQuery.trim();
    final rows = await db.query(
      'items',
      where: trimmedQuery.isEmpty ? 'box_id = ?' : 'box_id = ? AND name LIKE ?',
      whereArgs: trimmedQuery.isEmpty ? [boxId] : [boxId, '%$trimmedQuery%'],
      orderBy: 'name',
    );

    return rows
        .map(
          (row) => ItemRecord(
            id: row['id'] as int,
            boxId: row['box_id'] as int,
            name: row['name'] as String,
            quantity: row['quantity'] as int,
            imageKey: row['image_key'] as String,
            imageData: row['image_data'] as String?,
          ),
        )
        .toList();
  }

  Future<int> getTotalQuantityForBatch(int batchId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(items.quantity), 0)
      FROM items
      INNER JOIN boxes ON boxes.id = items.box_id
      WHERE boxes.batch_id = ?
      ''',
      [batchId],
    );
    return firstIntValue(result) ?? 0;
  }

  Future<void> addItem({
    required int boxId,
    required String name,
    required int quantity,
    required String imageKey,
    String? imageData,
  }) async {
    final db = await database;
    await db.insert('items', {
      'box_id': boxId,
      'name': name,
      'quantity': quantity,
      'image_key': imageKey,
      'image_data': imageData,
    });
    notifyDataChanged();
  }

  Future<void> updateItem({
    required int itemId,
    required String name,
    required int quantity,
    required String imageKey,
    String? imageData,
  }) async {
    final db = await database;
    await db.update(
      'items',
      {
        'name': name.trim(),
        'quantity': quantity,
        'image_key': imageKey,
        'image_data': imageData,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    notifyDataChanged();
  }

  Future<List<CadetRecord>> getCadets({String searchQuery = ''}) async {
    final db = await database;
    final query = searchQuery.trim();
    final rows = await db.query(
      'cadets',
      where: query.isEmpty ? null : '(name LIKE ? OR cadet_id LIKE ?)',
      whereArgs: query.isEmpty ? null : ['%$query%', '%$query%'],
      orderBy: 'name',
    );

    return rows
        .map(
          (row) => CadetRecord(
            id: row['id'] as int,
            cadetId: row['cadet_id'] as String,
            name: row['name'] as String,
            photoData: row['photo_data'] as String?,
          ),
        )
        .toList();
  }

  Future<List<TransferRecord>> getTransfers({
    String searchQuery = '',
    String action = 'all',
    int? cadetDbId,
    int limit = 50,
  }) async {
    final db = await database;
    final query = searchQuery.trim();
    final whereClauses = <String>[];
    final args = <Object?>[];

    if (action != 'all') {
      whereClauses.add('t.action = ?');
      args.add(action);
    }
    if (cadetDbId != null) {
      whereClauses.add('t.cadet_id = ?');
      args.add(cadetDbId);
    }
    if (query.isNotEmpty) {
      whereClauses.add('(c.name LIKE ? OR c.cadet_id LIKE ?)');
      args.add('%$query%');
      args.add('%$query%');
    }

    final whereSql = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT
        t.id,
        t.cadet_id,
        t.item_id,
        t.quantity,
        t.action,
        t.status,
        t.created_at,
        c.name AS cadet_name,
        c.cadet_id AS cadet_code,
        i.name AS item_name,
        b.name AS box_name,
        ba.name AS batch_name
      FROM transfers t
      INNER JOIN cadets c ON c.id = t.cadet_id
      INNER JOIN items i ON i.id = t.item_id
      INNER JOIN boxes b ON b.id = i.box_id
      INNER JOIN batches ba ON ba.id = b.batch_id
      $whereSql
      ORDER BY t.created_at DESC
      LIMIT ?
      ''',
      [...args, limit],
    );

    return rows
        .map(
          (row) => TransferRecord(
            id: row['id'] as int,
            cadetDbId: row['cadet_id'] as int,
            itemId: row['item_id'] as int,
            quantity: row['quantity'] as int,
            action: row['action'] as String,
            status: row['status'] as String?,
            createdAtMillis: row['created_at'] as int,
            cadetName: row['cadet_name'] as String,
            cadetCode: row['cadet_code'] as String,
            itemName: row['item_name'] as String,
            batchName: row['batch_name'] as String,
            boxName: row['box_name'] as String,
          ),
        )
        .toList();
  }

  Future<List<ItemRecord>> searchItemsAcrossInventory(String searchQuery) async {
    final db = await database;
    final query = searchQuery.trim();
    if (query.isEmpty) {
      return const [];
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        i.id,
        i.box_id,
        i.name,
        i.quantity,
        i.image_key,
        i.image_data
      FROM items i
      WHERE i.name LIKE ?
      ORDER BY i.name
      LIMIT 250
      ''',
      ['%$query%'],
    );

    return rows
        .map(
          (row) => ItemRecord(
            id: row['id'] as int,
            boxId: row['box_id'] as int,
            name: row['name'] as String,
            quantity: row['quantity'] as int,
            imageKey: row['image_key'] as String,
            imageData: row['image_data'] as String?,
          ),
        )
        .toList();
  }

  Future<List<CadetHistorySummary>> getCadetHistorySummaries({
    String searchQuery = '',
    String action = 'all',
    int limit = 200,
  }) async {
    final db = await database;
    final query = searchQuery.trim();
    final whereClause = query.isEmpty ? '' : 'WHERE (c.name LIKE ? OR c.cadet_id LIKE ?)';
    final whereArgs = query.isEmpty ? <Object?>[] : ['%$query%', '%$query%'];
    final joinActionClause = action == 'all' ? '' : ' AND t.action = ?';
    final actionArgs = action == 'all' ? <Object?>[] : <Object?>[action];

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id AS cadet_db_id,
        c.cadet_id AS cadet_code,
        c.name AS cadet_name,
        c.photo_data AS cadet_photo,
        COALESCE(SUM(CASE WHEN t.action = 'give' THEN t.quantity ELSE 0 END), 0) AS total_given,
        COALESCE(SUM(CASE WHEN t.action = 'collect' THEN t.quantity ELSE 0 END), 0) AS total_collected,
        COALESCE(MAX(t.created_at), 0) AS last_activity_at,
        COALESCE(
          (
            SELECT tx.action
            FROM transfers tx
            WHERE tx.cadet_id = c.id
            ORDER BY tx.created_at DESC, tx.id DESC
            LIMIT 1
          ),
          ''
        ) AS last_action
      FROM cadets c
      LEFT JOIN transfers t ON t.cadet_id = c.id$joinActionClause
      $whereClause
      GROUP BY c.id
      ORDER BY last_activity_at DESC, c.name ASC
      LIMIT ?
      ''',
      [...actionArgs, ...whereArgs, limit],
    );

    return rows
        .map(
          (row) => CadetHistorySummary(
            cadetDbId: row['cadet_db_id'] as int,
            cadetCode: row['cadet_code'] as String,
            cadetName: row['cadet_name'] as String,
            photoData: row['cadet_photo'] as String?,
            totalGiven: row['total_given'] as int,
            totalCollected: row['total_collected'] as int,
            lastActivityMillis: row['last_activity_at'] as int,
            lastAction: row['last_action'] as String,
          ),
        )
        .toList();
  }

  Future<int> getCadetHoldingQuantity({
    required int cadetDbId,
    required int itemId,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE WHEN action = 'give' THEN quantity ELSE -quantity END
      ), 0) AS held
      FROM transfers
      WHERE cadet_id = ? AND item_id = ?
      ''',
      [cadetDbId, itemId],
    );
    return (rows.first['held'] as int?) ?? 0;
  }

  Future<List<CadetHoldingRecord>> getCadetHoldings(int cadetDbId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        i.id AS item_id,
        i.name AS item_name,
        i.image_key AS image_key,
        i.image_data AS image_data,
        b.name AS box_name,
        ba.name AS batch_name,
        COALESCE(SUM(CASE WHEN t.action = 'give' THEN t.quantity ELSE -t.quantity END), 0) AS held,
        COALESCE(MAX(CASE WHEN t.action = 'give' THEN t.created_at END), 0) AS latest_taken_at
      FROM transfers t
      INNER JOIN items i ON i.id = t.item_id
      INNER JOIN boxes b ON b.id = i.box_id
      INNER JOIN batches ba ON ba.id = b.batch_id
      WHERE t.cadet_id = ?
      GROUP BY i.id
      HAVING held > 0
      ORDER BY i.name
      ''',
      [cadetDbId],
    );

    return rows
        .map(
          (row) => CadetHoldingRecord(
            itemId: row['item_id'] as int,
            itemName: row['item_name'] as String,
            imageKey: row['image_key'] as String,
            imageData: row['image_data'] as String?,
            batchName: row['batch_name'] as String,
            boxName: row['box_name'] as String,
            quantityHeld: row['held'] as int,
            latestTakenAtMillis: row['latest_taken_at'] as int,
          ),
        )
        .toList();
  }

  Future<void> giveItem({
    required int cadetDbId,
    required int itemId,
    required int quantity,
  }) async {
    await giveItems(
      cadetDbId: cadetDbId,
      items: [TransferInput(itemId: itemId, quantity: quantity)],
    );
  }

  Future<void> giveItems({
    required int cadetDbId,
    required List<TransferInput> items,
  }) async {
    if (items.isEmpty) {
      throw StateError('No items selected');
    }
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in items) {
        final rows = await txn.query(
          'items',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [entry.itemId],
          limit: 1,
        );
        final currentQty = rows.isEmpty ? 0 : (rows.first['quantity'] as int);
        if (entry.quantity <= 0 || currentQty < entry.quantity) {
          throw StateError('Not enough stock');
        }

        await txn.update(
          'items',
          {'quantity': currentQty - entry.quantity},
          where: 'id = ?',
          whereArgs: [entry.itemId],
        );

        await txn.insert('transfers', {
          'cadet_id': cadetDbId,
          'item_id': entry.itemId,
          'quantity': entry.quantity,
          'action': 'give',
          'status': null,
          'created_at': now,
        });
      }
    });
    notifyDataChanged();
  }

  Future<void> collectItem({
    required int cadetDbId,
    required int itemId,
    required int quantity,
    required String status,
  }) async {
    await collectItems(
      cadetDbId: cadetDbId,
      items: [
        CollectInput(
          itemId: itemId,
          quantity: quantity,
          status: status,
        ),
      ],
    );
  }

  Future<void> collectItems({
    required int cadetDbId,
    required List<CollectInput> items,
  }) async {
    if (items.isEmpty) {
      throw StateError('No items selected');
    }
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in items) {
        final holdingRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(
            CASE WHEN action = 'give' THEN quantity ELSE -quantity END
          ), 0) AS held
          FROM transfers
          WHERE cadet_id = ? AND item_id = ?
          ''',
          [cadetDbId, entry.itemId],
        );
        final held = (holdingRows.first['held'] as int?) ?? 0;
        if (entry.quantity <= 0 || held < entry.quantity) {
          throw StateError('Not enough held quantity');
        }

        await txn.insert('transfers', {
          'cadet_id': cadetDbId,
          'item_id': entry.itemId,
          'quantity': entry.quantity,
          'action': 'collect',
          'status': entry.status,
          'created_at': now,
        });

        if (entry.status != 'missing') {
          final itemRows = await txn.query(
            'items',
            columns: ['quantity'],
            where: 'id = ?',
            whereArgs: [entry.itemId],
            limit: 1,
          );
          final currentQty = itemRows.isEmpty ? 0 : (itemRows.first['quantity'] as int);
          await txn.update(
            'items',
            {'quantity': currentQty + entry.quantity},
            where: 'id = ?',
            whereArgs: [entry.itemId],
          );
        }
      }
    });
    notifyDataChanged();
  }

  Future<int> addCadet({
    required String cadetId,
    required String name,
    String? photoData,
  }) async {
    final db = await database;
    final id = await db.insert('cadets', {
      'cadet_id': cadetId.trim(),
      'name': name.trim(),
      'photo_data': photoData,
    });
    notifyDataChanged();
    return id;
  }

  Future<void> updateCadet({
    required int id,
    required String cadetId,
    required String name,
    String? photoData,
  }) async {
    final db = await database;
    await db.update(
      'cadets',
      {
        'cadet_id': cadetId.trim(),
        'name': name.trim(),
        'photo_data': photoData,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
  }

  Future<void> deleteCadet({required int id}) async {
    final db = await database;                          
    await db.delete(
      'cadets',
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
  }
}

class DashboardCounts {
  const DashboardCounts({
    required this.cadets,
    required this.givenItems,
    required this.collectedItems,
    required this.batches,
    required this.boxes,
    required this.itemRows,
    required this.itemQuantity,
  });

  final int cadets;
  final int givenItems;
  final int collectedItems;
  final int batches;
  final int boxes;
  final int itemRows;
  final int itemQuantity;
}

class BatchRecord {
  const BatchRecord({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class BoxRecord {
  const BoxRecord({
    required this.id,
    required this.batchId,
    required this.name,
  });

  final int id;
  final int batchId;
  final String name;
}

class ItemRecord {
  const ItemRecord({
    required this.id,
    required this.boxId,
    required this.name,
    required this.quantity,
    required this.imageKey,
    required this.imageData,
  });

  final int id;
  final int boxId;
  final String name;
  final int quantity;
  final String imageKey;
  final String? imageData;
}

class CadetRecord {
  const CadetRecord({
    required this.id,
    required this.cadetId,
    required this.name,
    required this.photoData,
  });

  final int id;
  final String cadetId;
  final String name;
  final String? photoData;
}

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.cadetDbId,
    required this.itemId,
    required this.quantity,
    required this.action,
    required this.status,
    required this.createdAtMillis,
    required this.cadetName,
    required this.cadetCode,
    required this.itemName,
    required this.batchName,
    required this.boxName,
  });

  final int id;
  final int cadetDbId;
  final int itemId;
  final int quantity;
  final String action;
  final String? status;
  final int createdAtMillis;
  final String cadetName;
  final String cadetCode;
  final String itemName;
  final String batchName;
  final String boxName;
}

class TransferInput {
  const TransferInput({
    required this.itemId,
    required this.quantity,
  });

  final int itemId;
  final int quantity;
}

class CollectInput {
  const CollectInput({
    required this.itemId,
    required this.quantity,
    required this.status,
  });

  final int itemId;
  final int quantity;
  final String status;
}

class CadetHistorySummary {
  const CadetHistorySummary({
    required this.cadetDbId,
    required this.cadetCode,
    required this.cadetName,
    required this.photoData,
    required this.totalGiven,
    required this.totalCollected,
    required this.lastActivityMillis,
    required this.lastAction,
  });

  CadetRecord toCadetRecord() {
    return CadetRecord(
      id: cadetDbId,
      cadetId: cadetCode,
      name: cadetName,
      photoData: photoData,
    );
  }

  final int cadetDbId;
  final String cadetCode;
  final String cadetName;
  final String? photoData;
  final int totalGiven;
  final int totalCollected;
  final int lastActivityMillis;
  final String lastAction;
}

class CadetHoldingRecord {
  const CadetHoldingRecord({
    required this.itemId,
    required this.itemName,
    required this.imageKey,
    required this.imageData,
    required this.batchName,
    required this.boxName,
    required this.quantityHeld,
    required this.latestTakenAtMillis,
  });

  final int itemId;
  final String itemName;
  final String imageKey;
  final String? imageData;
  final String batchName;
  final String boxName;
  final int quantityHeld;
  final int latestTakenAtMillis;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    required this.canManageInventory,
    required this.canCadetImportExport,
    required this.canViewCollectedInventory,
  });

  final int id;
  final String username;
  final String password;
  final String fullName;
  final String role;
  final bool canManageInventory;
  final bool canCadetImportExport;
  final bool canViewCollectedInventory;

  bool get isAdmin => role == 'admin';

  AppUser copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? role,
    bool? canManageInventory,
    bool? canCadetImportExport,
    bool? canViewCollectedInventory,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      canManageInventory: canManageInventory ?? this.canManageInventory,
      canCadetImportExport: canCadetImportExport ?? this.canCadetImportExport,
      canViewCollectedInventory: canViewCollectedInventory ?? this.canViewCollectedInventory,
    );
  }
}
