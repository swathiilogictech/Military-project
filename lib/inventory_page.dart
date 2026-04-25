import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'cadet_detail_page.dart';
import 'cadet_edit_page.dart';
import 'database_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    this.showCadets = false,
    this.canManageInventory = true,
    this.canCadetImportExport = true,
    this.canViewCollectedInventory = false,
  });

  final bool showCadets;
  final bool canManageInventory;
  final bool canCadetImportExport;
  final bool canViewCollectedInventory;

  @override
  State<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cadetSearchController = TextEditingController();

  List<BatchRecord> _batches = const [];
  List<BoxRecord> _boxes = const [];
  List<ItemRecord> _items = const [];
  List<CadetHistorySummary> _cadets = const [];
  List<TransferRecord> _collectedRows = const [];

  BatchRecord? _selectedBatch;
  BoxRecord? _selectedBox;
  bool _isLoading = true;
  bool _isCadetLoading = false;
  bool _isCollectedLoading = false;
  late bool _inventoryTabSelected;
  bool _collectedTabSelected = false;

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.dataVersion.addListener(_handleDataChanged);
    _inventoryTabSelected = !widget.showCadets;

    if (widget.showCadets) {
      _loadCadets();
    } else {
      _loadInventory();
    }
  }

  void showCadets() {
    if (!_inventoryTabSelected && !_collectedTabSelected) {
      _loadCadets();
      return;
    }
    setState(() {
      _inventoryTabSelected = false;
      _collectedTabSelected = false;
    });
    _loadCadets();
  }

  void showInventory() {
    if (_inventoryTabSelected) {
      _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: _selectedBox?.id,
      );
      return;
    }
    setState(() {
      _inventoryTabSelected = true;
      _collectedTabSelected = false;
    });
    _loadInventory(
      preferredBatchId: _selectedBatch?.id,
      preferredBoxId: _selectedBox?.id,
    );
  }

  @override
  void dispose() {
    DatabaseService.instance.dataVersion.removeListener(_handleDataChanged);
    _searchController.dispose();
    _cadetSearchController.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    if (_inventoryTabSelected) {
      _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: _selectedBox?.id,
        searchQuery: _searchController.text,
      );
      return;
    }
    if (_collectedTabSelected) {
      _loadCollectedRows();
      return;
    }
    _loadCadets(searchQuery: _cadetSearchController.text);
  }

  Future<void> _loadCollectedRows() async {
    setState(() => _isCollectedLoading = true);
    final rows = await DatabaseService.instance.getTransfers(action: 'collect', limit: 1500);
    if (!mounted) return;
    setState(() {
      _collectedRows = rows;
      _isCollectedLoading = false;
    });
  }

  Future<void> _loadInventory({
    int? preferredBatchId,
    int? preferredBoxId,
    String? searchQuery,
  }) async {
    setState(() => _isLoading = true);

    try {
      final batches = await DatabaseService.instance.getBatches();
      if (batches.isEmpty) {
        if (!mounted) return;
        setState(() {
          _batches = const [];
          _boxes = const [];
          _items = const [];
          _selectedBatch = null;
          _selectedBox = null;
          _isLoading = false;
        });
        return;
      }

      final selectedBatch = batches.firstWhere(
        (batch) => batch.id == preferredBatchId,
        orElse: () => batches.first,
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
          _isLoading = false;
        });
        return;
      }

      final selectedBox = boxes.firstWhere(
        (box) => box.id == preferredBoxId,
        orElse: () => boxes.first,
      );

      final items = await DatabaseService.instance.getItemsForBox(
        selectedBox.id,
        searchQuery: searchQuery ?? _searchController.text,
      );

      if (!mounted) return;
      setState(() {
        _batches = batches;
        _boxes = boxes;
        _items = items;
        _selectedBatch = selectedBatch;
        _selectedBox = selectedBox;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load inventory now.')),
      );
    }
  }

  Future<void> _changeBatch(BatchRecord batch) async {
    await _loadInventory(
      preferredBatchId: batch.id,
      searchQuery: _searchController.text,
    );
  }

  Future<void> _changeBox(BoxRecord box) async {
    await _loadInventory(
      preferredBatchId: _selectedBatch?.id,
      preferredBoxId: box.id,
      searchQuery: _searchController.text,
    );
  }

  Future<void> _onSearchChanged(String value) async {
    if (_selectedBatch == null || _selectedBox == null) {
      return;
    }

    await _loadInventory(
      preferredBatchId: _selectedBatch!.id,
      preferredBoxId: _selectedBox!.id,
      searchQuery: value,
    );
  }

  Future<void> _loadCadets({String? searchQuery}) async {
    setState(() {
      _isCadetLoading = true;
    });

    final rows = await DatabaseService.instance.getCadetHistorySummaries(
      searchQuery: searchQuery ?? _cadetSearchController.text,
      action: 'all',
      limit: 500,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _cadets = rows;
      _isCadetLoading = false;
    });
  }

  Future<void> _openAddCadet() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CadetEditPage(),
      ),
    );

    if (changed == true && mounted) {
      await _loadCadets();
    }
  }

  Future<void> _openCadetDetail(CadetRecord cadet) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CadetDetailPage(cadet: cadet),
      ),
    );

    if (changed == true && mounted) {
      await _loadCadets();
    }
  }

  Future<void> _showAddItemDialog() async {
    if (!widget.canManageInventory) {
      return;
    }
    final selectedBox = _selectedBox;
    if (selectedBox == null) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    Uint8List? photoBytes;
    String? photoBase64;
    final picker = ImagePicker();

    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Item to ${selectedBox.name}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Item name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!kIsWeb)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final file = await picker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 1200,
                                    imageQuality: 85,
                                  );
                                  if (file == null) {
                                    return;
                                  }
                                  final bytes = await file.readAsBytes();
                                  setDialogState(() {
                                    photoBytes = bytes;
                                    photoBase64 = base64Encode(bytes);
                                  });
                                },
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Take Picture'),
                              ),
                            ),
                          if (!kIsWeb) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1200,
                                  imageQuality: 85,
                                );
                                if (file == null) {
                                  return;
                                }
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  photoBytes = bytes;
                                  photoBase64 = base64Encode(bytes);
                                });
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choose File'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x22000000)),
                        ),
                        child: photoBytes == null
                            ? const Center(child: Text('No photo selected'))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  photoBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                if (photoBase64 == null || photoBase64!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a photo first.')),
                  );
                  return;
                }

                await DatabaseService.instance.addItem(
                  boxId: selectedBox.id,
                  name: nameController.text.trim(),
                  quantity: int.parse(quantityController.text),
                  imageKey: 'custom',
                  imageData: photoBase64,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();

    if (shouldReload == true && mounted) {
      await _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: _selectedBox?.id,
      );
    }
  }

  Future<void> _showEditItemDialog(ItemRecord item) async {
    if (!widget.canManageInventory) {
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity.toString());

    Uint8List? photoBytes;
    String? photoBase64 = item.imageData;
    final picker = ImagePicker();

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      photoBytes = base64Decode(photoBase64);
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Item name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock quantity'),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!kIsWeb)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final file = await picker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 1200,
                                    imageQuality: 85,
                                  );
                                  if (file == null) {
                                    return;
                                  }
                                  final bytes = await file.readAsBytes();
                                  setDialogState(() {
                                    photoBytes = bytes;
                                    photoBase64 = base64Encode(bytes);
                                  });
                                },
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Take Picture'),
                              ),
                            ),
                          if (!kIsWeb) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1200,
                                  imageQuality: 85,
                                );
                                if (file == null) {
                                  return;
                                }
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  photoBytes = bytes;
                                  photoBase64 = base64Encode(bytes);
                                });
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choose File'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x22000000)),
                        ),
                        child: photoBytes == null
                            ? const Center(child: Text('No photo selected'))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  photoBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                if (photoBase64 == null || photoBase64!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a photo first.')),
                  );
                  return;
                }

                await DatabaseService.instance.updateItem(
                  itemId: item.id,
                  name: nameController.text.trim(),
                  quantity: int.parse(quantityController.text.trim()),
                  imageKey: 'custom',
                  imageData: photoBase64,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();

    if (shouldSave == true && mounted) {
      await _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: _selectedBox?.id,
        searchQuery: _searchController.text,
      );
    }
  }

  Future<void> _showAddBatchDialog() async {
    final controller = TextEditingController();
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Batch'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Batch name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    final name = controller.text.trim();
    controller.dispose();

    if (shouldAdd != true || name.isEmpty) {
      return;
    }

    try {
      final batchId = await DatabaseService.instance.addBatch(name);
      if (!mounted) {
        return;
      }
      await _loadInventory(preferredBatchId: batchId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add batch. Name might already exist.')),
      );
    }
  }

  Future<void> _showRenameBatchDialog(BatchRecord batch) async {
    final controller = TextEditingController(text: batch.name);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Batch'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Batch name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final name = controller.text.trim();
    controller.dispose();

    if (shouldSave != true || name.isEmpty || name == batch.name) {
      return;
    }

    try {
      await DatabaseService.instance.renameBatch(batchId: batch.id, name: name);
      if (!mounted) {
        return;
      }
      await _loadInventory(preferredBatchId: batch.id, preferredBoxId: _selectedBox?.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename batch. Name might already exist.')),
      );
    }
  }

  Future<void> _showAddBoxDialog() async {
    final selectedBatch = _selectedBatch;
    if (selectedBatch == null) {
      return;
    }

    final controller = TextEditingController();
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Box to ${selectedBatch.name}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Box name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    final name = controller.text.trim();
    controller.dispose();

    if (shouldAdd != true || name.isEmpty) {
      return;
    }

    try {
      final boxId = await DatabaseService.instance.addBox(batchId: selectedBatch.id, name: name);
      if (!mounted) {
        return;
      }
      await _loadInventory(preferredBatchId: selectedBatch.id, preferredBoxId: boxId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add box.')),
      );
    }
  }

  Future<void> _showRenameBoxDialog(BoxRecord box) async {
    final controller = TextEditingController(text: box.name);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Box'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Box name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final name = controller.text.trim();
    controller.dispose();

    if (shouldSave != true || name.isEmpty || name == box.name) {
      return;
    }

    try {
      await DatabaseService.instance.renameBox(boxId: box.id, name: name);
      if (!mounted) {
        return;
      }
      await _loadInventory(
        preferredBatchId: _selectedBatch?.id,
        preferredBoxId: box.id,
        searchQuery: _searchController.text,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename box.')),
      );
    }
  }

  Future<void> _showInventoryActionsSheet() async {
    if (!widget.canManageInventory) {
      return;
    }
    final selectedBatch = _selectedBatch;
    final selectedBox = _selectedBox;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Inventory Actions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Batch', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Edit Batch',
                    icon: const Icon(Icons.drive_file_rename_outline),
                    onPressed: selectedBatch == null
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            _showRenameBatchDialog(selectedBatch);
                          },
                  ),
                  IconButton(
                    tooltip: 'Add Batch',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showAddBatchDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text('Box', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Edit Box',
                    icon: const Icon(Icons.drive_file_rename_outline),
                    onPressed: selectedBox == null
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            _showRenameBoxDialog(selectedBox);
                          },
                  ),
                  IconButton(
                    tooltip: 'Add Box',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: selectedBatch == null
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            _showAddBoxDialog();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Add Item',
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: selectedBox == null
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            _showAddItemDialog();
                          },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBatch = _selectedBatch;
    final selectedBox = _selectedBox;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Package Tracking',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Row(
                children: [
                  _ModeChip(
                    label: 'Inventory',
                    selected: _inventoryTabSelected,
                    onTap: showInventory,
                  ),
                  if (widget.canViewCollectedInventory) ...[
                    const SizedBox(width: 10),
                    _ModeChip(
                      label: 'Collected',
                      selected: _collectedTabSelected,
                      onTap: () {
                        setState(() {
                          _inventoryTabSelected = false;
                          _collectedTabSelected = true;
                        });
                        _loadCollectedRows();
                      },
                    ),
                  ],
                  const SizedBox(width: 10),
                  _IconChipButton(
                    icon: Icons.groups_2_outlined,
                    selected: !_inventoryTabSelected && !_collectedTabSelected,
                    tooltip: 'Cadet List',
                    onTap: () {
                      setState(() {
                        _inventoryTabSelected = false;
                        _collectedTabSelected = false;
                      });
                      _loadCadets();
                    },
                  ),
                  const Spacer(),
                  _inventoryTabSelected
                      ? (widget.canManageInventory
                          ? Tooltip(
                              message: 'Inventory Actions',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _showInventoryActionsSheet,
                                child: Container(
                                  width: 44,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4E9D72),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink())
                      : _collectedTabSelected
                          ? const SizedBox.shrink()
                          : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeChip(
                              label: '+Add Cadet',
                              selected: true,
                              onTap: _openAddCadet,
                            ),
                          ],
                        ),
                ],
              ),
              const SizedBox(height: 16),
              if (_inventoryTabSelected)
                Container(
                  height: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2ECFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x1A5B3D82)),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: _batches.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final batch = _batches[index];
                      final isSelected = batch.id == selectedBatch?.id;
                      return GestureDetector(
                        onTap: () => _changeBatch(batch),
                        onLongPress: widget.canManageInventory
                            ? () => _showRenameBatchDialog(batch)
                            : null,
                        child: Container(
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minWidth: 140, maxWidth: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE7EBFF) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            batch.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: isSelected ? const Color(0xFF2F6BFF) : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFFD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _inventoryTabSelected
                      ? (_isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                          children: [
                            Container(
                              width: 114,
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EDF9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                itemCount: _boxes.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final box = _boxes[index];
                                  final isSelected = box.id == selectedBox?.id;
                                  return GestureDetector(
                                    onTap: () => _changeBox(box),
                                    onLongPress: widget.canManageInventory
                                        ? () => _showRenameBoxDialog(box)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFE7EBFF) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 24,
                                          color: isSelected
                                              ? const Color(0xFF6B58F1)
                                              : Colors.black54,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          box.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                              controller: _searchController,
                                              onChanged: _onSearchChanged,
                                              decoration: const InputDecoration(
                                                hintText: 'Search items....',
                                                border: InputBorder.none,
                                                prefixIcon: Icon(Icons.search),
                                                contentPadding: EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
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
                                          ? const Center(
                                              child: Text(
                                                'No items in this box yet.',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            )
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                final calculatedColumns =
                                                    (constraints.maxWidth / 150).floor();
                                                final columns = calculatedColumns.clamp(4, 8);
                                                return GridView.builder(
                                                  itemCount: _items.length,
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: columns,
                                                    crossAxisSpacing: 8,
                                                    mainAxisSpacing: 8,
                                                    childAspectRatio: 0.95,
                                                  ),
                                                  itemBuilder: (context, index) {
                                                    final item = _items[index];
                                                    return _ItemCard(
                                                      item: item,
                                                      onEdit: widget.canManageInventory
                                                          ? () => _showEditItemDialog(item)
                                                          : null,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ))
                      : (_collectedTabSelected
                          ? _CollectedInventoryPanel(
                              rows: _collectedRows,
                              isLoading: _isCollectedLoading,
                            )
                          : _CadetListPanel(
                              cadets: _cadets,
                              controller: _cadetSearchController,
                              isLoading: _isCadetLoading,
                              onSearchChanged: (value) => _loadCadets(searchQuery: value),
                              onTapCadet: (summary) => _openCadetDetail(summary.toCadetRecord()),
                            )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
  });

  final ItemRecord item;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final imageData = item.imageData;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7D8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onEdit != null)
                  Material(
                    color: Colors.white.withOpacity(0.88),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onEdit,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF3E2E4E)),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26, height: 26),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'x ${item.quantity}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF352747),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: (imageData != null && imageData.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(imageData),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Icon(
                        _iconForImageKey(item.imageKey),
                        size: 40,
                        color: const Color(0xFF54406B),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2F2140),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectedInventoryPanel extends StatelessWidget {
  const _CollectedInventoryPanel({
    required this.rows,
    required this.isLoading,
  });

  final List<TransferRecord> rows;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No collected records yet.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    const headStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );
    const cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Item', style: headStyle)),
                Expanded(
                  flex: 1,
                  child: Center(child: Text('Qty', style: headStyle)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Cadet', style: headStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Center(child: Text('Date & Time', style: headStyle)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.itemName,
                          style: cellStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text('${row.quantity}', style: cellStyle),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${row.cadetName} (${row.cadetCode})',
                          style: cellStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            _dateTime(row.createdAtMillis),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
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
    );
  }
}

