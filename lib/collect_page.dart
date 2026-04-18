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
  bool _holdingsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCadets();
  }

  Future<void> _loadCadets() async {
    setState(() {
      _cadetsLoading = true;
    });
    final rows = await DatabaseService.instance.getCadets();
    if (!mounted) return;
    setState(() {
      _cadets = rows;
      _cadetsLoading = false;
      _selectedCadet ??= rows.isEmpty ? null : rows.first;
    });
    await _loadHoldings();
  }

  Future<void> _loadHoldings() async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      setState(() {
        _holdings = const [];
      });
      return;
    }
    setState(() {
      _holdingsLoading = true;
    });
    final rows = await DatabaseService.instance.getCadetHoldings(cadet.id);
    if (!mounted) return;
    setState(() {
      _holdings = rows;
      _holdingsLoading = false;
    });
  }

  Future<void> _selectCadet() async {
    final selected = await showModalBottomSheet<CadetRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = controller.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? _cadets
                : _cadets
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(query) ||
                          c.cadetId.toLowerCase().contains(query),
                    )
                    .toList();
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: TextField(
                      controller: controller,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search cadets',
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cadet = filtered[index];
                        return ListTile(
                          title: Text(cadet.name),
                          subtitle: Text(cadet.cadetId),
                          onTap: () => Navigator.of(context).pop(cadet),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCadet = selected;
      });
      await _loadHoldings();
    }
  }

  Future<void> _collectHolding(CadetHoldingRecord holding) async {
    final cadet = _selectedCadet;
    if (cadet == null) return;

    final qtyController = TextEditingController(text: '1');
    String status = 'good';
    final shouldCollect = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Collect ${holding.itemName}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Held: ${holding.quantityHeld}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Collect as'),
                    items: const [
                      DropdownMenuItem(value: 'good', child: Text('Good')),
                      DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                      DropdownMenuItem(value: 'missing', child: Text('Missing')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        status = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Collect'),
            ),
          ],
        );
      },
    );

    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    qtyController.dispose();

    if (shouldCollect != true || qty <= 0) {
      return;
    }

    try {
      await DatabaseService.instance.collectItem(
        cadetDbId: cadet.id,
        itemId: holding.itemId,
        quantity: qty,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collected $qty × ${holding.itemName} as $status')),
      );
      await _loadHoldings();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity to collect.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadet = _selectedCadet;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Package Tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Row(
              children: [
                const _ModeChip(label: 'Give', selected: false),
                const SizedBox(width: 10),
                const _ModeChip(label: 'Collect', selected: true),
                const Spacer(),
                ElevatedButton(
                  onPressed: _cadetsLoading ? null : _selectCadet,
                  child: const Text('Select'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EAF7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: cadet == null
                        ? const Text('Select a cadet to collect items.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name    : ${cadet.name}'),
                              Text('Cadet ID : ${cadet.cadetId}'),
                            ],
                          ),
                  ),
                  const Icon(Icons.account_circle, size: 48, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _holdingsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _holdings.isEmpty
                      ? const Center(child: Text('No items to collect.'))
                      : ListView.separated(
                          itemCount: _holdings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final holding = _holdings[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(holding.itemName),
                                        Text(
                                          '${holding.batchName} • ${holding.boxName}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('x ${holding.quantityHeld}'),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: cadet == null ? null : () => _collectHolding(holding),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDDF3FF),
                                      foregroundColor: Colors.black87,
                                    ),
                                    child: const Text('Collect'),
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
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF4E9D72) : const Color(0xFFE7F6F1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

