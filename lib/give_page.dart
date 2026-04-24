import 'dart:async';
import 'dart:convert';

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
  Timer? _searchDebounce;
  bool _isGlobalSearch = false;
  final Map<int, _GiveCartEntry> _cart = <int, _GiveCartEntry>{};

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _loadCadets();
    _loadInventory();
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    _searchDebounce?.cancel();
    _itemSearchController.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    _loadCadets();
    _loadInventory(
      preferredBatchId: _selectedBatch?.id,
      preferredBoxId: _selectedBox?.id,
      searchQuery: _itemSearchController.text,
    );
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
    if (boxes.isEmpty) {
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _boxes = const [];
        _items = const [];
        _selectedBatch = selectedBatch;
        _selectedBox = null;
        _inventoryLoading = false;
        _isGlobalSearch = false;
      });
      return;
    }

    final selectedBox = boxes.firstWhere(
      (box) => box.id == preferredBoxId,
      orElse: () => _selectedBox != null
          ? boxes.firstWhere((b) => b.id == _selectedBox!.id, orElse: () => boxes.first)
          : boxes.first,
    );

    final items = await DatabaseService.instance.getItemsForBox(
      selectedBox.id,
      searchQuery: '',
    );

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _boxes = boxes;
      _items = items;
      _selectedBatch = selectedBatch;
      _selectedBox = selectedBox;
      _inventoryLoading = false;
      _isGlobalSearch = false;
    });

    final activeQuery = (searchQuery ?? _itemSearchController.text).trim();
    if (activeQuery.isNotEmpty) {
      await _searchAcrossInventory(activeQuery);
    }
  }

  Future<void> _searchAcrossInventory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isGlobalSearch = false;
      });
      return;
    }
    final rows = await DatabaseService.instance.searchItemsAcrossInventory(trimmed);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _isGlobalSearch = true;
    });
  }

  void _onItemSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () async {
      if (value.trim().isEmpty) {
        await _loadInventory(
          preferredBatchId: _selectedBatch?.id,
          preferredBoxId: _selectedBox?.id,
          searchQuery: '',
        );
      } else {
        await _searchAcrossInventory(value);
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

  void _deleteFromCart(ItemRecord item) {
    setState(() => _cart.remove(item.id));
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
      setState(() {
        _cart.clear();
        _selectedCadet = null; // ← clear cadet panel after successful Give
      });
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
                    onChanged: _onItemSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search items',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Batch',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedBatch?.id,
                    decoration: const InputDecoration(
                      isDense: true,
                    ),
                    items: _batches
                        .map(
                          (b) => DropdownMenuItem<int>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _loadInventory(preferredBatchId: value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EDF9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      itemCount: _boxes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = _boxes[i];
                        final selected = b.id == _selectedBox?.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _loadInventory(
                            preferredBatchId: _selectedBatch?.id,
                            preferredBoxId: b.id,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFE7EBFF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 18),
                                const SizedBox(height: 2),
                                Text(
                                  b.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 5, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = _items[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Color(0xFFE2E8F0),
                                            child: Icon(Icons.inventory_2_outlined, size: 18),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: FilledButton.tonal(
                                          onPressed: item.quantity == 0 ? null : () => _addToCart(item),
                                          child: const Text('Add'),
                                        ),
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
                  ),
                ],
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
            if (cadet != null)
              FutureBuilder<List<TransferRecord>>(
                future: DatabaseService.instance.getTransfers(
                  cadetDbId: cadet.id,
                  action: 'all',
                  limit: 500,
                ),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <TransferRecord>[];
                  final issued =
                      rows.where((r) => r.action == 'give').fold<int>(0, (s, r) => s + r.quantity);
                  final returned = rows
                      .where((r) => r.action == 'collect')
                      .fold<int>(0, (s, r) => s + r.quantity);
                  final holding = issued - returned;
                  final photoData = cadet.photoData;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: (photoData != null && photoData.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(base64Decode(photoData), fit: BoxFit.cover),
                                )
                              : const Icon(Icons.account_circle, size: 48, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cadet.name} (${cadet.cadetId})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text('Time: ${_formatDateTime(DateTime.now())}'),
                              const SizedBox(height: 2),
                              Text('Issued: $issued   Returned: $returned   Holding: $holding'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(child: Text('No items selected'))
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text('Item', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Edit',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final entry = _cart.values.elementAt(i);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(flex: 6, child: Text(entry.item.name)),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${entry.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _removeFromCart(entry.item),
                                            icon: const Icon(Icons.remove_circle_outline),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _addToCart(entry.item),
                                            icon: const Icon(Icons.add_circle_outline),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _deleteFromCart(entry.item),
                                            icon: const Icon(Icons.delete_outline),
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

  Widget _buildCadetSelectorBar() {
    return const SizedBox.shrink();
  }
}

class _GiveCartEntry {
  const _GiveCartEntry({required this.item, required this.quantity});

  final ItemRecord item;
  final int quantity;
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
