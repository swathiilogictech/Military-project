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
  }

  Future<void> _loadInventory({
    int? preferredBatchId,
    int? preferredBoxId,
    String? searchQuery,
  }) async {
    setState(() {
      _inventoryLoading = true;
    });

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
      orElse: () => batches.first,
    );

    final boxes = await DatabaseService.instance.getBoxesForBatch(selectedBatch.id);
    final selectedBox = boxes.firstWhere(
      (box) => box.id == preferredBoxId,
      orElse: () => boxes.first,
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
    }
  }

  Future<void> _giveItem(ItemRecord item) async {
    final cadet = _selectedCadet;
    if (cadet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a cadet first.')),
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    final shouldGive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Give ${item.name}'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Give'),
            ),
          ],
        );
      },
    );

    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    qtyController.dispose();

    if (shouldGive != true || qty <= 0) {
      return;
    }

    try {
      await DatabaseService.instance.giveItem(
        cadetDbId: cadet.id,
        itemId: item.id,
        quantity: qty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Given $qty × ${item.name} to ${cadet.name}')),
      );
      await _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: _selectedBox?.id,
        searchQuery: _itemSearchController.text,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stock for this item.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadet = _selectedCadet;
    final selectedBatch = _selectedBatch;
    final selectedBox = _selectedBox;

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
                const _ModeChip(label: 'Give', selected: true),
                const SizedBox(width: 10),
                const _ModeChip(label: 'Collect', selected: false),
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
                        ? const Text('Select a cadet to give items.')
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
            if (_inventoryLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _batches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    final isSelected = batch.id == selectedBatch?.id;
                    return GestureDetector(
                      onTap: () => _loadInventory(preferredBatchId: batch.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE7EBFF) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          batch.name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF2F6BFF) : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFFD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EDF9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: _boxes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final box = _boxes[index];
                            final isSelected = box.id == selectedBox?.id;
                            return GestureDetector(
                              onTap: () => _loadInventory(
                                preferredBatchId: selectedBatch?.id,
                                preferredBoxId: box.id,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: isSelected ? const Color(0xFF6B58F1) : Colors.black54,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    box.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1EAF7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: TextField(
                                        controller: _itemSearchController,
                                        onChanged: (value) => _loadInventory(
                                          preferredBatchId: selectedBatch?.id,
                                          preferredBoxId: selectedBox?.id,
                                          searchQuery: value,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Search items....',
                                          border: InputBorder.none,
                                          prefixIcon: Icon(Icons.search),
                                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FutureBuilder<int>(
                                    future: selectedBatch == null
                                        ? Future<int>.value(0)
                                        : DatabaseService.instance
                                            .getTotalQuantityForBatch(selectedBatch.id),
                                    builder: (context, snapshot) {
                                      final total = snapshot.data ?? 0;
                                      return Text(
                                        'Total items : $total',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: _items.isEmpty
                                    ? const Center(child: Text('No items.'))
                                    : ListView.separated(
                                        itemCount: _items.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final item = _items[index];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text(item.name)),
                                                const SizedBox(width: 10),
                                                Text('${item.quantity}'),
                                                const SizedBox(width: 10),
                                                ElevatedButton(
                                                  onPressed: cadet == null ? null : () => _giveItem(item),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFDDF3FF),
                                                    foregroundColor: Colors.black87,
                                                  ),
                                                  child: const Text('Give'),
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

