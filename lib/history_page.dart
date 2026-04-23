import 'package:flutter/material.dart';

import 'cadet_detail_page.dart';
import 'database_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    this.initialAction = 'all',
  });

  final String initialAction;

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<CadetHistorySummary> _rows = const [];

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _load();
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> setActionFilter(String action) async {
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final rows = await DatabaseService.instance.getCadetHistorySummaries(
      searchQuery: _searchController.text,
      action: 'all',
      limit: 300,
    );

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _openCadetDetail(CadetHistorySummary summary) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CadetDetailPage(cadet: summary.toCadetRecord()),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cadet History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _formatDateTime(DateTime.now()),
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _load(),
                  decoration: const InputDecoration(
                    hintText: 'Search cadets by name or ID',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _rows.isEmpty
                            ? const Center(child: Text('No cadet history found.'))
                            : Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE2E8F0),
                                      border: Border(
                                        bottom: BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            'Name/ID',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Give',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Collect',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Holdings',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Recent Date & Time',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      itemCount: _rows.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final row = _rows[index];
                                        final holdings = row.totalGiven - row.totalCollected;
                                        final gaveLast = row.lastAction == 'give';
                                        final collectedLast = row.lastAction == 'collect';
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => _openCadetDetail(row),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        row.cadetName,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      Text(
                                                        row.cadetCode,
                                                        style: const TextStyle(color: Color(0xFF475569)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${row.totalGiven}',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight: gaveLast ? FontWeight.w800 : FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${row.totalCollected}',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight: collectedLast ? FontWeight.w800 : FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '$holdings',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    row.lastActivityMillis == 0
                                                        ? '-'
                                                        : _formatDateTime(
                                                            DateTime.fromMillisecondsSinceEpoch(
                                                              row.lastActivityMillis,
                                                            ),
                                                          ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
