import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/log_transaksi.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_queue_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/excel_service.dart';
import '../../services/batch_verification_service.dart';
import '../../services/mypertamina_api_service.dart';
import 'settings_screen.dart';
import '../widgets/token_status_widget.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/log_transaksi_table.dart';
import '../widgets/queue_progress_widget.dart';
import '../widgets/action_buttons_widget.dart';
import '../widgets/pelanggan_picker_dialog.dart';
import 'webview_screen.dart';
import '../widgets/glass_components.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenWebView;
  const DashboardScreen({super.key, this.onOpenWebView});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<LogTransaksi> _logs = [];
  String _filterStatus = 'SEMUA';
  bool _isLoadingLogs = false;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _isSyncing = false;

  bool get isImporting => _isImporting;
  bool get isExporting => _isExporting;
  bool get isSyncing => _isSyncing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadLogs());
  }

  Future<void> loadLogs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.registrationId.isEmpty) return;
    setState(() => _isLoadingLogs = true);
    try {
      _logs = await _firebaseService.getAllLogTransaksi(auth.registrationId);
    } catch (_) {}
    setState(() => _isLoadingLogs = false);
  }

  List<LogTransaksi> get filteredLogs {
    if (_filterStatus == 'SEMUA') return _logs;
    return _logs.where((l) => l.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, TransactionQueueProvider>(
      builder: (context, auth, txQueue, _) {
        return Scaffold(
          appBar: GlassAppBar(
            title: auth.storeName.isEmpty ? 'Pangkalan Cerdas' : auth.storeName,
            actions: [
              IconButton(
                icon: const Icon(Icons.language),
                tooltip: 'Buka WebView',
                onPressed: () => _openWebView(context),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Pengaturan',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: loadLogs,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: loadLogs,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHeaderWidget(
                    storeName: auth.storeName,
                    registrationId: auth.registrationId,
                    stockAvailable: auth.stockAvailable,
                  ),
                  const SizedBox(height: 10),
                  TokenStatusWidget(isTokenAvailable: auth.isTokenAvailable),
                  const SizedBox(height: 10),
                  QueueProgressWidget(txQueue: txQueue),
                  const SizedBox(height: 10),
                  ActionButtonsWidget(dashboardState: this),
                  const SizedBox(height: 14),
                  _buildFilterChips(),
                  const SizedBox(height: 8),
                  _isLoadingLogs
                      ? const Center(child: CircularProgressIndicator())
                      : LogTransaksiTable(
                          logs: filteredLogs,
                          onRetrySingle: (log) =>
                              retrySingle(context, txQueue, log),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        ...['SEMUA', 'BERHASIL', 'GAGAL'].map((f) {
          final isActive = _filterStatus == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(f, style: const TextStyle(fontSize: 12)),
              selected: isActive,
              selectedColor: f == 'BERHASIL'
                  ? Colors.green.shade200
                  : f == 'GAGAL'
                  ? Colors.red.shade200
                  : Colors.blue.shade200,
              onSelected: (_) => setState(() => _filterStatus = f),
            ),
          );
        }),
      ],
    );
  }

  void _openWebView(BuildContext context) {
    if (widget.onOpenWebView != null) {
      widget.onOpenWebView!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      ).then((_) => loadLogs());
    }
  }

  void pickCustomerForTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PelangganPickerDialog(
        onSelected: (pelanggan) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final txQueue = Provider.of<TransactionQueueProvider>(
            context,
            listen: false,
          );
          if (auth.registrationId.isEmpty) {
            _showSnack('Silakan login WebView terlebih dahulu');
            return;
          }
          txQueue.configure(
            apiClient: auth.apiClient,
            registrationId: auth.registrationId,
          );
          txQueue.addToQueue(pelanggan);
          _showSnack('${pelanggan.nama} ditambahkan ke antrean transaksi');
        },
      ),
    );
  }

  Future<void> importPelanggan() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final txQueue = Provider.of<TransactionQueueProvider>(
      context,
      listen: false,
    );
    if (auth.registrationId.isEmpty) {
      _showSnack('Silakan login WebView terlebih dahulu');
      return;
    }
    setState(() => _isImporting = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) {
        _showSnack('Pemilihan file dibatalkan');
        return;
      }
      final pelangganList = await ExcelService.importPelanggan(
        filePath: path,
        registrationId: auth.registrationId,
      );
      if (pelangganList.isEmpty) {
        _showSnack('File kosong atau format tidak sesuai');
        return;
      }
      final verification = BatchVerificationService(
        api: MyPertaminaApiService(auth.apiClient),
        firebase: _firebaseService,
      );
      final syncResult = await verification.batchVerifyAndSyncWithMyPertamina(
        customers: pelangganList,
        registrationId: auth.registrationId,
      );
      await _firebaseService.savePelangganBatch(
        pelangganList,
        auth.registrationId,
      );
      txQueue.configure(
        apiClient: auth.apiClient,
        registrationId: auth.registrationId,
      );
      txQueue.setQueue(pelangganList);
      _showSnack(
        '${pelangganList.length} pelanggan diimpor; ${syncResult.verified} terverifikasi, ${syncResult.failed} gagal',
      );
    } catch (e) {
      _showSnack('Error import: $e');
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> executeQueue() async {
    final txQueue = Provider.of<TransactionQueueProvider>(
      context,
      listen: false,
    );
    if (txQueue.totalQueue == 0) {
      _showSnack('Antrean kosong. Import dulu.');
      return;
    }
    await txQueue.executeQueue();
    await loadLogs();
    _showSnack(
      'Selesai: ${txQueue.successCount} berhasil, ${txQueue.failCount} gagal',
    );
  }

  Future<void> retryAll() async {
    final txQueue = Provider.of<TransactionQueueProvider>(
      context,
      listen: false,
    );
    await txQueue.retryAllFailed();
    await loadLogs();
    _showSnack('Retry selesai');
  }

  Future<void> retrySingle(
    BuildContext ctx,
    TransactionQueueProvider txQueue,
    LogTransaksi log,
  ) async {
    await txQueue.retrySingle(log);
    await loadLogs();
    _showSnack('Retry ${log.nik} selesai');
  }

  Future<void> exportExcel() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.registrationId.isEmpty) {
      _showSnack('Login dulu');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final logs = await _firebaseService.getAllLogTransaksi(
        auth.registrationId,
      );
      final path = await ExcelService.exportLogTransaksi(
        logs: logs,
        storeName: auth.storeName,
      );
      _showSnack('Diekspor ke: $path');
    } catch (e) {
      _showSnack('Error ekspor: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> syncWebHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isTokenAvailable) {
      _showSnack('Token tidak tersedia');
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final now = DateTime.now();
      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(now);
      await auth.apiClient.fetchTransactionReport(
        startDate: startDate,
        endDate: endDate,
      );
      _showSnack('Sync riwayat web berhasil');
    } catch (e) {
      _showSnack('Error sync: $e');
    } finally {
      setState(() => _isSyncing = false);
      await loadLogs();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
