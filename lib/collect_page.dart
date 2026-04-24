import 'package:flutter/material.dart';

import 'database_service.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  CadetRecord? _selectedCadet;
  List<CadetRecord> _cadets = const [];
  List<CadetHistorySummary> _recentGivenCadets = const [];
  bool _cadetsLoading = true;
  bool _recentCadetsLoading = true;
  bool _latestFirst = true;

  List<CadetHoldingRecord> _holdings = const [];
  bool _loading = false;

  final TextEditingController _holdingSearchController = TextEditingController();
  final Map<int, _ReturnSplit> _splits = <int, _ReturnSplit>{};

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _loadCadets();
    _loadRecentGivenCadets();
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    _holdingSearchController.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    _loadCadets();
    _loadRecentGivenCadets();
    if (_selectedCadet != null) {
      _loadForCadet();
    }
  }

  Future<void> _loadCadets() async {
    setState(() => _cadetsLoading = true);
    final rows = await DatabaseService.instance.getCadets();
    if (!mounted) return;
    setState(() {
      _cadets = rows;
      _cadetsLoading = false;
      if (_selectedCadet != null) {
        _selectedCadet = rows.where((c) => c.id == _selectedCadet!.id).firstOrNull;
      }
    });
  }

  Future<void> _loadRecentGivenCadets() async {
    setState(() => _recentCadetsLoading = true);
    final rows = await DatabaseService.instance.getCadetHistorySummaries(
      action: 'give',
      limit: 500,
    );
    if (!mounted) return;
    final filtered = rows.where((r) => r.totalGiven > 0).toList();
    filtered.sort((a, b) => b.lastActivityMillis.compareTo(a.lastActivityMillis));
    setState(() {
      _recentGivenCadets = filtered;
      _recentCadetsLoading = false;
    });
  }

  Future<void> _loadForCadet() async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      setState(() {
        _holdings = const [];
        _splits.clear();
      });
      return;
    }

    setState(() => _loading = true);
    final holdings = await DatabaseService.instance.getCadetHoldings(cadet.id);
    if (!mounted) return;
    setState(() {
      _holdings = holdings;
      _loading = false;
      _splits.removeWhere((itemId, _) => holdings.every((h) => h.itemId != itemId));
      for (final h in holdings) {
        _splits.putIfAbsent(h.itemId, () => const _ReturnSplit());
      }
    });
  }

  Future<void> _openCadetPicker() async {
    final selected = await showDialog<CadetRecord>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        var latestFirst = _latestFirst;
        return AlertDialog(
          title: const Text('Select Cadet'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final q = controller.text.trim().toLowerCase();
              final recentRows = latestFirst
                  ? _recentGivenCadets
                  : _recentGivenCadets.reversed.toList(growable: false);
              final source = recentRows.isNotEmpty
                  ? recentRows.map((r) => r.toCadetRecord()).toList()
                  : _cadets;
              final filtered = q.isEmpty
                  ? source
                  : source
                      .where((c) => c.name.toLowerCase().contains(q) || c.cadetId.toLowerCase().contains(q))
                      .toList();
              return SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search cadets',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: latestFirst ? 'Latest first' : 'Oldest first',
                          onPressed: () {
                            setDialogState(() {
                              latestFirst = !latestFirst;
                              _latestFirst = latestFirst;
                            });
                          },
                          icon: Icon(latestFirst ? Icons.south : Icons.north),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cadet = filtered[index];
                          final summary = _recentGivenCadets
                              .where((r) => r.cadetDbId == cadet.id)
                              .firstOrNull;
                          return ListTile(
                            title: Text(cadet.name),
                            subtitle: Text(
                              summary == null
                                  ? 'ID: ${cadet.cadetId}'
                                  : 'ID: ${cadet.cadetId} - Last: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(summary.lastActivityMillis))}',
                            ),
                            trailing: _selectedCadet?.id == cadet.id
                                ? const Icon(Icons.check_circle, color: Color(0xFF0F766E))
                                : null,
                            onTap: () => Navigator.of(context).pop(cadet),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCadet = null;
                  _holdings = const [];
                  _splits.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Unselect'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedCadet = selected);
      await _loadForCadet();
    }
  }

  void _adjustSplit(CadetHoldingRecord row, String status, int delta) {
    final current = _splits[row.itemId] ?? const _ReturnSplit();
    var next = current;
    switch (status) {
      case 'good':
        next = current.copyWith(good: (current.good + delta).clamp(0, row.quantityHeld));
        break;
      case 'damaged':
        next = current.copyWith(damaged: (current.damaged + delta).clamp(0, row.quantityHeld));
        break;
      case 'missing':
        next = current.copyWith(missing: (current.missing + delta).clamp(0, row.quantityHeld));
        break;
    }

    if (next.total > row.quantityHeld) return;
    setState(() => _splits[row.itemId] = next);
  }

  Future<void> _collectSelected() async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cadet first.')));
      return;
    }

    final inputs = <CollectInput>[];
    for (final h in _holdings) {
      final s = _splits[h.itemId] ?? const _ReturnSplit();
      if (s.good > 0) {
        inputs.add(CollectInput(itemId: h.itemId, quantity: s.good, status: 'good'));
      }
      if (s.damaged > 0) {
        inputs.add(CollectInput(itemId: h.itemId, quantity: s.damaged, status: 'damaged'));
      }
      if (s.missing > 0) {
        inputs.add(CollectInput(itemId: h.itemId, quantity: s.missing, status: 'missing'));
      }
    }

    if (inputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one return quantity.')),
      );
      return;
    }

    try {
      await DatabaseService.instance.collectItems(cadetDbId: cadet.id, items: inputs);
      if (!mounted) return;
      setState(() {
        _selectedCadet = null;
        _holdings = const [];
        _splits.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collection saved at ${_formatDateTime(DateTime.now())}')),
      );
      await _loadRecentGivenCadets();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to complete collection.')),
      );
    }
  }

  List<CadetHoldingRecord> get _filteredHoldings {
    final q = _holdingSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _holdings;
    return _holdings.where((h) => h.itemName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width < 600 ? 10 : 14, vertical: 10),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTakenPane(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakenPane() {
    final cadet = _selectedCadet;
    final totalHeld = _holdings.fold<int>(0, (sum, h) => sum + h.quantityHeld);
    final totalSelected = _splits.values.fold<int>(0, (sum, s) => sum + s.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cadet == null ? 'No cadet selected' : cadet.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          cadet == null ? 'Choose a cadet to collect items' : 'ID: ${cadet.cadetId}',
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _cadetsLoading || _recentCadetsLoading ? null : _openCadetPicker,
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(cadet == null ? 'Select' : 'Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Cadet Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'Held: $totalHeld',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: cadet != null,
              controller: _holdingSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search cadet items',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: cadet == null
                  ? const Center(
                      child: Text(
                        'Select a cadet to view and collect items.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : _filteredHoldings.isEmpty
                      ? const Center(child: Text('No items currently with this cadet.'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: _filteredHoldings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final h = _filteredHoldings[i];
                              final s = _splits[h.itemId] ?? const _ReturnSplit();
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            h.itemName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Held: ${h.quantityHeld}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Given: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(h.latestTakenAtMillis))}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _StatusStepper(
                                          label: 'Good',
                                          color: const Color(0xFF16A34A),
                                          value: s.good,
                                          onMinus: () => _adjustSplit(h, 'good', -1),
                                          onPlus: () => _adjustSplit(h, 'good', 1),
                                        ),
                                        _StatusStepper(
                                          label: 'Damaged',
                                          color: const Color(0xFFD97706),
                                          value: s.damaged,
                                          onMinus: () => _adjustSplit(h, 'damaged', -1),
                                          onPlus: () => _adjustSplit(h, 'damaged', 1),
                                        ),
                                        _StatusStepper(
                                          label: 'Missing',
                                          color: const Color(0xFFDC2626),
                                          value: s.missing,
                                          onMinus: () => _adjustSplit(h, 'missing', -1),
                                          onPlus: () => _adjustSplit(h, 'missing', 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Total selected: $totalSelected',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: cadet == null ? null : _collectSelected,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Collect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnSplit {
  const _ReturnSplit({this.good = 0, this.damaged = 0, this.missing = 0});

  final int good;
  final int damaged;
  final int missing;

  int get total => good + damaged + missing;

  _ReturnSplit copyWith({int? good, int? damaged, int? missing}) {
    return _ReturnSplit(
      good: good ?? this.good,
      damaged: damaged ?? this.damaged,
      missing: missing ?? this.missing,
    );
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({
    required this.label,
    required this.color,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final Color color;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour12:$mm $ampm';
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

