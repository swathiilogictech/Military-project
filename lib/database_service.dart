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
        version: 5,
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
        password TEXT NOT NULL
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
      });
    }
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
    final db = await database;
    final users = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    return users.isNotEmpty;
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
    return db.insert('batches', {'name': name.trim()});
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
  }

  Future<int> addBox({
    required int batchId,
    required String name,
  }) async {
    final db = await database;
    return db.insert('boxes', {
      'batch_id': batchId,
      'name': name.trim(),
    });
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
        COALESCE(SUM(CASE WHEN t.action = 'give' THEN t.quantity ELSE -t.quantity END), 0) AS held
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
          ),
        )
        .toList();
  }

  Future<void> giveItem({
    required int cadetDbId,
    required int itemId,
    required int quantity,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      final currentQty = rows.isEmpty ? 0 : (rows.first['quantity'] as int);
      if (quantity <= 0 || currentQty < quantity) {
        throw StateError('Not enough stock');
      }

      await txn.update(
        'items',
        {'quantity': currentQty - quantity},
        where: 'id = ?',
        whereArgs: [itemId],
      );

      await txn.insert('transfers', {
        'cadet_id': cadetDbId,
        'item_id': itemId,
        'quantity': quantity,
        'action': 'give',
        'status': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> collectItem({
    required int cadetDbId,
    required int itemId,
    required int quantity,
    required String status,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final holdingRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(
          CASE WHEN action = 'give' THEN quantity ELSE -quantity END
        ), 0) AS held
        FROM transfers
        WHERE cadet_id = ? AND item_id = ?
        ''',
        [cadetDbId, itemId],
      );
      final held = (holdingRows.first['held'] as int?) ?? 0;
      if (quantity <= 0 || held < quantity) {
        throw StateError('Not enough held quantity');
      }

      await txn.insert('transfers', {
        'cadet_id': cadetDbId,
        'item_id': itemId,
        'quantity': quantity,
        'action': 'collect',
        'status': status,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (status != 'missing') {
        final itemRows = await txn.query(
          'items',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [itemId],
          limit: 1,
        );
        final currentQty = itemRows.isEmpty ? 0 : (itemRows.first['quantity'] as int);
        await txn.update(
          'items',
          {'quantity': currentQty + quantity},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    });
  }

  Future<int> addCadet({
    required String cadetId,
    required String name,
    String? photoData,
  }) async {
    final db = await database;
    return db.insert('cadets', {
      'cadet_id': cadetId.trim(),
      'name': name.trim(),
      'photo_data': photoData,
    });
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

class CadetHoldingRecord {
  const CadetHoldingRecord({
    required this.itemId,
    required this.itemName,
    required this.imageKey,
    required this.imageData,
    required this.batchName,
    required this.boxName,
    required this.quantityHeld,
  });

  final int itemId;
  final String itemName;
  final String imageKey;
  final String? imageData;
  final String batchName;
  final String boxName;
  final int quantityHeld;
}
