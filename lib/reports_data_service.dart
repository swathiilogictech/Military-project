import 'dart:convert';

import 'database_service.dart';

class ReportsDataService {
  ReportsDataService._();

  static final ReportsDataService instance = ReportsDataService._();

  Future<List<CadetReportRow>> fetchCadetRows({
    String searchQuery = '',
    int? fromMillis,
    int? toMillis,
  }) async {
    final db = await DatabaseService.instance.database;
    final query = searchQuery.trim();
    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    final transferArgs = <Object?>[];

    if (query.isNotEmpty) {
      whereParts.add('(c.name LIKE ? OR c.cadet_id LIKE ?)');
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
    }

    final transferFilter = <String>[];
    if (fromMillis != null) {
      transferFilter.add('t.created_at >= ?');
      transferArgs.add(fromMillis);
    }
    if (toMillis != null) {
      transferFilter.add('t.created_at <= ?');
      transferArgs.add(toMillis);
    }
    final transferJoinExtra = transferFilter.isEmpty ? '' : ' AND ${transferFilter.join(' AND ')}';
    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id AS cadet_db_id,
        c.cadet_id AS cadet_code,
        c.name AS cadet_name,
        COALESCE(SUM(CASE WHEN t.action = 'give' THEN t.quantity ELSE 0 END), 0) AS total_given,
        COALESCE(SUM(CASE WHEN t.action = 'collect' THEN t.quantity ELSE 0 END), 0) AS total_collected,
        COALESCE(MAX(t.created_at), 0) AS last_activity
      FROM cadets c
      LEFT JOIN transfers t ON t.cadet_id = c.id$transferJoinExtra
      $whereSql
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE
      ''',
      [...transferArgs, ...whereArgs],
    );

    return rows
        .map(
          (row) => CadetReportRow(
            cadetDbId: row['cadet_db_id'] as int,
            cadetId: row['cadet_code'] as String,
            name: row['cadet_name'] as String,
            totalGiven: row['total_given'] as int,
            totalCollected: row['total_collected'] as int,
            lastActivityMillis: row['last_activity'] as int,
          ),
        )
        .toList();
  }

  Future<List<InventoryReportRow>> fetchInventoryRows({
    String searchQuery = '',
    int? batchId,
    int? boxId,
    bool lowStockOnly = false,
    int lowStockThreshold = 10,
  }) async {
    final db = await DatabaseService.instance.database;
    final query = searchQuery.trim();
    final whereParts = <String>[];
    final args = <Object?>[];

    if (query.isNotEmpty) {
      whereParts.add('i.name LIKE ?');
      args.add('%$query%');
    }
    if (batchId != null) {
      whereParts.add('ba.id = ?');
      args.add(batchId);
    }
    if (boxId != null) {
      whereParts.add('b.id = ?');
      args.add(boxId);
    }
    if (lowStockOnly) {
      whereParts.add('i.quantity <= ?');
      args.add(lowStockThreshold);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT
        i.id AS item_id,
        i.name AS item_name,
        i.quantity AS quantity,
        b.name AS box_name,
        ba.name AS batch_name
      FROM items i
      INNER JOIN boxes b ON b.id = i.box_id
      INNER JOIN batches ba ON ba.id = b.batch_id
      $whereSql
      ORDER BY ba.name, b.name, i.name COLLATE NOCASE
      ''',
      args,
    );

