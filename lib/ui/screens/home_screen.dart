import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_queue_provider.dart';
import '../../services/automation_service.dart';
import '../widgets/theme_toggle_button.dart';

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
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final auth = context.read<AuthProvider>();
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
      sold: auth.pangkalan?.sold ?? 0,
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
          auth.storeName.isEmpty ? 'Pangkalan Cerdas' : auth.storeName,
        ),
        actions: [
          _TokenPill(active: auth.isTokenValid || auth.isTokenAvailable),
          const ThemeToggleButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
