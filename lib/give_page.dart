import 'package:flutter/material.dart';

import 'database_service.dart';

class GivePage extends StatefulWidget {
  const GivePage({super.key});

  @override
  State<GivePage> createState() => _GivePageState();
}

class _GivePageState extends State<GivePage> {
  CadetRecord? _selectedCadet;
  List<CadetRecord> _cadets = const [];
  bool _cadetsLoading = true;

  List<BatchRecord> _batches = const [];
  List<BoxRecord> _boxes = const [];
  List<ItemRecord> _items = const [];
  BatchRecord? _selectedBatch;
  BoxRecord? _selectedBox;
  bool _inventoryLoading = true;

  final TextEditingController _itemSearchController = TextEditingController();
  final Map<int, _GiveCartEntry> _cart = <int, _GiveCartEntry>{};

  @override
  void initState() {
    super.initState();
    _loadCadets();
    _loadInventory();
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
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

  Future<void> _loadInventory({
    int? preferredBatchId,
    int? preferredBoxId,
    String? searchQuery,
  }) async {
    setState(() => _inventoryLoading = true);

    final batches = await DatabaseService.instance.getBatches();
    if (batches.isEmpty) {
      if (!mounted) return;
      setState(() {
        _batches = const [];
        _boxes = const [];
        _items = const [];
        _selectedBatch = null;
        _selectedBox = null;
        _inventoryLoading = false;
      });
      return;
    }

    final selectedBatch = batches.firstWhere(
      (batch) => batch.id == preferredBatchId,
      orElse: () => _selectedBatch != null
          ? batches.firstWhere((b) => b.id == _selectedBatch!.id, orElse: () => batches.first)
          : batches.first,
    );

    final boxes = await DatabaseService.instance.getBoxesForBatch(selectedBatch.id);
    final selectedBox = boxes.firstWhere(
      (box) => box.id == preferredBoxId,
      orElse: () => _selectedBox != null
          ? boxes.firstWhere((b) => b.id == _selectedBox!.id, orElse: () => boxes.first)
          : boxes.first,
    );

    final items = await DatabaseService.instance.getItemsForBox(
      selectedBox.id,
      searchQuery: searchQuery ?? _itemSearchController.text,
    );

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _boxes = boxes;
      _items = items;
      _selectedBatch = selectedBatch;
      _selectedBox = selectedBox;
      _inventoryLoading = false;
    });
  }

  Future<void> _openCadetPicker() async {
    final selected = await showModalBottomSheet<CadetRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = controller.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? _cadets
                : _cadets
                    .where((c) => c.name.toLowerCase().contains(q) || c.cadetId.toLowerCase().contains(q))
                    .toList();
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: TextField(
                      controller: controller,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search cadets',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
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
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedCadet = selected);
    }
  }

  void _addToCart(ItemRecord item) {
    final current = _cart[item.id]?.quantity ?? 0;
    if (current >= item.quantity) return;
    setState(() {
      _cart[item.id] = _GiveCartEntry(item: item, quantity: current + 1);
    });
  }

  void _removeFromCart(ItemRecord item) {
    final current = _cart[item.id];
    if (current == null) return;
    if (current.quantity <= 1) {
      setState(() => _cart.remove(item.id));
      return;
    }
    setState(() {
      _cart[item.id] = _GiveCartEntry(item: item, quantity: current.quantity - 1);
    });
  }

  Future<void> _submitGive() async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cadet first.')));
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items first.')));
      return;
    }

    try {
      await DatabaseService.instance.giveItems(
        cadetDbId: cadet.id,
        items: _cart.values.map((e) => TransferInput(itemId: e.item.id, quantity: e.quantity)).toList(),
      );
      if (!mounted) return;
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Given to ${cadet.name} at ${_formatDateTime(DateTime.now())}')),
      );
      await _loadInventory(preferredBatchId: _selectedBatch?.id, preferredBoxId: _selectedBox?.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to complete issue. Check stock.')),
      );
    }
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
            Row(
              children: [
                const _ModeChip(label: 'Give', selected: true),
                const SizedBox(width: 8),
                const _ModeChip(label: 'Collect', selected: false),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _cadetsLoading ? null : _openCadetPicker,
                  child: const Text('Select Cadet'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(flex: 7, child: _buildInventoryPanel()),
                        const SizedBox(width: 10),
                        Expanded(flex: 5, child: _buildPreviewPanel()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 6, child: _buildInventoryPanel()),
                        const SizedBox(height: 10),
                        Expanded(flex: 5, child: _buildPreviewPanel()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryPanel() {
    if (_inventoryLoading) {
      return const Card(child: Center(child: CircularProgressIndicator()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemSearchController,
                    onChanged: (value) => _loadInventory(
                      preferredBatchId: _selectedBatch?.id,
                      preferredBoxId: _selectedBox?.id,
                      searchQuery: value,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search items',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_selectedBatch?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _batches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final b = _batches[i];
                  return FilterChip(
                    selected: b.id == _selectedBatch?.id,
                    label: Text(b.name),
                    onSelected: (_) => _loadInventory(preferredBatchId: b.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _boxes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final b = _boxes[i];
                  return FilterChip(
                    selected: b.id == _selectedBox?.id,
                    label: Text(b.name),
                    onSelected: (_) => _loadInventory(
                      preferredBatchId: _selectedBatch?.id,
                      preferredBoxId: b.id,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(Icons.inventory_2_outlined),
                    ),
                    title: Text(item.name),
                    subtitle: Text('Available: ${item.quantity}'),
                    trailing: FilledButton.tonal(
                      onPressed: item.quantity == 0 ? null : () => _addToCart(item),
                      child: const Text('Add'),
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

  Widget _buildPreviewPanel() {
    final cadet = _selectedCadet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cadet == null ? 'No cadet selected' : '${cadet.name} (${cadet.cadetId})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(child: Text('No items selected'))
                  : ListView.separated(
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final entry = _cart.values.elementAt(i);
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            title: Text(entry.item.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _removeFromCart(entry.item),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('${entry.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                IconButton(
                                  onPressed: () => _addToCart(entry.item),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Total: ${_cart.values.fold<int>(0, (s, e) => s + e.quantity)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton(onPressed: _submitGive, child: const Text('Give')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiveCartEntry {
  const _GiveCartEntry({required this.item, required this.quantity});

  final ItemRecord item;
  final int quantity;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF4E9D72) : const Color(0xFFE7F6F1),
        borderRadius: BorderRadius.circular(14),
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