    return rows
        .map(
          (row) => InventoryReportRow(
            itemId: row['item_id'] as int,
            itemName: row['item_name'] as String,
            quantity: row['quantity'] as int,
            batchName: row['batch_name'] as String,
            boxName: row['box_name'] as String,
          ),
        )
        .toList();
  }

  Future<List<HistoryReportRow>> fetchHistoryRows({
    String searchQuery = '',
    String action = 'all',
    String status = 'all',
    int? fromMillis,
    int? toMillis,
    int limit = 1000,
  }) async {
    final db = await DatabaseService.instance.database;
    final query = searchQuery.trim();
    final whereParts = <String>[];
    final args = <Object?>[];

    if (query.isNotEmpty) {
      whereParts.add('(c.name LIKE ? OR c.cadet_id LIKE ? OR i.name LIKE ?)');
      args.add('%$query%');
      args.add('%$query%');
      args.add('%$query%');
    }
    if (action != 'all') {
      whereParts.add('t.action = ?');
      args.add(action);
    }
    if (status != 'all') {
      if (status == 'none') {
        whereParts.add('(t.status IS NULL OR t.status = "")');
      } else {
        whereParts.add('t.status = ?');
        args.add(status);
      }
    }
    if (fromMillis != null) {
      whereParts.add('t.created_at >= ?');
      args.add(fromMillis);
    }
    if (toMillis != null) {
      whereParts.add('t.created_at <= ?');
      args.add(toMillis);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT
        t.id AS transfer_id,
        t.created_at AS created_at,
        t.action AS action,
        t.status AS status,
        t.quantity AS quantity,
        c.cadet_id AS cadet_code,
        c.name AS cadet_name,
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
          (row) => HistoryReportRow(
            transferId: row['transfer_id'] as int,
            createdAtMillis: row['created_at'] as int,
            action: row['action'] as String,
            status: row['status'] as String?,
            quantity: row['quantity'] as int,
            cadetId: row['cadet_code'] as String,
            cadetName: row['cadet_name'] as String,
            itemName: row['item_name'] as String,
            boxName: row['box_name'] as String,
            batchName: row['batch_name'] as String,
          ),
        )
        .toList();
  }

  Future<PortableDataPackage> buildPortableDataPackage() async {
    final db = await DatabaseService.instance.database;
    final batches = await db.query('batches', orderBy: 'id');
    final boxes = await db.query('boxes', orderBy: 'id');
    final items = await db.query('items', orderBy: 'id');
    final cadets = await db.query('cadets', orderBy: 'id');
    final transfers = await db.query('transfers', orderBy: 'id');

    return PortableDataPackage(
      exportedAtMillis: DateTime.now().millisecondsSinceEpoch,
      batches: batches,
      boxes: boxes,
      items: items,
      cadets: cadets,
      transfers: transfers,
    );
  }

  Future<ImportResult> importPortableDataPackage(Map<String, dynamic> jsonMap) async {
    final db = await DatabaseService.instance.database;
    final batches = _listFromJson(jsonMap['batches']);
    final boxes = _listFromJson(jsonMap['boxes']);
    final items = _listFromJson(jsonMap['items']);
    final cadets = _listFromJson(jsonMap['cadets']);
    final transfers = _listFromJson(jsonMap['transfers']);

    await db.transaction((txn) async {
      await txn.delete('transfers');
      await txn.delete('items');
      await txn.delete('boxes');
      await txn.delete('batches');
      await txn.delete('cadets');

      for (final row in batches) {
        await txn.insert('batches', row);
      }
      for (final row in boxes) {
        await txn.insert('boxes', row);
      }
      for (final row in items) {
        await txn.insert('items', row);
      }
      for (final row in cadets) {
        await txn.insert('cadets', row);
      }
      for (final row in transfers) {
        await txn.insert('transfers', row);
      }
    });
    DatabaseService.instance.notifyDataChanged();

    return ImportResult(
      cadets: cadets.length,
      items: items.length,
      transfers: transfers.length,
    );
  }

  List<Map<String, Object?>> _listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(
              key.toString(),
              _normalizeValue(value),
            ),
          ),
        )
        .toList();
  }

  Object? _normalizeValue(Object? value) {
    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toInt();
      }
      return value.toDouble();
    }
    return value;
  }

  String packageToJson(PortableDataPackage data) {
    return const JsonEncoder.withIndent('  ').convert(data.toJson());
  }

  /// Merges transfers from another device's exported JSON into this device.
  /// 
  /// Rules:
  ///  - Only transfers are merged (cadets/items/batches/boxes are identical on all devices)
  ///  - Cadets are matched by cadet_id TEXT (e.g. "24023200"), not by DB integer id
  ///  - Duplicate detection: cadet_id + item_id + quantity + action + created_at must all match
  ///  - items.quantity is adjusted for every new transfer inserted
  ///  - Safe to run multiple times — duplicates are always skipped
  Future<MergeResult> mergeTransfersFromPackage(Map<String, dynamic> jsonMap) async {
    final db = await DatabaseService.instance.database;

    // ── 1. Parse incoming data ──────────────────────────────────────────────
    final incomingTransfers = _listFromJson(jsonMap['transfers']);
    final incomingCadets    = _listFromJson(jsonMap['cadets']);

    if (incomingTransfers.isEmpty) {
      return const MergeResult(inserted: 0, skipped: 0, failed: 0);
    }

    // ── 2. Build incoming dbId → cadet_id TEXT map ─────────────────────────
    // (DB integer IDs may differ across devices if new cadets were added)
    final incomingIdToCode = <int, String>{};
    for (final c in incomingCadets) {
      final id   = c['id'];
      final code = c['cadet_id'];
      if (id is int && code is String) {
        incomingIdToCode[id] = code;
      }
    }

    // ── 3. Build local cadet_id TEXT → local DB id map ────────────────────
    final localCadets = await db.query('cadets', columns: ['id', 'cadet_id']);
    final localCodeToId = <String, int>{};
    for (final c in localCadets) {
      localCodeToId[c['cadet_id'] as String] = c['id'] as int;
    }

    // ── 4. Load existing transfer fingerprints for duplicate detection ──────
    // Fingerprint = "localCadetDbId|itemId|quantity|action|createdAt"
    final existing = await db.query(
      'transfers',
      columns: ['cadet_id', 'item_id', 'quantity', 'action', 'created_at'],
    );
    final seen = <String>{};
    for (final t in existing) {
      seen.add(
        '${t['cadet_id']}|${t['item_id']}|${t['quantity']}|${t['action']}|${t['created_at']}',
      );
    }

    // ── 5. Merge in a single transaction ───────────────────────────────────
    int inserted = 0;
    int skipped  = 0;
    int failed   = 0;

    await db.transaction((txn) async {
      for (final t in incomingTransfers) {
        // Resolve cadet
        final incomingCadetDbId = t['cadet_id'];
        if (incomingCadetDbId is! int) { failed++; continue; }

        final cadetCode = incomingIdToCode[incomingCadetDbId];
        if (cadetCode == null)         { failed++; continue; }

        final localCadetId = localCodeToId[cadetCode];
        if (localCadetId == null)      { failed++; continue; }

        // Parse fields
        final itemId    = t['item_id']    as int?;
        final quantity  = t['quantity']   as int?;
        final action    = t['action']     as String?;
        final createdAt = t['created_at'] as int?;
        final status    = t['status']     as String?;

        if (itemId == null || quantity == null || action == null || createdAt == null) {
          failed++;
          continue;
        }

        // Duplicate check
        final fp = '$localCadetId|$itemId|$quantity|$action|$createdAt';
        if (seen.contains(fp)) { skipped++; continue; }
        seen.add(fp); // guard against duplicates within the same import file

        // Insert the transfer
        await txn.insert('transfers', {
          'cadet_id'  : localCadetId,
          'item_id'   : itemId,
          'quantity'  : quantity,
          'action'    : action,
          'status'    : status,
          'created_at': createdAt,
        });

        // Adjust item quantity
        final itemRows = await txn.query(
          'items',
          columns  : ['quantity'],
          where    : 'id = ?',
          whereArgs: [itemId],
          limit    : 1,
        );
        if (itemRows.isNotEmpty) {
          final currentQty = itemRows.first['quantity'] as int;
          int newQty = currentQty;

          if (action == 'give') {
            // Another device gave this item — reduce master stock
            newQty = (currentQty - quantity).clamp(0, currentQty);
          } else if (action == 'collect' && status != 'missing') {
            // Another device collected this item — increase master stock
            newQty = currentQty + quantity;
          }

          if (newQty != currentQty) {
            await txn.update(
              'items',
              {'quantity': newQty},
              where    : 'id = ?',
              whereArgs: [itemId],
            );
          }
        }

        inserted++;
      }
    });

    DatabaseService.instance.notifyDataChanged();

    return MergeResult(inserted: inserted, skipped: skipped, failed: failed);
  }
}

