import 'package:flutter/material.dart';

import 'database_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onOpenCadets,
    required this.onOpenInventory,
    required this.onOpenGivenHistory,
    required this.onOpenCollectedHistory,
  });

  final VoidCallback onOpenCadets;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenGivenHistory;
  final VoidCallback onOpenCollectedHistory;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Package Tracking',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<DashboardCounts>(
              future: DatabaseService.instance.getDashboardCounts(),
              builder: (context, snapshot) {
                final counts = snapshot.data;
                final cards = <_StatCardData>[
                  _StatCardData(
                    title: 'Cadets',
                    value: '${counts?.cadets ?? 0}',
                    color: const Color(0xFFE0F2FE),
                    textColor: const Color(0xFF0C4A6E),
                    onTap: onOpenCadets,
                  ),
                  _StatCardData(
                    title: 'Given',
                    value: '${counts?.givenItems ?? 0}',
                    color: const Color(0xFFDCFCE7),
                    textColor: const Color(0xFF14532D),
                    onTap: onOpenGivenHistory,
                  ),
                  _StatCardData(
                    title: 'Collected',
                    value: '${counts?.collectedItems ?? 0}',
                    color: const Color(0xFFFFEDD5),
                    textColor: const Color(0xFF7C2D12),
                    onTap: onOpenCollectedHistory,
                  ),
                  _StatCardData(
                    title: 'Batches',
                    value: '${counts?.batches ?? 0}',
                    color: const Color(0xFFEDE9FE),
                    textColor: const Color(0xFF4C1D95),
                    onTap: onOpenInventory,
                  ),
                  _StatCardData(
                    title: 'Boxes',
                    value: '${counts?.boxes ?? 0}',
                    color: const Color(0xFFF1F5F9),
                    textColor: const Color(0xFF334155),
                    onTap: onOpenInventory,
                  ),
                  _StatCardData(
                    title: 'Items',
                    value: '${counts?.itemQuantity ?? 0}',
                    color: const Color(0xFFFEF3C7),
                    textColor: const Color(0xFF78350F),
                    onTap: onOpenInventory,
                  ),
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) => _StatCard(data: cards[index]),
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Recent Cadet Activity',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<CadetHistorySummary>>(
              future: DatabaseService.instance.getCadetHistorySummaries(limit: 8),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <CadetHistorySummary>[];
                if (rows.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: Text('No recent activity.')),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final holding = row.totalGiven - row.totalCollected;
                          return ListTile(
                            dense: true,
                            title: Text('${row.cadetName} (${row.cadetCode})'),
                            subtitle: Text('G: ${row.totalGiven}  C: ${row.totalCollected}  H: $holding'),
                            trailing: Text(row.lastActivityMillis == 0
                                ? '-'
                                : _formatDateTime(DateTime.fromMillisecondsSinceEpoch(row.lastActivityMillis))),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: data.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  color: data.textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 24,
                  color: data.textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
}

String _formatDateTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour12:$mm $ampm';
}
