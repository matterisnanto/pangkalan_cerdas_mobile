import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../services/firebase_service.dart';
import '../../services/batch_verification_service.dart';
import '../../services/mypertamina_api_service.dart';
import '../widgets/glass_components.dart';
import '../widgets/apple_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _delay = 3;
  bool _busy = false;
  Future<void> _clearSession() async {
    await SecureStorageService().clearAll();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache sesi dihapus')));
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.verified} pelanggan terverifikasi; ${result.failed} gagal',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GlassAppBar(title: 'Pengaturan'),
    body: AppleBackground(
      child: Consumer<AuthProvider>(
        builder: (_, auth, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  onChanged: (v) => setState(() => _delay = v ?? 3),
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
