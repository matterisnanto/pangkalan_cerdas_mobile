import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../services/firebase_service.dart';
import '../../services/batch_verification_service.dart';
import '../../services/mypertamina_api_service.dart';
import '../widgets/glass_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/apple_background.dart';
import '../widgets/theme_toggle_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _delay = 3;
  bool _busy = false;
  List<Map<String, String>> _accounts = [];
  final _storage = SecureStorageService();
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _delay = await _storage.getTransactionDelay();
    final raw = await _storage.readPangkalanAccounts();
    if (raw != null && raw.isNotEmpty) {
      try {
        _accounts = (jsonDecode(raw) as List)
            .map((item) => Map<String, String>.from(item as Map))
            .toList();
      } catch (_) {
        _accounts = [];
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveAccounts() async {
    await context.read<AuthProvider>().savePangkalanAccount(_accounts);
  }

  Future<void> _editAccount([int? index]) async {
    final account = index == null ? null : _accounts[index];
    final name = TextEditingController(text: account?['name']);
    final username = TextEditingController(text: account?['username']);
    final password = TextEditingController(text: account?['password']);
    final authProvider = context.read<AuthProvider>();
    final messengerContext = context;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          index == null ? 'Tambah Akun Pangkalan' : 'Edit Akun Pangkalan',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama Pangkalan'),
              ),
              TextField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'Username / Email / No HP',
                ),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(),
              'username': username.text.trim(),
              'password': password.text,
            }),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    name.dispose();
    username.dispose();
    password.dispose();
    if (result == null || result.values.any((value) => value.isEmpty)) return;
    setState(() {
      if (index == null) {
        _accounts.add(result);
      } else {
        _accounts[index] = result;
      }
    });
    await authProvider.saveAccountWithoutNotify(_accounts);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messengerContext.mounted) {
        authProvider.refreshAccountList();
        ScaffoldMessenger.of(messengerContext).showSnackBar(
          const SnackBar(content: Text('Akun pangkalan berhasil disimpan!')),
        );
      }
    });
  }

  Future<void> _deleteAccount(int index) async {
    setState(() => _accounts.removeAt(index));
    await _saveAccounts();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun pangkalan dihapus!')),
        );
      }
    });
  }

  Future<void> _clearSession() async {
    await SecureStorageService().clearAll();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache sesi dihapus')));
    }
  }

  Future<void> _verifyAll() async {
    final auth = context.read<AuthProvider>();
    if (auth.registrationId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final list = await FirebaseService().getAllPelanggan(auth.registrationId);
      final result =
          await BatchVerificationService(
            api: MyPertaminaApiService(auth.apiClient),
          ).batchVerifyAndSyncWithMyPertamina(
            customers: list,
            registrationId: auth.registrationId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.verified} pelanggan terverifikasi; ${result.failed} gagal',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GlassAppBar(title: 'Pengaturan'),
    body: AppleBackground(
      child: Consumer<AuthProvider>(
        builder: (_, auth, child) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('Tema aplikasi'),
                subtitle: Text('Beralih antara Light Mode dan Dark Mode'),
                trailing: ThemeToggleButton(),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                title: const Text('Profil Pangkalan'),
                subtitle: Text('${auth.storeName}\nID: ${auth.registrationId}'),
                leading: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                title: const Text('Auto-scoping aktif'),
                subtitle: const Text(
                  'Nama dan registrationId disinkronkan otomatis dari GET /general/v1/users/profile.',
                ),
                leading: const Icon(Icons.hub_outlined),
                trailing: IconButton(
                  onPressed: auth.fetchUserProfile,
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sinkronkan profil',
                ),
              ),
            ),
            GlassCard(
              child: ListTile(
                title: const Text('Jeda transaksi'),
                subtitle: Text('$_delay detik'),
                leading: const Icon(Icons.timer_outlined),
                trailing: DropdownButton<int>(
                  value: _delay,
                  items: [2, 3, 4, 5]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v detik')),
                      )
                      .toList(),
                  onChanged: (v) async {
                    final value = v ?? 3;
                    setState(() => _delay = value);
                    await SecureStorageService().saveTransactionDelay(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Token & Sesi'),
                    subtitle: Text(
                      auth.isTokenAvailable
                          ? 'Token tersedia'
                          : 'Token belum tersedia',
                    ),
                    leading: const Icon(Icons.vpn_key_outlined),
                  ),
                  GlassButton(
                    label: 'Perbarui Token via WebView',
                    icon: Icons.language,
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton.icon(
                    onPressed: _clearSession,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Cache Sesi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Manajemen Akun Pangkalan'),
                    subtitle: Text(
                      '${_accounts.length} akun tersimpan terenkripsi',
                    ),
                    leading: const Icon(Icons.manage_accounts_outlined),
                    trailing: IconButton(
                      onPressed: () => _editAccount(),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  ..._accounts.asMap().entries.map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(entry.value['name'] ?? ''),
                      subtitle: Text(entry.value['username'] ?? ''),
                      leading: const Icon(Icons.store_outlined),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            onPressed: () => _editAccount(entry.key),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteAccount(entry.key),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                title: const Text('Sync & Backup'),
                subtitle: const Text(
                  'Verifikasi ulang semua pelanggan ke MyPertamina API',
                ),
                leading: const Icon(Icons.sync),
                trailing: _busy
                    ? const CircularProgressIndicator()
                    : IconButton(
                        onPressed: _verifyAll,
                        icon: const Icon(Icons.refresh),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
