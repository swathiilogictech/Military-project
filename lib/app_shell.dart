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

  /// Shows the beautiful logout confirmation dialog.
  Future<void> _showLogoutDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout Dialog',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _LogoutDialog();
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _logout();
      }
    });
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
            // Show confirmation popup instead of logging out directly
            _showLogoutDialog();
            return;
          }
          _setIndex(index);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logout Confirmation Dialog Widget
// ---------------------------------------------------------------------------

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog();

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconRotation;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconRotation = Tween<double>(begin: 0.0, end: 0.08).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    // Subtle entrance wiggle on the icon
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _iconController.forward();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    setState(() => _isLoggingOut = true);
    // Small delay for visual feedback before dismissing
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top accent strip ──────────────────────────────────────────
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFB13E4B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Icon ─────────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _iconRotation,
                builder: (context, child) => Transform.rotate(
                  angle: _iconRotation.value,
                  child: child,
                ),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFB13E4B).withOpacity(0.18),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 30,
                    color: Color(0xFFB13E4B),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────────
              const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 10),

              // ── Subtitle ──────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Divider ───────────────────────────────────────────────────
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // ── Buttons ───────────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        textColor: const Color(0xFF475569),
                        backgroundColor: Colors.transparent,
                        onTap: _isLoggingOut
                            ? null
                            : () => Navigator.of(context).pop(false),
                        isLeft: true,
                      ),
                    ),

                    // Vertical divider
                    const VerticalDivider(
                      width: 1,
                      color: Color(0xFFE2E8F0),
                    ),

                    // Sign Out button
                    Expanded(
                      child: _DialogButton(
                        label: _isLoggingOut ? 'Signing out…' : 'Log Out',
                        textColor: const Color(0xFFB13E4B),
                        backgroundColor: Colors.transparent,
                        fontWeight: FontWeight.w700,
                        onTap: _isLoggingOut ? null : _confirmLogout,
                        isLeft: false,
                        isLoading: _isLoggingOut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: Dialog Button
// ---------------------------------------------------------------------------

class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.onTap,
    required this.isLeft,
    this.fontWeight = FontWeight.w500,
    this.isLoading = false,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool isLeft;
  final FontWeight fontWeight;
  final bool isLoading;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFFF1F5F9)
              : widget.backgroundColor,
          borderRadius: BorderRadius.only(
            bottomLeft: widget.isLeft ? const Radius.circular(20) : Radius.zero,
            bottomRight: widget.isLeft ? Radius.zero : const Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: widget.isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.textColor,
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: widget.fontWeight,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}