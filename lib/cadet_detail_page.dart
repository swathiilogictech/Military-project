import 'dart:convert';

import 'package:flutter/material.dart';

import 'cadet_edit_page.dart';
import 'database_service.dart';

class CadetDetailPage extends StatefulWidget {
  const CadetDetailPage({
    super.key,
    required this.cadet,
  });

  final CadetRecord cadet;

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String>(
                      value: _actionFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'give', child: Text('Given')),
                        DropdownMenuItem(value: 'collect', child: Text('Collected')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _actionFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _TransferPanel(title: 'Cadet History', rows: _filteredRows),
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
  });

  final String title;
  final List<TransferRecord> rows;

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
            child: Text(
              '$title (${rows.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No records.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isCollect = row.action == 'collect';
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isCollect ? const Color(0xFF0EA5E9) : const Color(0xFF0F766E),
                              child: Icon(
                                isCollect ? Icons.call_received : Icons.call_made,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row.itemName}  x${row.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text('${row.batchName} - ${row.boxName}'),
                                  if (row.status != null)
                                    Text(
                                      'Status: ${row.status}',
                                      style: const TextStyle(color: Color(0xFFB45309)),
                                    ),
                                  Text(
                                    _formatDateTime(DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis)),
                                    style: const TextStyle(color: Color(0xFF334155)),
                                  ),
                                ],
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
