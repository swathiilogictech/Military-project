import 'package:flutter/material.dart';

import 'collect_page.dart';
import 'dashboard_page.dart';
import 'give_page.dart';
import 'history_page.dart';
import 'inventory_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _index = 0;
  final GlobalKey<InventoryPageState> _inventoryKey = GlobalKey<InventoryPageState>();

  void _setIndex(int index) {
    setState(() {
      _index = index;
    });
  }

  Future<void> _logout() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        onOpenCadets: () {
          _setIndex(3);
          _inventoryKey.currentState?.showCadets();
        },
        onOpenInventory: () {
          _setIndex(3);
          _inventoryKey.currentState?.showInventory();
        },
      ),
      const GivePage(),
      const CollectPage(),
      InventoryPage(key: _inventoryKey),
      const HistoryPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.call_made), label: 'Give'),
          BottomNavigationBarItem(icon: Icon(Icons.call_received), label: 'Collect'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
        ],
        onTap: (index) {
          if (index == 5) {
            _openSettings();
            return;
          }
          if (index == 6) {
            _logout();
            return;
          }
          _setIndex(index);
        },
      ),
    );
  }
}
