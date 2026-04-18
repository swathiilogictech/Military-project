import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final statCards = <_StatCardData>[
      const _StatCardData(
        title: 'Number of\nCadets',
        value: '5',
        color: Color(0xFF88CF10),
      ),
      const _StatCardData(
        title: 'Given Items',
        value: '32',
        color: Color(0xFFA77AEE),
      ),
      const _StatCardData(
        title: 'Collected\nItems',
        value: '17',
        color: Color(0xFFB25294),
      ),
      const _StatCardData(
        title: 'Batches',
        value: '5',
        color: Color(0xFF6FA7B3),
      ),
      const _StatCardData(
        title: 'Boxes',
        value: '25',
        color: Color(0xFFC44C62),
      ),
      const _StatCardData(
        title: 'Items',
        value: '90',
        color: Color(0xFFB27431),
      ),
    ];

    final transfers = <_TransferData>[
      const _TransferData(
        name: 'Daniel',
        id: '24023100',
        taken: '7',
        returned: '-',
        date: '05/04/2026',
        time: '1:10pm',
      ),
      const _TransferData(
        name: 'Subash',
        id: '24023167',
        taken: '-',
        returned: '5',
        date: '14/04/2026',
        time: '10:18pm',
      ),
      const _TransferData(
        name: 'Swathi',
        id: '24023141',
        taken: '-',
        returned: '5',
        date: '08/04/2026',
        time: '11:28pm',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202020),
                    ),
                  ),
                ),
              ),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF8A8A8A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              GridView.builder(
                shrinkWrap: true,
                itemCount: statCards.length,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final card = statCards[index];
                  return _StatCard(data: card);
                },
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2FA0CB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Recent Transfers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTableHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _TransferCard(data: transfers[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.ios_share_outlined),
            label: 'Share',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_checkout_outlined),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_outlined),
            label: 'Folder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.w500,
      fontSize: 14,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFA4A0A1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Profile', style: headerStyle)),
          Expanded(flex: 3, child: Text('Name/ID', style: headerStyle)),
          Expanded(flex: 2, child: Text('Taken', style: headerStyle)),
          Expanded(flex: 2, child: Text('Returned', style: headerStyle)),
          Expanded(flex: 2, child: Text('Time', style: headerStyle)),
          Expanded(flex: 1, child: Text('Edit', style: headerStyle)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.data});

  final _TransferData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC9C9C9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 64,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_circle,
                size: 54,
                color: Color(0xFFD7D7D7),
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
                  data.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Text(
                  data.id,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                data.taken,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                data.returned,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.date, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 3),
                Text(data.time, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Icon(Icons.edit_outlined, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;
}

class _TransferData {
  const _TransferData({
    required this.name,
    required this.id,
    required this.taken,
    required this.returned,
    required this.date,
    required this.time,
  });

  final String name;
  final String id;
  final String taken;
  final String returned;
  final String date;
  final String time;
}
