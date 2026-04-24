import 'dart:convert';

import 'package:flutter/material.dart';

import 'cadet_edit_page.dart';
import 'database_service.dart';

class CadetDetailPage extends StatefulWidget {
  const CadetDetailPage({
    super.key,
    required this.cadet,
    this.showEditAction = true,
  });

  final CadetRecord cadet;
  final bool showEditAction;

  @override
  State<CadetDetailPage> createState() => _CadetDetailPageState();
}

class _CadetDetailPageState extends State<CadetDetailPage> {
  bool _loading = true;
  List<TransferRecord> _rows = const [];
  String _actionFilter = 'all';

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _load();
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final rows = await DatabaseService.instance.getTransfers(
      cadetDbId: widget.cadet.id,
      action: 'all',
      limit: 500,
    );

    if (!mounted) return;

    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cadet = widget.cadet;
    final photoData = cadet.photoData;

    final totalTaken =
        _rows.where((r) => r.action == 'give').fold<int>(0, (sum, r) => sum + r.quantity);
    final totalReturned =
        _rows.where((r) => r.action == 'collect').fold<int>(0, (sum, r) => sum + r.quantity);
    final holding = totalTaken - totalReturned;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 12 : 18,
                vertical: 12,
              ),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            height: 82,
                            width: 82,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: (photoData != null && photoData.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(base64Decode(photoData), fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.account_circle, size: 64, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cadet.name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Cadet ID: ${cadet.cadetId}',
                                  style: const TextStyle(color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Issued: $totalTaken | Returned: $totalReturned | Holding: $holding',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              if (widget.showEditAction) ...[
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    final updated = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => CadetEditPage(cadet: cadet),
                                      ),
                                    );
                                    if (context.mounted && updated == true) {
                                      Navigator.of(context).pop(true);
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                const SizedBox(height: 8),
                              ],
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _TransferPanel(
                            title: 'Cadet History',
                            rows: _filteredRows,
                            actionFilter: _actionFilter,
                            onActionFilterChanged: (value) {
                              setState(() {
                                _actionFilter = value;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TransferRecord> get _filteredRows {
    if (_actionFilter == 'all') return _rows;
    return _rows.where((r) => r.action == _actionFilter).toList();
  }
}

class _TransferPanel extends StatelessWidget {
  const _TransferPanel({
    required this.title,
    required this.rows,
    required this.actionFilter,
    required this.onActionFilterChanged,
  });

  final String title;
  final List<TransferRecord> rows;
  final String actionFilter;
  final ValueChanged<String> onActionFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFE2E8F0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$title (${rows.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButton<String>(
                  value: actionFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'give', child: Text('Given')),
                    DropdownMenuItem(value: 'collect', child: Text('Collected')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onActionFilterChanged(value);
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w700))),
                Expanded(
                  flex: 2,
                  child: Text('Batch/Box', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Date/Time', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No records.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final statusText = row.action == 'give' ? 'given' : (row.status ?? 'collected');
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(row.itemName)),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${row.batchName} / ${row.boxName}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${row.quantity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatDateTime(DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                statusText,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')} ${monthNames[dt.month - 1]} ${dt.year}, $hour12:$mm $ampm';
}
