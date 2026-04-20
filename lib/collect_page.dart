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
  bool _cadetsLoading = true;

  List<CadetHoldingRecord> _holdings = const [];
  List<TransferRecord> _collectedRows = const [];
  bool _loading = false;

  final TextEditingController _holdingSearchController = TextEditingController();
  final Map<int, _ReturnSplit> _splits = <int, _ReturnSplit>{};

  @override
  void initState() {
    super.initState();
    _loadCadets();
  }

  @override
  void dispose() {
    _holdingSearchController.dispose();
    super.dispose();
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

  Future<void> _loadForCadet() async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      setState(() {
        _holdings = const [];
        _collectedRows = const [];
        _splits.clear();
      });
      return;
    }

    setState(() => _loading = true);
    final holdings = await DatabaseService.instance.getCadetHoldings(cadet.id);
    final collected = await DatabaseService.instance.getTransfers(
      cadetDbId: cadet.id,
      action: 'collect',
      limit: 300,
    );
    if (!mounted) return;
    setState(() {
      _holdings = holdings;
      _collectedRows = collected;
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
        return AlertDialog(
          title: const Text('Select Cadet'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final q = controller.text.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? _cadets
                  : _cadets
                      .where((c) => c.name.toLowerCase().contains(q) || c.cadetId.toLowerCase().contains(q))
                      .toList();
              return SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search cadets',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cadet = filtered[index];
                          return ListTile(
                            title: Text(cadet.name),
                            subtitle: Text('ID: ${cadet.cadetId}'),
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
                  _collectedRows = const [];
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
        _splits.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collection saved at ${_formatDateTime(DateTime.now())}')),
      );
      await _loadForCadet();
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
    final isWide = width >= 920;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width < 600 ? 10 : 14, vertical: 10),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : isWide
                      ? Row(
                          children: [
                            Expanded(flex: 6, child: _buildTakenPane()),
                            const SizedBox(width: 10),
                            Expanded(flex: 5, child: _buildAuditPane()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 6, child: _buildTakenPane()),
                            const SizedBox(height: 10),
                            Expanded(flex: 4, child: _buildAuditPane()),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakenPane() {
    final cadet = _selectedCadet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cadet == null ? 'No cadet selected' : '${cadet.name} (${cadet.cadetId})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _cadetsLoading ? null : _openCadetPicker,
                  child: const Text('Select'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _holdingSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search items',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredHoldings.isEmpty
                  ? const Center(child: Text('No items currently with cadet.'))
                  : ListView.separated(
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
                                      '${h.itemName}  |  Held: ${h.quantityHeld}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    _formatDateTime(DateTime.fromMillisecondsSinceEpoch(h.latestTakenAtMillis)),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _SplitControl(
                                label: 'Good',
                                value: s.good,
                                color: const Color(0xFF22C55E),
                                onMinus: () => _adjustSplit(h, 'good', -1),
                                onPlus: () => _adjustSplit(h, 'good', 1),
                              ),
                              const SizedBox(height: 6),
                              _SplitControl(
                                label: 'Damaged',
                                value: s.damaged,
                                color: const Color(0xFFF59E0B),
                                onMinus: () => _adjustSplit(h, 'damaged', -1),
                                onPlus: () => _adjustSplit(h, 'damaged', 1),
                              ),
                              const SizedBox(height: 6),
                              _SplitControl(
                                label: 'Missing',
                                value: s.missing,
                                color: const Color(0xFFEF4444),
                                onMinus: () => _adjustSplit(h, 'missing', -1),
                                onPlus: () => _adjustSplit(h, 'missing', 1),
                              ),
                              const SizedBox(height: 4),
                              Text('Selected for return: ${s.total}/${h.quantityHeld}'),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Total selected: ${_splits.values.fold<int>(0, (sum, s) => sum + s.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton(onPressed: _collectSelected, child: const Text('Collect')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditPane() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collected Audit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: _collectedRows.isEmpty
                  ? const Center(child: Text('No collected records.'))
                  : ListView.separated(
                      itemCount: _collectedRows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _collectedRows[i];
                        return ListTile(
                          dense: true,
                          title: Text('${r.itemName}  x${r.quantity}'),
                          subtitle: Text(_formatDateTime(DateTime.fromMillisecondsSinceEpoch(r.createdAtMillis))),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _statusColor(r.status),
                            ),
                            child: Text(
                              (r.status ?? '').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
                    ),
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

class _SplitControl extends StatelessWidget {
  const _SplitControl({
    required this.label,
    required this.value,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'good':
      return const Color(0xFF22C55E);
    case 'damaged':
      return const Color(0xFFF59E0B);
    case 'missing':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF64748B);
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