class _CadetListPanel extends StatelessWidget {
  const _CadetListPanel({
    required this.cadets,
    required this.controller,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onTapCadet,
  });

  final List<CadetHistorySummary> cadets;
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CadetHistorySummary> onTapCadet;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.w500,
      fontSize: 14,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
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
                    controller: controller,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search cadets',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(child: Text('Photo', style: headerStyle)),
                ),
                Expanded(flex: 3, child: Text('Name/ID', style: headerStyle)),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('Give', style: headerStyle)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('Collect', style: headerStyle)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('Holdings', style: headerStyle)),
                ),
                Expanded(
                  flex: 3,
                  child: Center(child: Text('Recent Date & Time', style: headerStyle)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : cadets.isEmpty
                    ? const Center(child: Text('No cadets yet. Tap + to add.'))
                    : ListView.separated(
                        itemCount: cadets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cadet = cadets[index];
                          final holdings = cadet.totalGiven - cadet.totalCollected;
                          final gaveLast = cadet.lastAction == 'give';
                          final collectedLast = cadet.lastAction == 'collect';
                          return GestureDetector(
                            onTap: () => onTapCadet(cadet),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: (cadet.photoData != null && cadet.photoData!.isNotEmpty)
                                            ? Image.memory(
                                                base64Decode(cadet.photoData!),
                                                fit: BoxFit.cover,
                                              )
                                            : const Icon(
                                                Icons.person,
                                                size: 22,
                                                color: Color(0xFF64748B),
                                              ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          cadet.cadetName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          cadet.cadetCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        '${cadet.totalGiven}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: gaveLast ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        '${cadet.totalCollected}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: collectedLast ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        '$holdings',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Text(
                                        cadet.lastActivityMillis == 0
                                            ? '-'
                                            : _dateTime(cadet.lastActivityMillis),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
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
    );
  }
}

String _dateTime(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${dt.year} $hh:$min';
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4E9D72) : const Color(0xFFE7F6F1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4E9D72) : const Color(0xFFE7F6F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

const List<(String, IconData, String)> _iconChoices = [
  ('water_drop', Icons.water_drop_outlined, 'Water'),
  ('gun', Icons.gps_fixed, 'Weapon'),
  ('shield', Icons.shield_outlined, 'Vest'),
  ('visibility', Icons.visibility_outlined, 'Optics'),
  ('radio', Icons.settings_input_antenna, 'Radio'),
  ('hiking', Icons.hiking, 'Boots'),
  ('military_tech', Icons.military_tech_outlined, 'Hat'),
  ('brightness_low', Icons.brightness_low, 'Grenade'),
  ('health_and_safety', Icons.health_and_safety_outlined, 'Helmet'),
  ('goggles', Icons.visibility, 'Goggles'),
  ('checkroom', Icons.checkroom, 'Uniform'),
  ('knife', Icons.construction, 'Knife'),
  ('flashlight_on', Icons.flashlight_on, 'Torch'),
  ('bullets', Icons.scatter_plot, 'Bullets'),
  ('backpack', Icons.backpack_outlined, 'Bag'),
  ('rope', Icons.timeline, 'Rope'),
  ('explore', Icons.explore_outlined, 'Compass'),
  ('map', Icons.map_outlined, 'Map'),
  ('medical_services', Icons.medical_services_outlined, 'Medical'),
  ('lunch_dining', Icons.lunch_dining_outlined, 'Rations'),
  ('light_mode', Icons.light_mode_outlined, 'Signal'),
  ('menu_book', Icons.menu_book_outlined, 'Manual'),
  ('front_hand', Icons.front_hand_outlined, 'Gloves'),
];

IconData _iconForImageKey(String imageKey) {
  switch (imageKey) {
    case 'water_drop':
      return Icons.water_drop_outlined;
    case 'gun':
      return Icons.gps_fixed;
    case 'shield':
      return Icons.shield_outlined;
    case 'visibility':
      return Icons.visibility_outlined;
    case 'radio':
      return Icons.settings_input_antenna;
    case 'hiking':
      return Icons.hiking;
    case 'military_tech':
      return Icons.military_tech_outlined;
    case 'brightness_low':
      return Icons.brightness_low;
    case 'health_and_safety':
      return Icons.health_and_safety_outlined;
    case 'goggles':
      return Icons.visibility;
    case 'checkroom':
      return Icons.checkroom;
    case 'knife':
      return Icons.construction;
    case 'flashlight_on':
      return Icons.flashlight_on;
    case 'bullets':
      return Icons.scatter_plot;
    case 'backpack':
      return Icons.backpack_outlined;
    case 'rope':
      return Icons.timeline;
    case 'explore':
      return Icons.explore_outlined;
    case 'map':
      return Icons.map_outlined;
    case 'medical_services':
      return Icons.medical_services_outlined;
    case 'lunch_dining':
      return Icons.lunch_dining_outlined;
    case 'light_mode':
      return Icons.light_mode_outlined;
    case 'menu_book':
      return Icons.menu_book_outlined;
    case 'front_hand':
      return Icons.front_hand_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}
