import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/log_transaksi.dart';
import '../../models/mypertamina_models.dart';
import '../../models/pelanggan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_queue_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/pelanggan_model.dart';
import '../../services/automation_service.dart';
import '../../services/api_client.dart';
import '../../services/firebase_service.dart';
import '../../services/mypertamina_api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_components.dart';

class TransaksiScreen extends StatefulWidget {
  final VoidCallback? onOpenWebView;
  const TransaksiScreen({super.key, this.onOpenWebView});
  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen>
    with SingleTickerProviderStateMixin {
  final _firebase = FirebaseService();
  final _automation = AutomationService();
  late final TabController _tabController;

  List<SmartQueueEntry> _queueEntries = [];
  List<LogTransaksi> _logs = [];
  Map<String, Pelanggan> _customerMap = {};

  bool _loadingQueue = true;
  bool _loadingLogs = true;
  bool _tokenExpired = false;
  String? _errorMessage;
  String _myPertaminaSearch = '';
  final _myPertaminaSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQueue();
      _loadLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _myPertaminaSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    final auth = context.read<AuthProvider>();
    if (auth.registrationId.isEmpty) {
      if (mounted) setState(() => _loadingQueue = false);
      return;
    }
    if (mounted) setState(() => _loadingQueue = true);
    try {
      final result = await _automation.generateSmartQueue(
        targetStock: auth.stockAvailable,
        registrationId: auth.registrationId,
      );
      if (!mounted) return;

      final queue = context.read<TransactionQueueProvider>();
      queue.configure(
        apiClient: auth.apiClient,
        registrationId: auth.registrationId,
        pangkalanName: auth.storeName,
        stockAvailable: auth.stockAvailable,
        sold: auth.sold,
        onQueueCompleted: () async {
          await _loadLogs();
          if (mounted) {
            auth.fetchProductAndStockFromApi();
          }
        },
      );
      queue.setQueue(result.entries.map((e) => e.pelanggan).toList());

      setState(() => _queueEntries = result.entries);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat antrean: $e');
    } finally {
      if (mounted) setState(() => _loadingQueue = false);
    }
  }

