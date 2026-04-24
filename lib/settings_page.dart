import 'package:flutter/material.dart';

import 'database_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _newUserController = TextEditingController();
  final _newUserNameController = TextEditingController();
  final _newUserPasswordController = TextEditingController();

  List<AppUser> _staffUsers = const [];
  bool _loading = true;
  bool _canManageInventory = true;
  bool _canCadetImportExport = false;
  bool _canViewCollectedInventory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _newUserController.dispose();
    _newUserNameController.dispose();
    _newUserPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final current = DatabaseService.instance.currentUser;
    final staff = await DatabaseService.instance.getStaffUsers();
    if (!mounted) return;
    _nameController.text = current?.fullName ?? '';
    setState(() {
      _staffUsers = staff;
      _loading = false;
    });
  }

  Future<void> _saveAdminProfile() async {
    await DatabaseService.instance.updateCurrentUserProfile(
      fullName: _nameController.text,
      password: _passwordController.text.trim().isEmpty ? null : _passwordController.text,
    );
    if (!mounted) return;
    _passwordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin profile updated.')),
    );
  }

  Future<void> _createStaff() async {
    final username = _newUserController.text.trim();
    final fullName = _newUserNameController.text.trim();
    final password = _newUserPasswordController.text;
    if (username.isEmpty || fullName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter username, name and password.')),
      );
      return;
    }
    try {
      await DatabaseService.instance.createStaffUser(
        username: username,
        password: password,
        fullName: fullName,
        canManageInventory: _canManageInventory,
        canCadetImportExport: _canCadetImportExport,
        canViewCollectedInventory: _canViewCollectedInventory,
      );
      _newUserController.clear();
      _newUserNameController.clear();
      _newUserPasswordController.clear();
      _canManageInventory = true;
      _canCadetImportExport = false;
      _canViewCollectedInventory = false;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff created.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create staff. Username may exist.')),
      );
    }
  }

  Future<void> _updatePermissions(AppUser user, {
    bool? manageInventory,
    bool? cadetImportExport,
    bool? viewCollectedInventory,
  }) async {
    await DatabaseService.instance.updateStaffPermissions(
      userId: user.id,
      canManageInventory: manageInventory ?? user.canManageInventory,
      canCadetImportExport: cadetImportExport ?? user.canCadetImportExport,
      canViewCollectedInventory: viewCollectedInventory ?? user.canViewCollectedInventory,
    );
    await _load();
  }

  Future<void> _resetPassword(AppUser user) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password: ${user.username}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final value = controller.text;
    if (value.trim().isEmpty) return;
    await DatabaseService.instance.resetStaffPassword(userId: user.id, newPassword: value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = DatabaseService.instance.currentUser;
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Username: ${current?.username ?? 'admin'}'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Full name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Change admin password'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _saveAdminProfile,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Staff',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserController,
                          decoration: const InputDecoration(labelText: 'Username'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserNameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                        ),
                        CheckboxListTile(
                          value: _canManageInventory,
                          onChanged: (v) => setState(() => _canManageInventory = v ?? false),
                          title: const Text('Allow add/modify inventory'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _canCadetImportExport,
                          onChanged: (v) => setState(() => _canCadetImportExport = v ?? false),
                          title: const Text('Allow cadet import/export'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _canViewCollectedInventory,
                          onChanged: (v) => setState(() => _canViewCollectedInventory = v ?? false),
                          title: const Text('Allow collected inventory view'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _createStaff,
                            child: const Text('Create Staff'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff Access',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (_staffUsers.isEmpty) const Text('No staff users yet.'),
                        for (final staff in _staffUsers)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${staff.fullName} (${staff.username})',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: staff.canManageInventory,
                                          onChanged: (v) => _updatePermissions(
                                            staff,
                                            manageInventory: v ?? false,
                                          ),
                                        ),
                                        const Text('Inventory'),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: staff.canCadetImportExport,
                                          onChanged: (v) => _updatePermissions(
                                            staff,
                                            cadetImportExport: v ?? false,
                                          ),
                                        ),
                                        const Text('Cadet Import/Export'),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: staff.canViewCollectedInventory,
                                          onChanged: (v) => _updatePermissions(
                                            staff,
                                            viewCollectedInventory: v ?? false,
                                          ),
                                        ),
                                        const Text('Collected Inventory'),
                                      ],
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton(
                                    onPressed: () => _resetPassword(staff),
                                    child: const Text('Reset Password'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

