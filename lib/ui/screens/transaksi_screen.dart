import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/log_transaksi.dart';
import '../../models/pelanggan_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/mypertamina_api_service.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});
  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _firebase = FirebaseService();
  List<LogTransaksi> _logs = [];
  List<Pelanggan> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.registrationId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _firebase.getAllLogTransaksi(auth.registrationId),
        _firebase.getAllPelanggan(auth.registrationId),
      ]);
      if (mounted) {
        setState(() {
          _logs = values[0] as List<LogTransaksi>;
          _customers = values[1] as List<Pelanggan>;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncQuota(Pelanggan customer) async {
    final auth = context.read<AuthProvider>();
    if (customer.encryptedFamilyId == null ||
        customer.encryptedFamilyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Family ID belum tersedia; lakukan verifikasi pelanggan.',
          ),
        ),
      );
      return;
    }
    try {
      final quota = await MyPertaminaApiService(auth.apiClient).checkQuota(
        customer.nik,
        customer.encryptedFamilyId!,
        customer.kategori,
      );
      await _firebase.updatePelangganQuota(
        nik: customer.nik,
        registrationId: auth.registrationId,
        encryptedFamilyId: customer.encryptedFamilyId!,
        daily: quota.dailyPerSegment.toInt(),
        monthly: quota.monthly.toInt(),
        family: quota.familyQuota.toInt(),
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal sinkron kuota: $e')));
    }
  }

  Widget _customerTile(Pelanggan p) => Card(
    child: ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(p.nama),
      subtitle: Text('${p.nik} • ${p.displayKategori}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${p.sisaKuotaHarian} tabung',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => _syncQuota(p),
            icon: const Icon(Icons.sync, size: 18),
          ),
        ],
      ),
    ),
  );

  Widget _logTile(LogTransaksi log) => Card(
    child: ListTile(
      leading: Icon(
        log.isSuccess ? Icons.check_circle : Icons.error,
        color: log.isSuccess ? Colors.green : Colors.red,
      ),
      title: Text('${log.nama} • ${log.jumlahTabung} tabung'),
      subtitle: Text(
        '${log.nik}\n${log.timestamp} • ${log.status}${log.refNo == null ? '' : '\nStruk: ${log.refNo}'}',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text(
        'Sisa Kuota Real-time',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (_customers.isEmpty)
        const Card(child: ListTile(title: Text('Belum ada pelanggan'))),
      ..._customers.map(_customerTile),
      const SizedBox(height: 20),
      Text('Riwayat Transaksi', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (_logs.isEmpty)
        const Card(child: ListTile(title: Text('Belum ada riwayat transaksi'))),
      ..._logs.map(_logTile),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi & Kuota'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
            ),
    );
  }
}
