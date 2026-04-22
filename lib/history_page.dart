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
  String _action = 'all';

  bool _loading = true;
  List<CadetHistorySummary> _rows = const [];

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> setActionFilter(String action) async {
    if (!mounted) return;
    setState(() {
      _action = action;
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final rows = await DatabaseService.instance.getCadetHistorySummaries(
      searchQuery: _searchController.text,
      action: _action,
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
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _rows.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final row = _rows[index];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _openCadetDetail(row),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                     child: Row(
                                      children: [
                                        const SizedBox(width: 50), // avatar space match header

                                        Expanded(
                                          child: Text(
                                            row.cadetName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),

                                        Expanded(
                                          child: Text(
                                            '${row.totalGiven}',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),

                                        Expanded(
                                          child: Text(
                                            '${row.totalCollected}',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),

                                        Expanded(
                                          child: Text(
                                            row.lastActivityMillis == 0
                                                ? '-'
                                                : _formatDateTime(
                                                    DateTime.fromMillisecondsSinceEpoch(row.lastActivityMillis),
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
