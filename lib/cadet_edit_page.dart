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

<<<<<<< HEAD
  Future<void> _delete() async {
  await DatabaseService.instance.deleteCadet(
    id: widget.cadet!.id,
  );
  if (!mounted) return;
    Navigator.of(context).pop(true);
  }

=======
>>>>>>> Kavi
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cadet != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEdit ? 'Edit Cadet' : 'Add Cadet',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Container(
                    width: 560,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6E4E0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 80,
                                      child: Text('Cadet ID'),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _cadetIdController,
                                        decoration: const InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Enter cadet id';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 80,
                                      child: Text('Name'),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Enter name';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Column(
                            children: [
                              Text(isEdit ? 'Edit Picture' : 'Upload Picture'),
                              const SizedBox(height: 10),
                              Container(
                                height: 120,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black54),
                                ),
                                child: _photoBytes == null
                                    ? const Icon(Icons.account_circle, size: 90, color: Colors.grey)
                                    : Image.memory(_photoBytes!, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (!kIsWeb)
                                    IconButton(
                                      onPressed: _saving ? null : () => _pickPhoto(ImageSource.camera),
                                      icon: const Icon(Icons.photo_camera_outlined),
                                    ),
                                  IconButton(
                                    onPressed: _saving ? null : () => _pickPhoto(ImageSource.gallery),
                                    icon: const Icon(Icons.upload_file),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Back'),
                  ),
<<<<<<< HEAD
                  if (isEdit && !_saving)
                    FilledButton.icon(
                    onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 158, 16, 16),    // button color
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),    // text color
                      ),
                    ),
=======
>>>>>>> Kavi
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

