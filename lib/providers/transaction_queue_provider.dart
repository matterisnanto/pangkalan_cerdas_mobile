import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/pelanggan.dart';
import '../models/log_transaksi.dart';
import '../services/api_client.dart';
import '../services/firebase_service.dart';
import '../services/quota_rule_engine.dart';
import '../services/notification_service.dart';

enum QueueStatus { idle, running, paused, tokenExpired, completed }

class TransactionQueueProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  ApiClient? _apiClient;
  String _registrationId = '';

  List<Pelanggan> _queue = [];
  List<LogTransaksi> _results = [];
  List<LogTransaksi> _todayLogs = [];

  QueueStatus _status = QueueStatus.idle;
  int _currentIndex = 0;
  String? _lastError;
  bool _needsTokenRefresh = false;
  int _delaySeconds = 3;
  String _pangkalanName = '';
  int _stockAvailable = 0;
  int _sold = 0;

  List<Pelanggan> get queue => _queue;
  List<LogTransaksi> get results => _results;
  QueueStatus get status => _status;
  int get currentIndex => _currentIndex;
  int get totalQueue => _queue.length;
  int get successCount => _results.where((r) => r.status == 'BERHASIL').length;
  int get failCount => _results.where((r) => r.status == 'GAGAL').length;
  String? get lastError => _lastError;
  bool get needsTokenRefresh => _needsTokenRefresh;
  bool get isRunning => _status == QueueStatus.running;
  double get progress => _queue.isEmpty ? 0 : _currentIndex / _queue.length;

  void configure({
    required ApiClient apiClient,
    required String registrationId,
    int delaySeconds = 3,
    String pangkalanName = '',
    int stockAvailable = 0,
    int sold = 0,
  }) {
    _apiClient = apiClient;
    _registrationId = registrationId;
    _pangkalanName = pangkalanName;
    _stockAvailable = stockAvailable;
    _sold = sold;
    _delaySeconds = delaySeconds.clamp(2, 5);
  }

  Future<void> loadTodayLogs() async {
    if (_registrationId.isEmpty) return;
    _todayLogs = await _firebaseService.getLogTransaksiHariIni(_registrationId);
  }

  void setQueue(List<Pelanggan> customers) {
    _queue = List.from(customers);
    _results = [];
    _currentIndex = 0;
    _status = QueueStatus.idle;
    _lastError = null;
    _needsTokenRefresh = false;
    notifyListeners();
  }

  void addToQueue(Pelanggan customer) {
    _queue.add(customer);
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    _results = [];
    _currentIndex = 0;
    _status = QueueStatus.idle;
    notifyListeners();
  }

  Future<void> executeQueue() async {
    if (_apiClient == null || _registrationId.isEmpty) {
      _lastError = 'API Client atau registrationId belum dikonfigurasi';
      notifyListeners();
      return;
    }
    _status = QueueStatus.running;
    _needsTokenRefresh = false;
    notifyListeners();
    await loadTodayLogs();

    for (int i = _currentIndex; i < _queue.length; i++) {
      if (_status != QueueStatus.running) break;
      _currentIndex = i;
      notifyListeners();
      await _processTransaction(_queue[i]);
      try {
        await NotificationService.showBatchProgressNotification(
          current: i + 1,
          total: _queue.length,
          success: successCount,
          fail: failCount,
        );
      } catch (_) {}
      if (i < _queue.length - 1 && _status == QueueStatus.running) {
        await Future.delayed(Duration(seconds: _delaySeconds));
      }
    }
    if (_status == QueueStatus.running) {
      _currentIndex = _queue.length;
      _status = QueueStatus.completed;
    }
    notifyListeners();
  }

  Future<void> _processTransaction(Pelanggan pelanggan) async {
    final quotaResult = QuotaRuleEngine.validateLocalQuota(
      nik: pelanggan.nik,
      kategori: pelanggan.kategori,
      jumlahTabungAkanDibeli: 1,
      transaksiHariIni: _todayLogs,
    );

    if (!quotaResult.isValid) {
      final failLog = LogTransaksi(
        id: '',
        nik: pelanggan.nik,
        nama: pelanggan.nama,
        kategori: pelanggan.kategori,
        jumlahTabung: 1,
        status: 'GAGAL',
        pesanError: quotaResult.errorMessage,
        registrationId: _registrationId,
        timestamp: DateTime.now(),
      );
      await _firebaseService.saveLogTransaksi(failLog);
      _results.add(failLog);
      _todayLogs.add(failLog);
      notifyListeners();
      return;
    }

    try {
      final response = await _callVerifyWithRetry(pelanggan.nik);
      final data = response.data;
      final refNo = data is Map<String, dynamic>
          ? (data['data']?['refNo']?.toString() ??
                data['refNo']?.toString() ??
                '-')
          : '-';
      final successLog = LogTransaksi(
        id: '',
        nik: pelanggan.nik,
        nama: pelanggan.nama,
        kategori: pelanggan.kategori,
        jumlahTabung: 1,
        status: 'BERHASIL',
        refNo: refNo,
        registrationId: _registrationId,
        timestamp: DateTime.now(),
      );
      await _firebaseService.saveLogTransaksi(successLog);
      await _firebaseService.updatePelangganAfterTransaction(
        registrationId: _registrationId,
        nik: pelanggan.nik,
        daily: (pelanggan.sisaKuotaHarian - 1).clamp(0, 999999),
        monthly: (pelanggan.sisaKuotaBulanan - 1).clamp(0, 999999),
        lastTransactedAt: DateTime.now(),
        pangkalanName: _pangkalanName,
      );
      _stockAvailable = (_stockAvailable - 1).clamp(0, 999999);
      _sold += 1;
      await _firebaseService.updatePangkalanAfterTransaction(
        registrationId: _registrationId,
        stockAvailable: _stockAvailable,
        sold: _sold,
      );
      _results.add(successLog);
      _todayLogs.add(successLog);
    } on DioException catch (e) {
      if (ApiClient.isTokenExpired(e)) {
        _status = QueueStatus.tokenExpired;
        _needsTokenRefresh = true;
        _lastError =
            'Token kadaluarsa. Silakan refresh WebView lalu lanjutkan.';
        try {
          await NotificationService.showTokenExpiredNotification();
        } catch (_) {}
      }
      final failLog = LogTransaksi(
        id: '',
        nik: pelanggan.nik,
        nama: pelanggan.nama,
        kategori: pelanggan.kategori,
        jumlahTabung: 1,
        status: 'GAGAL',
        pesanError: ApiClient.parseDioError(e),
        registrationId: _registrationId,
        timestamp: DateTime.now(),
      );
      await _firebaseService.saveLogTransaksi(failLog);
      _results.add(failLog);
      _todayLogs.add(failLog);
    } catch (e) {
      final failLog = LogTransaksi(
        id: '',
        nik: pelanggan.nik,
        nama: pelanggan.nama,
        kategori: pelanggan.kategori,
        jumlahTabung: 1,
        status: 'GAGAL',
        pesanError: e.toString(),
        registrationId: _registrationId,
        timestamp: DateTime.now(),
      );
      await _firebaseService.saveLogTransaksi(failLog);
      _results.add(failLog);
      _todayLogs.add(failLog);
    }
    notifyListeners();
  }

  Future<Response> _callVerifyWithRetry(
    String nik, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await _apiClient!.verifyNikTransaction(nik);
      } on DioException catch (e) {
        if (ApiClient.isTokenExpired(e)) rethrow;
        final statusCode = e.response?.statusCode ?? 0;
        final isRetryable =
            statusCode >= 500 ||
            statusCode == 429 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        attempt++;
        if (!isRetryable || attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  Future<void> retrySingle(LogTransaksi failedLog) async {
    if (_apiClient == null || _registrationId.isEmpty) return;
    await loadTodayLogs();
    final pelanggan = Pelanggan(
      nik: failedLog.nik,
      nama: failedLog.nama,
      kategori: failedLog.kategori,
      registrationId: _registrationId,
    );
    _status = QueueStatus.running;
    notifyListeners();
    await _processTransaction(pelanggan);
    _status = QueueStatus.completed;
    notifyListeners();
  }

  Future<void> retryAllFailed() async {
    if (_apiClient == null || _registrationId.isEmpty) return;
    final failedLogs = await _firebaseService.getLogGagal(_registrationId);
    if (failedLogs.isEmpty) return;
    final customers = failedLogs
        .map(
          (l) => Pelanggan(
            nik: l.nik,
            nama: l.nama,
            kategori: l.kategori,
            registrationId: _registrationId,
          ),
        )
        .toList();
    setQueue(customers);
    await executeQueue();
  }

  Future<void> resumeAfterTokenRefresh() async {
    if (_status == QueueStatus.tokenExpired) {
      _needsTokenRefresh = false;
      _status = QueueStatus.running;
      _currentIndex++;
      notifyListeners();
      await executeQueue();
    }
  }

  void pauseQueue() {
    if (_status == QueueStatus.running) {
      _status = QueueStatus.paused;
      notifyListeners();
    }
  }

  /// Stops safely without deleting the current results. A later Start resumes
  /// from the current item, while Reset clears the queue completely.
  void stopQueue() {
    if (_status == QueueStatus.running || _status == QueueStatus.paused) {
      _status = QueueStatus.idle;
      notifyListeners();
    }
  }

  void resumeQueue() {
    if (_status == QueueStatus.paused) {
      executeQueue();
    }
  }

  void reset() {
    _queue = [];
    _results = [];
    _currentIndex = 0;
    _status = QueueStatus.idle;
    _lastError = null;
    _needsTokenRefresh = false;
    notifyListeners();
  }
}
