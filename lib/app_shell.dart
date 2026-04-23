import 'package:flutter/material.dart';

import 'collect_page.dart';
import 'dashboard_page.dart';
import 'give_page.dart';
import 'history_page.dart';
import 'inventory_page.dart';
import 'login_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'database_service.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _index = 0;
  final GlobalKey<InventoryPageState> _inventoryKey = GlobalKey<InventoryPageState>();
  final GlobalKey<HistoryPageState> _historyKey = GlobalKey<HistoryPageState>();
  late final List<Widget> _pages;
  late final bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.user.isAdmin;
    _pages = <Widget>[
      DashboardPage(
        onOpenCadets: () {
          _setIndex(3);
          _inventoryKey.currentState?.showCadets();
        },
        onOpenInventory: () {
          _setIndex(3);
          _inventoryKey.currentState?.showInventory();
        },
        onOpenGivenHistory: () {
          _setIndex(4);
          _historyKey.currentState?.setActionFilter('give');
        },
        onOpenCollectedHistory: () {
          _setIndex(4);
          _historyKey.currentState?.setActionFilter('collect');
        },
      ),
      const GivePage(),
      const CollectPage(),
      InventoryPage(
        key: _inventoryKey,
        canManageInventory: widget.user.isAdmin || widget.user.canManageInventory,
        canCadetImportExport: widget.user.isAdmin || widget.user.canCadetImportExport,
        canViewCollectedInventory: widget.user.isAdmin || widget.user.canViewCollectedInventory,
      ),
      HistoryPage(key: _historyKey),
      const ReportsPage(),
      if (_isAdmin) const SettingsPage(),
    ];
  }

  void _setIndex(int index) {
    setState(() {
      _index = index;
    });
  }

  Future<void> _logout() async {
    DatabaseService.instance.logoutUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF475569),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 22),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.call_made),
            activeIcon: Icon(Icons.call_made),
            label: 'Give',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.call_received),
            activeIcon: Icon(Icons.call_received),
            label: 'Collect',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.logout_outlined),
            activeIcon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        onTap: (index) {
          final settingsIndex = _isAdmin ? 6 : -1;
          final logoutIndex = _isAdmin ? 7 : 6;
          if (_isAdmin && index == settingsIndex) {
            _setIndex(index);
            return;
          }
          if (index == logoutIndex) {
            _logout();
            return;
          }
          _setIndex(index);
        },
      ),
    );
  }
}
