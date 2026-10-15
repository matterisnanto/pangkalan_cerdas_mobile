import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/mypertamina_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_queue_provider.dart';
import '../../services/automation_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenWebView;
  const HomeScreen({super.key, this.onOpenWebView});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _automation = AutomationService();
  List<SmartQueueEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQueue());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (auth.isTokenValid && auth.stockAvailable == 0 && !auth.isStockLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AuthProvider>().fetchProductAndStockFromApi();
      });
    }
  }

  Future<void> _loadQueue() async {
    final auth = context.read<AuthProvider>();
    if (auth.isTokenValid) await auth.fetchProductAndStockFromApi();
    if (auth.registrationId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final result = await _automation.generateSmartQueue(
      targetStock: auth.stockAvailable,
      registrationId: auth.registrationId,
    );
    if (!mounted) return;
    setState(() {
      _entries = result.entries;
      _loading = false;
    });
    final queue = context.read<TransactionQueueProvider>();
    queue.configure(
      apiClient: auth.apiClient,
      registrationId: auth.registrationId,
      pangkalanName: auth.storeName,
      stockAvailable: auth.stockAvailable,
      sold: auth.sold,
      onQueueCompleted: auth.fetchProductAndStockFromApi,
    );
    queue.setQueue(_entries.map((e) => e.pelanggan).toList());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final queue = context.watch<TransactionQueueProvider>();
    final safe = _entries.where((e) => e.aman).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          auth.isTokenValid && auth.storeName.isNotEmpty
              ? 'Pangkalan ${auth.storeName}'
              : 'Belum Login - Buka WebView',
        ),
        actions: [_TokenPill(active: auth.isTokenValid)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.isTokenValid && auth.profile != null)
              _ProfileCard(profile: auth.profile!)
            else
              _LoginCard(onLogin: widget.onOpenWebView),
            const SizedBox(height: 14),
            _StockCard(
              stockAvailable: auth.isTokenValid ? auth.stockAvailable : 0,
              sold: auth.isTokenValid ? auth.sold : 0,
              stockRedeem: auth.isTokenValid ? auth.stockRedeem : 0,
              price: auth.isTokenValid ? auth.price : 0,
              expired: !auth.isTokenValid,
              loading: auth.isStockLoading,
              onSync: auth.isTokenValid
                  ? () => auth.fetchProductAndStockFromApi()
                  : null,
            ),
            const SizedBox(height: 14),
            _ControlCard(
              queue: queue,
              total: _entries.length,
              safe: safe,
              onStart: queue.executeQueue,
              onPause: queue.pauseQueue,
              onReset: () {
                queue.clearQueue();
                _loadQueue();
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Daftar Antrean Pelanggan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text('Antrean kosong atau stok belum disinkronkan.'),
                ),
              )
            else
              ..._entries.asMap().entries.map(
                (e) => _QueueCard(entry: e.value, index: e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final VoidCallback? onLogin;
  const _LoginCard({this.onLogin});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lock_outline, color: Colors.red),
      title: const Text('Belum Login / Token Kadaluarsa'),
      subtitle: const Text(
        'Sesi habis. Login melalui WebView untuk memuat profil pangkalan.',
      ),
      trailing: FilledButton(
        onPressed: onLogin,
        child: const Text('Buka WebView'),
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  final PangkalanProfileModel profile;
  const _ProfileCard({required this.profile});
  @override
  Widget build(BuildContext context) {
    final address = [
      profile.storeAddress,
      profile.villageName,
      profile.ditrictName,
      profile.city,
      profile.province,
    ].where((value) => value.isNotEmpty).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informasi Pangkalan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const _TokenPill(active: true),
              ],
            ),
            const Divider(),
            _ProfileLine('Nama Pangkalan', profile.storeName),
            _ProfileLine('ID Registrasi', profile.registrationId),
            _ProfileLine('Pemilik / Pengelola', profile.name),
            _ProfileLine('Alamat Lengkap', address),
            _ProfileLine('No. Telepon', profile.phoneNumber),
            _ProfileLine('Agen / Penyalur Resmi', profile.agenName),
          ],
        ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String label, value;
  const _ProfileLine(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _TokenPill extends StatelessWidget {
  final bool active;
  const _TokenPill({required this.active});
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: (active ? Colors.green : Colors.red).withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? '● Aktif' : '● Expired',
      style: TextStyle(
        color: active ? Colors.green : Colors.red,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _StockCard extends StatelessWidget {
  final int stockAvailable, sold, stockRedeem;
  final num price;
  final bool expired;
  final VoidCallback? onSync;
  const _StockCard({
    required this.stockAvailable,
    required this.sold,
    required this.stockRedeem,
    required this.price,
    required this.expired,
    required this.onSync,
    this.loading = false,
  });
  final bool loading;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stok Pangkalan (MyPertamina Sync)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$stockAvailable Tabung${expired ? ' (Sesi Habis)' : ''}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Total Terjual: $sold'),
              Text('Kuota Penebusan: $stockRedeem'),
              Text('Harga: Rp ${price.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync),
            label: const Text('Sinkronkan Stok API'),
          ),
        ],
      ),
    ),
  );
}

class _ControlCard extends StatelessWidget {
  final TransactionQueueProvider queue;
  final int total, safe;
  final VoidCallback onStart, onPause, onReset;
  const _ControlCard({
    required this.queue,
    required this.total,
    required this.safe,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });
  @override
  Widget build(BuildContext c) {
    final progress = queue.progress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pusat Kontrol Otomatisasi',
              style: Theme.of(c).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('Progres: ${queue.currentIndex} / $total Tabung Diproses'),
            const SizedBox(height: 8),
            Text(
              'Antrean Siap: $total Tabung ($safe Zona Aman, ${total - safe} Mode Kepepet)',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: queue.isRunning ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Mulai Otomatisasi'),
                ),
                OutlinedButton.icon(
                  onPressed: queue.isRunning ? onPause : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Jeda'),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.stop),
                  label: const Text('Hentikan / Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final SmartQueueEntry entry;
  final int index;
  const _QueueCard({required this.entry, required this.index});
  @override
  Widget build(BuildContext c) {
    final p = entry.pelanggan;
    final last = p.lastTransactedAt;
    final date = last == null
        ? 'Belum ada'
        : DateFormat('dd MMM yyyy').format(last);
    final name = p.lastTransactionPangkalan ?? 'Pangkalan sebelumnya';
    final status = entry.aman ? 'ZONA AMAN' : 'MODE KEPEPET';
    final color = entry.aman ? Colors.green : Colors.amber.shade800;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Wrap(
          spacing: 6,
          children: [
            Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
            Chip(
              label: Text(p.displayKategori),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Text(
          'NIK: ${p.nik}\n🟢 Sisa Kuota: ${p.sisaKuotaHarian} Tabung\nTerakhir: $date • $name',
        ),
        trailing: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
