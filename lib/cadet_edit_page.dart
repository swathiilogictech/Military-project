import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'database_service.dart';

class CadetEditPage extends StatefulWidget {
  const CadetEditPage({
    super.key,
    this.cadet,
  });

  final CadetRecord? cadet;

  @override
  State<CadetEditPage> createState() => _CadetEditPageState();
}

class _CadetEditPageState extends State<CadetEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cadetIdController;
  late final TextEditingController _nameController;

  Uint8List? _photoBytes;
  String? _photoBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cadetIdController = TextEditingController(text: widget.cadet?.cadetId ?? '');
    _nameController = TextEditingController(text: widget.cadet?.name ?? '');

    final existing = widget.cadet?.photoData;
    if (existing != null && existing.isNotEmpty) {
      _photoBase64 = existing;
      _photoBytes = base64Decode(existing);
    }
  }

  @override
  void dispose() {
    _cadetIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoBase64 = base64Encode(bytes);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final cadetId = _cadetIdController.text.trim();
      final name = _nameController.text.trim();

      if (widget.cadet == null) {
        await DatabaseService.instance.addCadet(
          cadetId: cadetId,
          name: name,
          photoData: _photoBase64,
        );
      } else {
        await DatabaseService.instance.updateCadet(
          id: widget.cadet!.id,
          cadetId: cadetId,
          name: name,
          photoData: _photoBase64,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save cadet. Cadet ID must be unique.')),
      );
    }
  }

  Future<void> _delete() async {
    await DatabaseService.instance.deleteCadet(
      id: widget.cadet!.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6DAE3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2B4C7E), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cadet != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Cadet' : 'Add Cadet'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFD7DCE6)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            SizedBox(
                              width: 380,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _cadetIdController,
                                    decoration: _fieldDecoration('Cadet ID'),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter cadet ID';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: _fieldDecoration('Name'),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter name';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Column(
                                children: [
                                  Container(
                                    height: 140,
                                    width: 140,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F8FB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD7DCE6)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _photoBytes == null
                                        ? const Icon(Icons.account_circle, size: 92, color: Color(0xFF9AA3B2))
                                        : Image.memory(_photoBytes!, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (!kIsWeb)
                                        IconButton.filledTonal(
                                          tooltip: 'Camera',
                                          onPressed: _saving ? null : () => _pickPhoto(ImageSource.camera),
                                          icon: const Icon(Icons.photo_camera_outlined),
                                        ),
                                      IconButton.filledTonal(
                                        tooltip: 'Gallery',
                                        onPressed: _saving ? null : () => _pickPhoto(ImageSource.gallery),
                                        icon: const Icon(Icons.upload_file),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            if (isEdit && !_saving) ...[
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _delete,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF8C1D18),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(isEdit ? 'Save Changes' : 'Create Cadet'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

