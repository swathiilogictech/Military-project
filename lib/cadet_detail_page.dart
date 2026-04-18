import 'dart:convert';

import 'package:flutter/material.dart';

import 'database_service.dart';
import 'cadet_edit_page.dart';

class CadetDetailPage extends StatelessWidget {
  const CadetDetailPage({
    super.key,
    required this.cadet,
  });

  final CadetRecord cadet;

  @override
  Widget build(BuildContext context) {
    final photoData = cadet.photoData;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                  Container(
                    height: 86,
                    width: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: (photoData != null && photoData.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              base64Decode(photoData),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.account_circle, size: 70, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name     : ${cadet.name}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Cadet ID : ${cadet.cadetId}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Recent   : -', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => CadetEditPage(cadet: cadet),
                        ),
                      );
                      if (context.mounted && updated == true) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 6),
                  _BackPillButton(onTap: () => Navigator.of(context).pop(false)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Give/Collect workflow comes next.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E9D72),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Give'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Give/Collect workflow comes next.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAED1C0),
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('Collect'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Collections',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFA4A0A1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Item')),
                    Expanded(flex: 1, child: Text('Batch')),
                    Expanded(flex: 2, child: Text('Box')),
                    Expanded(flex: 2, child: Text('Given')),
                    Expanded(flex: 2, child: Text('Collected')),
                    Expanded(flex: 2, child: Text('Status')),
                    Expanded(flex: 1, child: Text('Edit')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Expanded(
                child: Center(
                  child: Text('No transfer history yet.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackPillButton extends StatelessWidget {
  const _BackPillButton({required this.onTap});

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