class CadetReportRow {
  const CadetReportRow({
    required this.cadetDbId,
    required this.cadetId,
    required this.name,
    required this.totalGiven,
    required this.totalCollected,
    required this.lastActivityMillis,
  });

  final int cadetDbId;
  final String cadetId;
  final String name;
  final int totalGiven;
  final int totalCollected;
  final int lastActivityMillis;
}

class InventoryReportRow {
  const InventoryReportRow({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.batchName,
    required this.boxName,
  });

  final int itemId;
  final String itemName;
  final int quantity;
  final String batchName;
  final String boxName;
}

class HistoryReportRow {
  const HistoryReportRow({
    required this.transferId,
    required this.createdAtMillis,
    required this.action,
    required this.status,
    required this.quantity,
    required this.cadetId,
    required this.cadetName,
    required this.itemName,
    required this.boxName,
    required this.batchName,
  });

  final int transferId;
  final int createdAtMillis;
  final String action;
  final String? status;
  final int quantity;
  final String cadetId;
  final String cadetName;
  final String itemName;
  final String boxName;
  final String batchName;
}

class PortableDataPackage {
  const PortableDataPackage({
    required this.exportedAtMillis,
    required this.batches,
    required this.boxes,
    required this.items,
    required this.cadets,
    required this.transfers,
  });

  final int exportedAtMillis;
  final List<Map<String, Object?>> batches;
  final List<Map<String, Object?>> boxes;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> cadets;
  final List<Map<String, Object?>> transfers;

  Map<String, Object?> toJson() {
    return {
      'schema': 'military_app_package_v1',
      'exported_at': exportedAtMillis,
      'batches': batches,
      'boxes': boxes,
      'items': items,
      'cadets': cadets,
      'transfers': transfers,
    };
  }
}

class ImportResult {
  const ImportResult({
    required this.cadets,
    required this.items,
    required this.transfers,
  });

  final int cadets;
  final int items;
  final int transfers;
}

class MergeResult {
  const MergeResult({
    required this.inserted,
    required this.skipped,
    required this.failed,
  });

  final int inserted;
  final int skipped;
  final int failed;
}
