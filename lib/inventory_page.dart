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
<<<<<<< HEAD
    this.onBack,
  });

  final bool showCadets;
  final VoidCallback? onBack;
=======
  });

  final bool showCadets;
>>>>>>> Kavi

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
  String _cadetActionFilter = 'all';

  BatchRecord? _selectedBatch;
  BoxRecord? _selectedBox;
  bool _isLoading = true;
  bool _isCadetLoading = false;
  late bool _inventoryTabSelected;

  @override
  void initState() {
    super.initState();
    _inventoryTabSelected = !widget.showCadets;

    if (widget.showCadets) {
      _loadCadets();
    } else {
      _loadInventory();
    }
  }

  void showCadets() {
    if (!_inventoryTabSelected) {
      _loadCadets();
      return;
    }
    setState(() {
      _inventoryTabSelected = false;
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
    });
    _loadInventory(
      preferredBatchId: _selectedBatch?.id,
      preferredBoxId: _selectedBox?.id,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cadetSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory({
    int? preferredBatchId,
    int? preferredBoxId,
    String? searchQuery,
  }) async {
    setState(() {
      _isLoading = true;
    });

    final batches = await DatabaseService.instance.getBatches();
    if (batches.isEmpty) {
      if (!mounted) {
        return;
      }
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
    final selectedBox = boxes.firstWhere(
      (box) => box.id == preferredBoxId,
      orElse: () => boxes.first,
    );

    final items = await DatabaseService.instance.getItemsForBox(
      selectedBox.id,
      searchQuery: searchQuery ?? _searchController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _batches = batches;
      _boxes = boxes;
      _items = items;
      _selectedBatch = selectedBatch;
      _selectedBox = selectedBox;
      _isLoading = false;
    });
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
      action: _cadetActionFilter,
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

  Future<void> _openEditCadet(CadetRecord cadet) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CadetEditPage(cadet: cadet),
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
    final selectedBatch = _selectedBatch;
    final selectedBox = _selectedBox;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Add Item'),
                enabled: selectedBox != null,
                onTap: selectedBox == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _showAddItemDialog();
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add Batch'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAddBatchDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename Batch'),
                enabled: selectedBatch != null,
                onTap: selectedBatch == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _showRenameBatchDialog(selectedBatch);
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Box'),
                enabled: selectedBatch != null,
                onTap: selectedBatch == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _showAddBoxDialog();
                      },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename Box'),
                enabled: selectedBox != null,
                onTap: selectedBox == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _showRenameBoxDialog(selectedBox);
                      },
              ),
              const SizedBox(height: 10),
            ],
          ),
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
                    onTap: () {
                      setState(() {
                        _inventoryTabSelected = true;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  _ModeChip(
                    label: 'Cadet List',
                    selected: !_inventoryTabSelected,
                    onTap: () {
                      setState(() {
                        _inventoryTabSelected = false;
                      });
                      _loadCadets();
                    },
                  ),
                  const Spacer(),
                  _TopActionButton(
                    icon: Icons.add,
                    onTap: _inventoryTabSelected ? _showInventoryActionsSheet : _openAddCadet,
                  ),
                  const SizedBox(width: 12),
                  _BackButton(
                    onTap: () {
                      if (!_inventoryTabSelected) {
                        setState(() {
                          _inventoryTabSelected = true;
                        });
                        return;
                      }
<<<<<<< HEAD
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
=======
                      Navigator.of(context).maybePop();
>>>>>>> Kavi
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_inventoryTabSelected)
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
                        onTap: () => _changeBatch(batch),
                        onLongPress: () => _showRenameBatchDialog(batch),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE7EBFF) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
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
                              width: 58,
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
                                    onTap: () => _changeBox(box),
                                    onLongPress: () => _showRenameBoxDialog(box),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          color: isSelected
                                              ? const Color(0xFF6B58F1)
                                              : Colors.black54,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          box.name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
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
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: _showAddItemDialog,
                                          child: const Icon(
                                            Icons.add,
                                            color: Color(0xFF5D8BFF),
                                            size: 28,
                                          ),
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
                                          : GridView.builder(
                                              itemCount: _items.length,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 4,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                                childAspectRatio: 0.78,
                                              ),
                                              itemBuilder: (context, index) {
                                                final item = _items[index];
                                                return _ItemCard(
                                                  item: item,
                                                  onEdit: () => _showEditItemDialog(item),
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
                      : _CadetListPanel(
                          cadets: _cadets,
                          actionFilter: _cadetActionFilter,
                          controller: _cadetSearchController,
                          isLoading: _isCadetLoading,
                          onSearchChanged: (value) => _loadCadets(searchQuery: value),
                          onFilterChanged: (value) async {
                            setState(() {
                              _cadetActionFilter = value;
                            });
                            await _loadCadets();
                          },
                          onTapCadet: (summary) => _openCadetDetail(summary.toCadetRecord()),
                          onEditCadet: (summary) => _openEditCadet(summary.toCadetRecord()),
                        ),
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
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final imageData = item.imageData;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2CCFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (imageData != null && imageData.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                base64Decode(imageData),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                _iconForImageKey(item.imageKey),
                                size: 52,
                                color: const Color(0xFF54406B),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'x ${item.quantity}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CadetListPanel extends StatelessWidget {
  const _CadetListPanel({
    required this.cadets,
    required this.actionFilter,
    required this.controller,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onTapCadet,
    required this.onEditCadet,
  });

  final List<CadetHistorySummary> cadets;
  final String actionFilter;
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<CadetHistorySummary> onTapCadet;
  final ValueChanged<CadetHistorySummary> onEditCadet;

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
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: actionFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'give', child: Text('Given')),
                  DropdownMenuItem(value: 'collect', child: Text('Collected')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onFilterChanged(value);
                },
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
                Expanded(flex: 4, child: Text('Name/ID', style: headerStyle)),
                Expanded(flex: 2, child: Text('Given', style: headerStyle)),
                Expanded(flex: 2, child: Text('Returned', style: headerStyle)),
                Expanded(flex: 2, child: Text('Recent/Date', style: headerStyle)),
<<<<<<< HEAD
                
=======
                Expanded(flex: 1, child: Text('Edit', style: headerStyle)),
>>>>>>> Kavi
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
                                    flex: 4,
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
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        '${cadet.totalCollected}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        cadet.lastActivityMillis == 0
                                            ? '-'
                                            : _dateOnly(cadet.lastActivityMillis),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
<<<<<<< HEAD
                              
=======
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: IconButton(
                                        onPressed: () => onEditCadet(cadet),
                                        icon: const Icon(Icons.edit_outlined, size: 24),
                                      ),
                                    ),
                                  ),
>>>>>>> Kavi
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

String _dateOnly(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  return '$dd/$mm/${dt.year}';
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
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 30),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF3FF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          'Back',
          style: TextStyle(fontWeight: FontWeight.w600),
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
