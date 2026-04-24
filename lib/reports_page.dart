import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';
import 'reports_data_service.dart';
import 'web_download.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _cadetSearchController = TextEditingController();
  final TextEditingController _inventorySearchController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();

  DateTime? _fromDate;
  DateTime _toDate = DateTime.now();

  int? _inventoryBatchId;
  int? _inventoryBoxId;
  bool _inventoryLowStockOnly = false;
  int _inventoryLowStockThreshold = 10;

  String _historyAction = 'all';
  String _historyStatus = 'all';

  List<BatchRecord> _batches = const [];
  List<BoxRecord> _boxes = const [];
  List<CadetReportRow> _cadetRows = const [];
  List<InventoryReportRow> _inventoryRows = const [];
  List<HistoryReportRow> _historyRows = const [];
  List<File> _downloadFiles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadCurrentTab();
    });
    _loadInitial();
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    _tabController.dispose();
    _cadetSearchController.dispose();
    _inventorySearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  int? get _fromMillis => _fromDate == null ? null : _startOfDay(_fromDate!).millisecondsSinceEpoch;
  int? get _toMillis => _endOfDay(_toDate).millisecondsSinceEpoch;

  void _handleDataChanged() {
    if (!mounted) return;
    _reloadSourcesThenCurrentTab();
  }

  Future<void> _reloadSourcesThenCurrentTab() async {
    final batches = await DatabaseService.instance.getBatches();
    final nextBatchId = batches.any((b) => b.id == _inventoryBatchId)
        ? _inventoryBatchId
        : (batches.isEmpty ? null : batches.first.id);
    final boxes = nextBatchId == null
        ? const <BoxRecord>[]
        : await DatabaseService.instance.getBoxesForBatch(nextBatchId);
    final nextBoxId = boxes.any((b) => b.id == _inventoryBoxId)
        ? _inventoryBoxId
        : (boxes.isEmpty ? null : boxes.first.id);

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _inventoryBatchId = nextBatchId;
      _boxes = boxes;
      _inventoryBoxId = nextBoxId;
    });
    await _loadCurrentTab();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final batches = await DatabaseService.instance.getBatches();
    final batchId = batches.isEmpty ? null : batches.first.id;
    final boxes =
        batchId == null ? const <BoxRecord>[] : await DatabaseService.instance.getBoxesForBatch(batchId);

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _inventoryBatchId = batchId;
      _boxes = boxes;
      _inventoryBoxId = boxes.isEmpty ? null : boxes.first.id;
    });
    await _refreshDownloads();
    await _loadCurrentTab();
  }

  Future<void> _loadCurrentTab() async {
    setState(() => _loading = true);
    try {
      switch (_tabController.index) {
        case 0:
          final rows = await ReportsDataService.instance.fetchCadetRows(
            searchQuery: _cadetSearchController.text,
            fromMillis: _fromMillis,
            toMillis: _toMillis,
          );
          if (!mounted) return;
          setState(() {
            _cadetRows = rows;
          });
          break;
        case 1:
          final rows = await ReportsDataService.instance.fetchInventoryRows(
            searchQuery: _inventorySearchController.text,
            batchId: _inventoryBatchId,
            boxId: _inventoryBoxId,
            lowStockOnly: _inventoryLowStockOnly,
            lowStockThreshold: _inventoryLowStockThreshold,
          );
          if (!mounted) return;
          setState(() {
            _inventoryRows = rows;
          });
          break;
        case 2:
          final rows = await ReportsDataService.instance.fetchHistoryRows(
            searchQuery: _historySearchController.text,
            action: _historyAction,
            status: _historyStatus,
            fromMillis: _fromMillis,
            toMillis: _toMillis,
            limit: 2000,
          );
          if (!mounted) return;
          setState(() {
            _historyRows = rows;
          });
          break;
        default:
          await _refreshDownloads();
      }
    } catch (_) {
      if (!mounted) return;
      _toast('Unable to load this tab right now.');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<Directory?> _downloadsDir() async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'report_downloads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _refreshDownloads() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() => _downloadFiles = const []);
      return;
    }
    try {
      final dir = await _downloadsDir();
      final files = dir!
          .listSync()
          .whereType<File>()
          .where((f) {
            final ext = p.extension(f.path).toLowerCase();
            return ext == '.pdf' || ext == '.csv' || ext == '.json';
          })
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (!mounted) return;
      setState(() {
        _downloadFiles = files;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloadFiles = const [];
      });
    }
  }

  Future<void> _pickFromDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    setState(() {
      _fromDate = date;
    });
    await _loadCurrentTab();
  }

  Future<void> _pickToDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    setState(() {
      _toDate = date;
    });
    await _loadCurrentTab();
  }

  Future<void> _changeBatch(int? batchId) async {
    if (batchId == null) return;
    final boxes = await DatabaseService.instance.getBoxesForBatch(batchId);
    if (!mounted) return;
    setState(() {
      _inventoryBatchId = batchId;
      _boxes = boxes;
      _inventoryBoxId = boxes.isEmpty ? null : boxes.first.id;
    });
    await _loadCurrentTab();
  }

  Future<void> _shareTabExport({required bool asPdf}) async {
    switch (_tabController.index) {
      case 0:
        await _exportCadetTab(asPdf: asPdf);
        break;
      case 1:
        await _exportInventoryTab(asPdf: asPdf);
        break;
      default:
        await _exportHistoryTab(asPdf: asPdf);
    }
  }

  Future<void> _exportCadetTab({required bool asPdf}) async {
    final rows = await ReportsDataService.instance.fetchCadetRows(
      searchQuery: _cadetSearchController.text,
      fromMillis: _fromMillis,
      toMillis: _toMillis,
    );
    final filePrefix = 'cadets_${_stamp(DateTime.now())}';
    if (asPdf) {
      final bytes = await _buildPdfBytes(
        title: 'Cadets List Report',
        headers: const ['Cadet ID', 'Name', 'Given', 'Collected', 'Holding', 'Last Activity'],
        rows: rows
            .map(
              (row) => [
                row.cadetId,
                row.name,
                '${row.totalGiven}',
                '${row.totalCollected}',
                '${row.totalGiven - row.totalCollected}',
                row.lastActivityMillis == 0 ? '-' : _human(row.lastActivityMillis),
              ],
            )
            .toList(),
      );
      await _shareBytes(
        bytes: bytes,
        filename: '$filePrefix.pdf',
        mimeType: 'application/pdf',
        text: 'Cadets report PDF',
      );
      return;
    }
    final csv = _buildCsv(
      headers: const ['Cadet ID', 'Name', 'Given', 'Collected', 'Holding', 'Last Activity'],
      rows: rows
          .map(
            (row) => [
              row.cadetId,
              row.name,
              '${row.totalGiven}',
              '${row.totalCollected}',
              '${row.totalGiven - row.totalCollected}',
              row.lastActivityMillis == 0 ? '' : _human(row.lastActivityMillis),
            ],
          )
          .toList(),
    );
    await _shareBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename: '$filePrefix.csv',
      mimeType: 'text/csv',
      text: 'Cadets report Excel file',
    );
  }

  Future<void> _exportInventoryTab({required bool asPdf}) async {
    final rows = await ReportsDataService.instance.fetchInventoryRows(
      searchQuery: _inventorySearchController.text,
      batchId: _inventoryBatchId,
      boxId: _inventoryBoxId,
      lowStockOnly: _inventoryLowStockOnly,
      lowStockThreshold: _inventoryLowStockThreshold,
    );
    final filePrefix = 'inventory_${_stamp(DateTime.now())}';
    if (asPdf) {
      final bytes = await _buildPdfBytes(
        title: 'Inventory List Report',
        headers: const ['Batch', 'Box', 'Item', 'Stock'],
        rows: rows
            .map((row) => [row.batchName, row.boxName, row.itemName, '${row.quantity}'])
            .toList(),
      );
      await _shareBytes(
        bytes: bytes,
        filename: '$filePrefix.pdf',
        mimeType: 'application/pdf',
        text: 'Inventory report PDF',
      );
      return;
    }
    final csv = _buildCsv(
      headers: const ['Batch', 'Box', 'Item', 'Stock'],
      rows: rows.map((row) => [row.batchName, row.boxName, row.itemName, '${row.quantity}']).toList(),
    );
    await _shareBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename: '$filePrefix.csv',
      mimeType: 'text/csv',
      text: 'Inventory report Excel file',
    );
  }

  Future<void> _exportHistoryTab({required bool asPdf}) async {
    final rows = await ReportsDataService.instance.fetchHistoryRows(
      searchQuery: _historySearchController.text,
      action: _historyAction,
      status: _historyStatus,
      fromMillis: _fromMillis,
      toMillis: _toMillis,
      limit: 5000,
    );
    final filePrefix = 'history_${_stamp(DateTime.now())}';
    if (asPdf) {
      final bytes = await _buildPdfBytes(
        title: 'History Report',
        headers: const ['Date', 'Cadet', 'Item', 'Action', 'Status', 'Qty', 'Location'],
        rows: rows
            .map(
              (row) => [
                _human(row.createdAtMillis),
                '${row.cadetName} (${row.cadetId})',
                row.itemName,
                row.action,
                row.status ?? '-',
                '${row.quantity}',
                '${row.batchName} / ${row.boxName}',
              ],
            )
            .toList(),
      );
      await _shareBytes(
        bytes: bytes,
        filename: '$filePrefix.pdf',
        mimeType: 'application/pdf',
        text: 'History report PDF',
      );
      return;
    }
    final csv = _buildCsv(
      headers: const ['Date', 'Cadet ID', 'Cadet Name', 'Item', 'Action', 'Status', 'Qty', 'Batch', 'Box'],
      rows: rows
          .map(
            (row) => [
              _human(row.createdAtMillis),
              row.cadetId,
              row.cadetName,
              row.itemName,
              row.action,
              row.status ?? '',
              '${row.quantity}',
              row.batchName,
              row.boxName,
            ],
          )
          .toList(),
    );
    await _shareBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename: '$filePrefix.csv',
      mimeType: 'text/csv',
      text: 'History report Excel file',
    );
  }

  Future<void> _shareAllRecords({required bool asPdf}) async {
    final cadets = await ReportsDataService.instance.fetchCadetRows(
      fromMillis: _fromMillis,
      toMillis: _toMillis,
    );
    final inventory = await ReportsDataService.instance.fetchInventoryRows();
    final history = await ReportsDataService.instance.fetchHistoryRows(
      fromMillis: _fromMillis,
      toMillis: _toMillis,
      limit: 100000,
    );

    final stamp = _stamp(DateTime.now());
    if (asPdf) {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (_) => [
            _pdfTable(
              title: 'Cadets List',
              headers: const ['Cadet ID', 'Name', 'Given', 'Collected', 'Holding'],
              rows: cadets
                  .map((row) => [
                        row.cadetId,
                        row.name,
                        '${row.totalGiven}',
                        '${row.totalCollected}',
                        '${row.totalGiven - row.totalCollected}',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            _pdfTable(
              title: 'Inventory List',
              headers: const ['Batch', 'Box', 'Item', 'Stock'],
              rows: inventory
                  .map((row) => [row.batchName, row.boxName, row.itemName, '${row.quantity}'])
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            _pdfTable(
              title: 'History',
              headers: const ['Date', 'Cadet', 'Item', 'Action', 'Status', 'Qty'],
              rows: history
                  .map((row) => [
                        _human(row.createdAtMillis),
                        '${row.cadetName} (${row.cadetId})',
                        row.itemName,
                        row.action,
                        row.status ?? '-',
                        '${row.quantity}',
                      ])
                  .toList(),
            ),
          ],
        ),
      );
      await _shareBytes(
        bytes: await pdf.save(),
        filename: 'all_records_$stamp.pdf',
        mimeType: 'application/pdf',
        text: 'All records PDF',
      );
      return;
    }

    final cadetCsv = _buildCsv(
      headers: const ['Cadet ID', 'Name', 'Given', 'Collected', 'Holding', 'Last Activity'],
      rows: cadets
          .map((row) => [
                row.cadetId,
                row.name,
                '${row.totalGiven}',
                '${row.totalCollected}',
                '${row.totalGiven - row.totalCollected}',
                row.lastActivityMillis == 0 ? '' : _human(row.lastActivityMillis),
              ])
          .toList(),
    );
    final inventoryCsv = _buildCsv(
      headers: const ['Batch', 'Box', 'Item', 'Stock'],
      rows: inventory.map((row) => [row.batchName, row.boxName, row.itemName, '${row.quantity}']).toList(),
    );
    final historyCsv = _buildCsv(
      headers: const ['Date', 'Cadet ID', 'Cadet Name', 'Item', 'Action', 'Status', 'Qty', 'Batch', 'Box'],
      rows: history
          .map((row) => [
                _human(row.createdAtMillis),
                row.cadetId,
                row.cadetName,
                row.itemName,
                row.action,
                row.status ?? '',
                '${row.quantity}',
                row.batchName,
                row.boxName,
              ])
          .toList(),
    );
    final cadetName = 'all_cadets_$stamp.csv';
    final inventoryName = 'all_inventory_$stamp.csv';
    final historyName = 'all_history_$stamp.csv';

    if (kIsWeb) {
      await downloadFileOnWeb(cadetName, utf8.encode(cadetCsv), 'text/csv');
      await downloadFileOnWeb(inventoryName, utf8.encode(inventoryCsv), 'text/csv');
      await downloadFileOnWeb(historyName, utf8.encode(historyCsv), 'text/csv');
      _toast('3 files downloaded.');
      return;
    }

    // Write all 3 files to internal dir first (always writable)
    final appDir = await _downloadsDir();
    final cadetBytes = Uint8List.fromList(utf8.encode(cadetCsv));
    final inventoryBytes = Uint8List.fromList(utf8.encode(inventoryCsv));
    final historyBytes = Uint8List.fromList(utf8.encode(historyCsv));

    await File(p.join(appDir!.path, cadetName)).writeAsBytes(cadetBytes, flush: true);
    await File(p.join(appDir.path, inventoryName)).writeAsBytes(inventoryBytes, flush: true);
    await File(p.join(appDir.path, historyName)).writeAsBytes(historyBytes, flush: true);
    await _refreshDownloads();

    if (!mounted) return;

    // Show custom bottom sheet: Save to Downloads OR Share via other apps
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Export 3 files (Cadets, Inventory, History)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const Divider(),

              // ── Option 1: Save to Downloads ──────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.green),
                ),
                title: const Text('Save to Downloads'),
                subtitle: const Text('Each file saved one by one'),
                onTap: () async {
                  Navigator.pop(ctx);
                  for (final entry in [
                    (cadetName, cadetBytes),
                    (inventoryName, inventoryBytes),
                    (historyName, historyBytes),
                  ]) {
                    await _saveToDownloads(
                      bytes: entry.$2,
                      filename: entry.$1,
                      mimeType: 'text/csv',
                    );
                  }
                  if (!mounted) return;
                  _toast('All 3 files saved to Downloads.');
                },
              ),

              // ── Option 2: Share via other apps ────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.blue),
                ),
                title: const Text('Share via other apps'),
                subtitle: const Text('WhatsApp, Gmail, Drive and more'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Share.shareXFiles(
                    [
                      XFile(p.join(appDir.path, cadetName), mimeType: 'text/csv'),
                      XFile(p.join(appDir.path, inventoryName), mimeType: 'text/csv'),
                      XFile(p.join(appDir.path, historyName), mimeType: 'text/csv'),
                    ],
                    subject: 'All Records Export',
                    text: 'Cadets, Inventory and History CSV files',
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportDataPackage() async {
    final bundle = await ReportsDataService.instance.buildPortableDataPackage();
    final jsonString = ReportsDataService.instance.packageToJson(bundle);
    await _shareBytes(
      bytes: Uint8List.fromList(utf8.encode(jsonString)),
      filename: 'military_data_package_${_stamp(DateTime.now())}.json',
      mimeType: 'application/json',
      text: 'Portable data package',
    );
  }

  Future<void> _importDataPackage() async {
    // ── Step 1: Pick the .json file ────────────────────────────────────────
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast('Unable to read file.');
      return;
    }

    // ── Step 2: Decode & validate ──────────────────────────────────────────
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map<String, dynamic>) throw const FormatException('Not a JSON object');
      decoded = raw;
    } catch (_) {
      _toast('Invalid package format — not a valid military app export.');
      return;
    }

    // Validate it is actually our package (must have schema key)
    final schema = decoded['schema'] as String?;
    if (schema != 'military_app_package_v1') {
      _toast('Wrong file — this is not a military app export file.');
      return;
    }

    // ── Step 3: Show merge preview dialog ─────────────────────────────────
    final exportedAt = decoded['exported_at'];
    final exportedDate = exportedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(exportedAt)
        : null;
    final exportedLabel = exportedDate != null
        ? '${exportedDate.day.toString().padLeft(2,'0')}/'
          '${exportedDate.month.toString().padLeft(2,'0')}/'
          '${exportedDate.year}  '
          '${exportedDate.hour.toString().padLeft(2,'0')}:'
          '${exportedDate.minute.toString().padLeft(2,'0')}'
        : 'Unknown time';

    final incomingTransfers = (decoded['transfers'] as List?)?.length ?? 0;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge Device Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.devices, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text('Exported: $exportedLabel',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Contains $incomingTransfers transfer records',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // What will happen
            const Text('What will happen:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _mergeInfoRow(Icons.add_circle_outline, Colors.green,
                'New transfers from this file will be added'),
            _mergeInfoRow(Icons.inventory_2_outlined, Colors.orange,
                'Item stock will be adjusted for each new transfer'),
            _mergeInfoRow(Icons.copy_outlined, Colors.grey,
                'Duplicate records will be skipped automatically'),
            _mergeInfoRow(Icons.shield_outlined, Colors.blue,
                'Your existing data will NOT be deleted'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.merge_type, size: 18),
            label: const Text('Merge'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ── Step 4: Run merge ──────────────────────────────────────────────────
    if (!mounted) return;
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Merging data...'),
          ],
        ),
      ),
    );

    MergeResult summary;
    try {
      summary = await ReportsDataService.instance.mergeTransfersFromPackage(decoded);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      _toast('Merge failed: $e');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    // ── Step 5: Show result ────────────────────────────────────────────────
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            _mergeInfoRow(Icons.add_circle, Colors.green,
                '${summary.inserted} new transfers added'),
            _mergeInfoRow(Icons.copy, Colors.grey,
                '${summary.skipped} duplicates skipped'),
            if (summary.failed > 0)
              _mergeInfoRow(Icons.warning_amber, Colors.red,
                  '${summary.failed} records could not be matched'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    await _loadInitial();
  }

  /// Small helper row used inside merge dialogs.
  static Widget _mergeInfoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }


  /// Saves bytes to the device Downloads folder.
  ///
  /// Platform behaviour:
  ///   Web     → triggers browser download via dart:html
  ///   Android → writes to app external files dir (accessible in Files app,
  ///             no permission needed on Android 10+), then opens share sheet
  ///             so user can move/forward the file
  ///   iOS     → writes to internal docs dir, then shares via share sheet
  ///   Desktop → uses FilePicker.saveFile() with bytes (works on desktop/web)
  Future<void> _saveToDownloads({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      await downloadFileOnWeb(filename, bytes, mimeType);
      _toast('Download started: $filename');
      return;
    }

    if (Platform.isAndroid) {
      // Write to app-scoped external storage — always writable without
      // any permission on Android 10+.
      // Path: /storage/emulated/0/Android/data/<pkg>/files/<filename>
      // Accessible via the device Files app under "Android/data".
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        // Fallback: internal storage + share
        await _shareViaSheet(bytes: bytes, filename: filename, mimeType: mimeType);
        return;
      }
      final savePath = p.join(extDir.path, filename);
      await File(savePath).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      // Also offer share so user can move to WhatsApp, Drive, etc.
      await Share.shareXFiles(
        [XFile(savePath, mimeType: mimeType)],
        subject: filename,
        text: 'Saved to device. Share or move as needed.',
      );
      return;
    }

    if (Platform.isIOS) {
      // iOS: write to docs dir, share sheet lets user save to Files app
      await _shareViaSheet(bytes: bytes, filename: filename, mimeType: mimeType);
      return;
    }

    // Desktop (Windows / macOS / Linux): saveFile with bytes works perfectly
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
      bytes: bytes,
    );
    if (!mounted) return;
    _toast(savedPath != null ? 'Saved to $savedPath' : 'Save cancelled.');
  }

  /// Writes bytes to internal app dir then opens the system share sheet.
  Future<void> _shareViaSheet({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final appDir = await _downloadsDir();
    final appPath = p.join(appDir!.path, filename);
    await File(appPath).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(appPath, mimeType: mimeType)],
      subject: filename,
    );
  }

  /// Shows a bottom sheet with "Save to Downloads" first, then "Share via apps".
  Future<void> _shareBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String text,
  }) async {
    if (kIsWeb) {
      await downloadFileOnWeb(filename, bytes, mimeType);
      _toast('Download started: $filename');
      return;
    }

    // Save a copy to internal dir so Downloads tab always works
    final appDir = await _downloadsDir();
    final appPath = p.join(appDir!.path, filename);
    await File(appPath).writeAsBytes(bytes, flush: true);
    await _refreshDownloads();

    if (!mounted) return;

    // Show custom bottom sheet: Save to Downloads OR Share via other apps
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  filename,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),

              // ── Option 1: Save to Downloads ──────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.green),
                ),
                title: const Text('Save to Downloads'),
                subtitle: const Text('Pick a folder on your device'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _saveToDownloads(
                    bytes: bytes,
                    filename: filename,
                    mimeType: mimeType,
                  );
                },
              ),

              // ── Option 2: Share via other apps ────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.blue),
                ),
                title: const Text('Share via other apps'),
                subtitle: const Text('WhatsApp, Gmail, Drive and more'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Opens Android/iOS system share sheet
                  await Share.shareXFiles(
                    [XFile(appPath, mimeType: mimeType)],
                    subject: filename,
                    text: text,
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          _pdfTable(title: title, headers: headers, rows: rows),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.all(4),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
        ),
      ],
    );
  }

  String _buildCsv({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export portable package',
            onPressed: _exportDataPackage,
            icon: const Icon(Icons.drive_folder_upload_outlined),
          ),
          IconButton(
            tooltip: 'Import package',
            onPressed: _importDataPackage,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.groups_2_outlined), text: "Cadet's List"),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory List'),
            Tab(icon: Icon(Icons.history_outlined), text: 'History'),
            Tab(icon: Icon(Icons.download_done_outlined), text: 'Downloads'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index != 3)
            _TopDateFilters(
              fromDate: _fromDate,
              toDate: _toDate,
              onPickFrom: _pickFromDate,
              onPickTo: _pickToDate,
              onClearFrom: () async {
                setState(() => _fromDate = null);
                await _loadCurrentTab();
              },
            ),
          if (_tabController.index != 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showExportChooser(currentTabOnly: true),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save This Tab'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showExportChooser(currentTabOnly: false),
                      icon: const Icon(Icons.dataset_outlined),
                      label: const Text('Save All Records'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCadetTab(),
                      _buildInventoryTab(),
                      _buildHistoryTab(),
                      _buildDownloadsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportChooser({required bool currentTabOnly}) async {
    final exportPdf = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Excel (CSV)'),
                subtitle: const Text('Spreadsheet export'),
                onTap: () => Navigator.of(context).pop(false),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                subtitle: const Text('Print-ready report'),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (exportPdf == null) return;

    if (currentTabOnly) {
      await _shareTabExport(asPdf: exportPdf);
      return;
    }
    await _shareAllRecords(asPdf: exportPdf);
  }

  Widget _buildCadetTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _cadetSearchController,
            decoration: const InputDecoration(
              hintText: 'Search cadet by name or ID',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => _loadCurrentTab(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              child: _cadetRows.isEmpty
                  ? const Center(child: Text('No cadet records found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: _cadetRows.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final row = _cadetRows[index];
                        final holding = row.totalGiven - row.totalCollected;
                        return ListTile(
                          title: Text('${row.name} (${row.cadetId})'),
                          subtitle: Text(
                            'Given: ${row.totalGiven} | Collected: ${row.totalCollected} | Holding: $holding',
                          ),
                          trailing: Text(
                            row.lastActivityMillis == 0 ? '-' : _human(row.lastActivityMillis),
                            textAlign: TextAlign.end,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _inventorySearchController,
            decoration: const InputDecoration(
              hintText: 'Search item',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => _loadCurrentTab(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _inventoryBatchId,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: _batches
                      .map((batch) => DropdownMenuItem(value: batch.id, child: Text(batch.name)))
                      .toList(),
                  onChanged: _changeBatch,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _inventoryBoxId,
                  decoration: const InputDecoration(labelText: 'Box'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
                    ..._boxes.map((box) => DropdownMenuItem<int?>(value: box.id, child: Text(box.name))),
                  ],
                  onChanged: (value) async {
                    setState(() => _inventoryBoxId = value);
                    await _loadCurrentTab();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  value: _inventoryLowStockOnly,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Low stock only'),
                  onChanged: (value) async {
                    setState(() => _inventoryLowStockOnly = value);
                    await _loadCurrentTab();
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: TextFormField(
                  initialValue: '10',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Threshold'),
                  onFieldSubmitted: (value) async {
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0) return;
                    setState(() => _inventoryLowStockThreshold = parsed);
                    await _loadCurrentTab();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: _inventoryRows.isEmpty
                  ? const Center(child: Text('No inventory records found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: _inventoryRows.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final row = _inventoryRows[index];
                        final isLow = row.quantity <= _inventoryLowStockThreshold;
                        return ListTile(
                          title: Text(row.itemName),
                          subtitle: Text('${row.batchName} / ${row.boxName}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isLow ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${row.quantity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isLow ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _historySearchController,
            decoration: const InputDecoration(
              hintText: 'Search cadet ID, cadet name or item',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => _loadCurrentTab(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _historyAction,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'give', child: Text('Given')),
                    DropdownMenuItem(value: 'collect', child: Text('Collected')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _historyAction = value);
                    await _loadCurrentTab();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _historyStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'good', child: Text('Good')),
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem(value: 'missing', child: Text('Missing')),
                    DropdownMenuItem(value: 'none', child: Text('None')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _historyStatus = value);
                    await _loadCurrentTab();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: _historyRows.isEmpty
                  ? const Center(child: Text('No history records found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: _historyRows.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final row = _historyRows[index];
                        return ListTile(
                          title: Text('${row.cadetName} (${row.cadetId})'),
                          subtitle: Text(
                            '${row.itemName} | ${row.batchName}/${row.boxName}\n'
                            'Action: ${row.action} | Status: ${row.status ?? '-'} | Qty: ${row.quantity}',
                          ),
                          trailing: Text(
                            _human(row.createdAtMillis),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved Report Files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _refreshDownloads,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: _downloadFiles.isEmpty
                  ? const Center(child: Text('No downloaded files yet. Save a report to see files here.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: _downloadFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final file = _downloadFiles[index];
                        final stat = file.statSync();
                        final ext = p.extension(file.path).toLowerCase();
                        return ListTile(
                          title: Text(p.basename(file.path)),
                          subtitle: Text(
                            '${_formatBytes(stat.size)} • ${_human(stat.modified.millisecondsSinceEpoch)}',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                tooltip: 'View',
                                onPressed: () => _viewDownload(file),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              IconButton(
                                tooltip: 'Print',
                                onPressed: ext == '.pdf' ? () => _printDownload(file) : null,
                                icon: const Icon(Icons.print_outlined),
                              ),
                              IconButton(
                                tooltip: 'Share',
                                onPressed: () => _shareDownload(file),
                                icon: const Icon(Icons.share_outlined),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDownload(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.pdf') {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PdfPreviewScreen(
            title: p.basename(file.path),
            bytes: bytes,
          ),
        ),
      );
      return;
    }

    final content = await file.readAsString();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.basename(file.path)),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _printDownload(File file) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareDownload(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Report file');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({
    required this.title,
    required this.bytes,
  });

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}

class _TopDateFilters extends StatelessWidget {
  const _TopDateFilters({
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
  });

  final DateTime? fromDate;
  final DateTime toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFrom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onPickFrom,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(fromDate == null ? 'From Date' : _dateOnly(fromDate!)),
                    ),
                    if (fromDate != null)
                      IconButton(
                        tooltip: 'Clear from date',
                        onPressed: onClearFrom,
                        icon: const Icon(Icons.clear),
                      ),
                    OutlinedButton.icon(
                      onPressed: onPickTo,
                      icon: const Icon(Icons.event_outlined),
                      label: Text('To: ${_dateOnly(toDate)}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

String _dateOnly(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _human(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$d/$m/${dt.year} $h:$minute $ampm';
}

String _stamp(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$y$m${d}_$hh$mm$ss';
}