  Future<void> _loadLogs() async {
    final auth = context.read<AuthProvider>();
    if (auth.registrationId.isEmpty) {
      if (mounted) setState(() => _loadingLogs = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loadingLogs = true;
        _errorMessage = null;
        _tokenExpired = false;
      });
    }
    try {
      final customersFuture = _firebase.getAllPelanggan(auth.registrationId);
      final logsFuture = _firebase.getAllLogTransaksi(auth.registrationId);

      List<LogTransaksi> logs = [];
      List<Pelanggan> customers = [];
      try {
        logs = await logsFuture;
      } catch (e) {
        _errorMessage = 'Riwayat lokal gagal dimuat: $e';
      }
      try {
        customers = await customersFuture;
      } catch (e) {
        _errorMessage ??= 'Data pelanggan gagal dimuat: $e';
      }
      try {
        await context
            .read<TransactionProvider>()
            .syncAndSaveMyPertaminaTransactionsThisYear(customers);
        final report = await MyPertaminaApiService(
          auth.apiClient,
        ).fetchReport();
        final apiLogs = report.map(_reportToLog).toList();
        final existingIds = logs.map((l) => l.id).toSet();
        for (final apiLog in apiLogs) {
          if (apiLog.id.isNotEmpty && !existingIds.contains(apiLog.id)) {
            logs.add(apiLog);
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          _tokenExpired = true;
        } else {
          _errorMessage ??= 'Laporan MyPertamina gagal dimuat.';
        }
      } catch (e) {
        _errorMessage ??= 'Laporan MyPertamina gagal dimuat: $e';
      }

      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final cMap = <String, Pelanggan>{};
      for (final c in customers) {
        cMap[c.nik] = c;
      }

      if (mounted) {
        setState(() {
          _logs = logs;
          _customerMap = cMap;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat transaksi: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  LogTransaksi _reportToLog(TransactionReceiptModel report) => LogTransaksi(
    id: report.transactionId,
    nik: report.nik,
    nama: report.customerName,
    kategori: report.category,
    jumlahTabung: report.quantity,
    status: report.status.isEmpty ? 'BERHASIL' : report.status,
    refNo: report.transactionUniqueKey.isEmpty
        ? null
        : report.transactionUniqueKey,
    registrationId: context.read<AuthProvider>().registrationId,
    timestamp: DateTime.tryParse(report.createdAt) ?? DateTime.now(),
  );

  void _startQueue() {
    final queue = context.read<TransactionQueueProvider>();
    if (queue.totalQueue == 0) {
      _showSnack('Antrean kosong. Muat ulang data pelanggan terlebih dahulu.');
      return;
    }
    queue.executeQueue();
  }

  void _resumeQueue() {
    final queue = context.read<TransactionQueueProvider>();
    _automation.resume();
    if (queue.status == QueueStatus.paused) {
      queue.resumeQueue();
    } else if (queue.status == QueueStatus.tokenExpired) {
      queue.resumeAfterTokenRefresh();
    } else {
      _showSnack('Tidak ada antrean yang dijeda.');
    }
  }

  void _pauseQueue() {
    final queue = context.read<TransactionQueueProvider>();
    if (queue.isRunning) {
      _automation.pause();
      queue.pauseQueue();
      _showSnack('Antrean dijeda.');
    }
  }

  Future<void> _retryFailed() async {
    final auth = context.read<AuthProvider>();
    final queue = context.read<TransactionQueueProvider>();
    // Use AutomationService to extract failed items and re-queue them
    final failedCustomers = await _automation.retryFailed(auth.registrationId);
    if (failedCustomers.isEmpty) {
      _showSnack('Tidak ada transaksi gagal untuk di-retry.');
      return;
    }
    queue.setQueue(failedCustomers);
    queue.executeQueue();
    await _loadLogs();
    if (mounted)
      _showSnack(
        '${failedCustomers.length} transaksi gagal dimasukkan ke antrean.',
      );
  }

  void _showTopNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer2<AuthProvider, TransactionQueueProvider>(
      builder: (context, auth, txQueue, _) {
        return Scaffold(
          appBar: GlassAppBar(
            title: 'Pusat Otomatisasi',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Muat Ulang',
                onPressed: () {
                  _loadQueue();
                  _loadLogs();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildControlPanel(context, txQueue, cs),
              TabBar(
                controller: _tabController,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: cs.primary,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.queue_play_next, size: 18),
                    text: 'Antrean',
                  ),
                  Tab(
                    icon: const Icon(Icons.history, size: 18),
                    text: 'Log Riwayat',
                  ),
                  Tab(
                    icon: const Icon(Icons.cloud_sync, size: 18),
                    text: 'Riwayat Transaksi',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQueueTab(context, txQueue),
                    _buildLogTab(context, txQueue),
                    _buildMyPertaminaHistory(
                      context,
                      context.watch<TransactionProvider>(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(
    BuildContext context,
    TransactionQueueProvider txQueue,
    ColorScheme cs,
  ) {
    final processed = txQueue.currentIndex;
    final total = txQueue.totalQueue;
    final success = txQueue.successCount;
    final fail = txQueue.failCount;
    final isRunning = txQueue.isRunning;
    final isPaused = txQueue.status == QueueStatus.paused;
    final isIdle =
        txQueue.status == QueueStatus.idle ||
        txQueue.status == QueueStatus.completed;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRunning
                    ? Icons.play_circle_fill
                    : isPaused
                    ? Icons.pause_circle_filled
                    : Icons.radio_button_checked,
                size: 18,
                color: isRunning
                    ? cs.primary
                    : isPaused
                    ? Colors.orange
                    : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progres: $processed / $total Diproses  •  '
                  '$success Sukses  •  $fail Gagal',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: txQueue.progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                fail > 0 && success == 0 ? cs.error : cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _controlButton(
                icon: Icons.play_arrow_rounded,
                label: 'Mulai',
                color: cs.primary,
                onPressed: isIdle ? _startQueue : null,
              ),
              _controlButton(
                icon: Icons.play_circle_outline,
                label: 'Lanjutkan',
                color: Colors.teal,
                onPressed:
                    isPaused || txQueue.status == QueueStatus.tokenExpired
                    ? _resumeQueue
                    : null,
              ),
              _controlButton(
                icon: Icons.pause_rounded,
                label: 'Jeda',
                color: Colors.orange,
                onPressed: isRunning ? _pauseQueue : null,
              ),
              _controlButton(
                icon: Icons.replay_rounded,
                label: 'Retry Gagal',
                color: cs.error,
                onPressed: !isRunning && fail > 0 ? _retryFailed : null,
              ),
            ],
          ),
          if (txQueue.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              txQueue.lastError!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ],
          if (txQueue.needsTokenRefresh) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lock_clock, size: 16, color: cs.error),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Token expired. Login ulang lalu tekan Lanjutkan.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: widget.onOpenWebView,
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 38,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: onPressed != null ? .9 : .3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueTab(
    BuildContext context,
    TransactionQueueProvider txQueue,
  ) {
    if (_loadingQueue) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = _queueEntries;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Antrean kosong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Pastikan token valid dan data pelanggan tersedia.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadQueue,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Muat Ulang Antrean'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          return _buildQueueCard(context, entries[index], index, txQueue);
        },
      ),
    );
  }

  Widget _buildQueueCard(
    BuildContext context,
    SmartQueueEntry entry,
    int index,
    TransactionQueueProvider txQueue,
  ) {
    final p = entry.pelanggan;
    final cs = Theme.of(context).colorScheme;
    final isProcessed = index < txQueue.currentIndex;
    final isCurrentlyProcessing =
        index == txQueue.currentIndex && txQueue.isRunning;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;
    if (isProcessed) {
      final result = txQueue.results.length > index
          ? txQueue.results[index]
          : null;
      if (result != null && result.isSuccess) {
        statusLabel = 'Selesai';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (result != null) {
        statusLabel = 'Gagal';
        statusColor = cs.error;
        statusIcon = Icons.error;
      } else {
        statusLabel = 'Dilewati';
        statusColor = Colors.grey;
        statusIcon = Icons.skip_next;
      }
    } else if (isCurrentlyProcessing) {
      statusLabel = 'Diproses...';
      statusColor = cs.primary;
      statusIcon = Icons.sync;
    } else {
      statusLabel = 'Menunggu';
      statusColor = cs.onSurfaceVariant;
      statusIcon = Icons.hourglass_empty;
    }

    final priorityColor = entry.aman ? Colors.green : Colors.amber.shade800;
    final priorityLabel = entry.aman ? '🟢 Zona Aman' : '🟡 Kepepet';
    final priorityTooltip = entry.aman
        ? '>= 2 hari sejak terakhir'
        : '< 2 hari sejak terakhir';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentlyProcessing
                ? cs.primary
                : cs.surfaceContainerHighest,
            child: isCurrentlyProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      p.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.displayKategori == 'UMKM'
                            ? Colors.indigo.withValues(alpha: .12)
                            : Colors.teal.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.displayKategori,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.displayKategori == 'UMKM'
                              ? Colors.indigo
                              : Colors.teal.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'NIK: ${p.nik}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Tooltip(
                      message: priorityTooltip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priorityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab(BuildContext context, TransactionQueueProvider txQueue) {
    if (_loadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    final banners = <Widget>[];
    if (_tokenExpired) {
      banners.add(
        GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sesi token berakhir. Login ulang untuk memuat laporan API.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenWebView,
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      banners.add(
        GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_logs.isEmpty && banners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat transaksi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: banners.length + _logs.length,
        itemBuilder: (context, index) {
          if (index < banners.length) return banners[index];
          final logIndex = index - banners.length;
          return _buildLogCard(context, _logs[logIndex], txQueue);
        },
      ),
    );
  }

  Widget _buildMyPertaminaHistory(
    BuildContext context,
    TransactionProvider provider,
  ) {
    final query = _myPertaminaSearch.trim().toUpperCase();
    final items = provider.transactions
        .where(
          (item) =>
              query.isEmpty ||
              item.name.toUpperCase().contains(query) ||
              item.fullNik.contains(query) ||
              item.maskedNik.contains(query),
        )
        .toList();
    final uniqueCustomers = items
        .map((item) => item.fullNik.isNotEmpty ? item.fullNik : item.maskedNik)
        .toSet()
        .length;
    final totalTubes = items.fold<int>(0, (sum, item) => sum + item.total);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryMetric(
                  context,
                  'Transaksi Tahun Ini',
                  '${items.length}',
                ),
                _summaryMetric(context, 'Tabung Terjual', '$totalTubes'),
                _summaryMetric(context, 'Pelanggan Unik', '$uniqueCustomers'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: FilledButton.icon(
            onPressed: provider.isLoading
                ? null
                : () async {
                    final auth = context.read<AuthProvider>();
                    if (auth.token == null || auth.token!.isEmpty) {
                      _showTopNotification(
                        'Silakan login ke Portal MyPertamina terlebih dahulu di Halaman Portal!',
                        isError: true,
                      );
                      return;
                    }
                    debugPrint('▶️ [MYPTM UI] Tombol tarik transaksi ditekan');
                    try {
                      final customers = await _firebase.getAllPelanggan(
                        auth.registrationId,
                      );
                      if (!mounted) return;
                      final count = await provider
                          .syncAndSaveMyPertaminaTransactionsThisYear(
                            customers,
                          );
                      if (!mounted) return;
                      _showTopNotification(
                        'Berhasil menarik $count data transaksi MyPertamina tahun ini!',
                      );
                    } on DioException catch (e) {
                      if (!mounted) return;
                      final message = switch (e.response?.statusCode) {
                        401 || 403 =>
                          'Sesi login MyPertamina habis. Silakan login ulang di Halaman Portal.',
                        406 =>
                          'Server menolak permintaan (Rentang tanggal/Header). Mencoba penarikan ulang per bulan...',
                        _ => ApiClient.parseDioError(e),
                      };
                      _showTopNotification(message, isError: true);
                    } catch (e, stackTrace) {
                      debugPrint('❌ [MYPTM UI ERROR]: $e');
                      debugPrint('📌 [MYPTM UI STACKTRACE]: $stackTrace');
                      if (!mounted) return;
                      _showTopNotification(
                        'Gagal mendapatkan transaksi: ${e.toString()}',
                        isError: true,
                      );
                    }
                  },
            icon: const Icon(Icons.sync),
            label: const Text('Refresh / Tarik Data MyPertamina Terbaru'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _myPertaminaSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari nama atau NIK',
            ),
            onChanged: (value) => setState(() => _myPertaminaSearch = value),
          ),
        ),
        if (provider.isLoading)
          Column(
            children: [
              const LinearProgressIndicator(),
              if (provider.monthlyTotal > 0)
                Text(
                  'Menarik bulan ${provider.monthlyProgress}/${provider.monthlyTotal}...',
                ),
            ],
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildMyPertaminaCard(context, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _summaryMetric(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMyPertaminaCard(
    BuildContext context,
    EnrichedMyPertaminaTransaction item,
  ) {
    final date = item.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt!.toLocal());
    final nik = item.isEnriched ? item.fullNik : item.maskedNik;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('NIK: $nik'),
              Chip(
                label: Text(
                  item.isEnriched
                      ? 'Terverifikasi Master'
                      : 'Belum Ada di Master',
                ),
                backgroundColor: item.isEnriched
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
              ),
              if (!item.isEnriched)
                TextButton(
                  onPressed: () {},
                  child: const Text('+ Tambah Pelanggan'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${item.category} • ${item.total} tabung LPG 3kg'),
        ],
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    LogTransaksi log,
    TransactionQueueProvider txQueue,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSuccess = log.isSuccess;
    final statusColor = isSuccess ? Colors.green : cs.error;
    final statusLabel = isSuccess ? '🟢 SUKSES' : '🔴 GAGAL';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          log.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Pelanggan.normalizeKategori(log.kategori) ==
                                    'UMKM'
                                ? Colors.indigo.withValues(alpha: .12)
                                : Colors.teal.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            Pelanggan.normalizeKategori(log.kategori),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  Pelanggan.normalizeKategori(log.kategori) ==
                                      'UMKM'
                                  ? Colors.indigo
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIK: ${log.nik}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLogDetails(context, log, cs, isSuccess),
        ],
      ),
    );
  }

  Widget _buildLogDetails(
    BuildContext context,
    LogTransaksi log,
    ColorScheme cs,
    bool isSuccess,
  ) {
    final customer = _customerMap[log.nik];
    final sisaKuota = customer?.sisaKuotaHarian;
    final formattedTime = DateFormat(
      'dd MMM yyyy, HH:mm:ss',
    ).format(log.timestamp);

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sisaKuota != null)
            Row(
              children: [
                Icon(
                  Icons.local_gas_station,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sisa Kuota: $sisaKuota Tabung',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${log.jumlahTabung} tabung',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (log.refNo != null && log.refNo!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.receipt_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Struk: ${log.refNo}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (!isSuccess &&
              log.pesanError != null &&
              log.pesanError!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                log.pesanError!,
                style: TextStyle(fontSize: 11, color: cs.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
