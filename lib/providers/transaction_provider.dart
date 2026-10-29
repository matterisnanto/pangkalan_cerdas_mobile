import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../models/pelanggan_model.dart';
import '../services/firebase_service.dart';
import '../services/mypertamina_api_service.dart';
import '../services/local_database_service.dart';
import 'auth_provider.dart';

class EnrichedMyPertaminaTransaction {
  final String name;
  final String maskedNik;
  final String fullNik;
  final String category;
  final int total;
  final DateTime? createdAt;
  final bool isEnriched;
  final bool hasMasterData;
  final String? customerPhoto;

  const EnrichedMyPertaminaTransaction({
    required this.name,
    required this.maskedNik,
    required this.fullNik,
    required this.category,
    required this.total,
    required this.createdAt,
    required this.isEnriched,
    required this.hasMasterData,
    this.customerPhoto,
  });
}

class TransactionProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  final MyPertaminaApiService _api;
  final LocalDatabaseService _database = LocalDatabaseService.instance;
  List<EnrichedMyPertaminaTransaction> transactions = [];
  bool isLoading = false;
  String? error;
  int monthlyProgress = 0;
  int monthlyTotal = 0;
  bool uniqueCustomersOnly = false;
  String masterStatusFilter = 'all';
  String lpgCategoryFilter = 'all';

  List<EnrichedMyPertaminaTransaction> get filteredTransactions {
    final result = <EnrichedMyPertaminaTransaction>[];
    final seen = <String>{};
    for (final item in transactions) {
      if (masterStatusFilter == 'verified' && !item.isEnriched) continue;
      if (masterStatusFilter == 'unverified' && item.isEnriched) continue;
      if (lpgCategoryFilter != 'all' &&
          item.category.toUpperCase() != lpgCategoryFilter.toUpperCase()) {
        continue;
      }
      if (uniqueCustomersOnly) {
        final key = item.fullNik.isNotEmpty ? item.fullNik : item.maskedNik;
        if (!seen.add(key)) continue;
      }
      result.add(item);
    }
    return result;
  }

  void setTransactionFilters({
    required bool uniqueOnly,
    required String masterStatus,
    required String lpgCategory,
  }) {
    uniqueCustomersOnly = uniqueOnly;
    masterStatusFilter = masterStatus;
    lpgCategoryFilter = lpgCategory;
    notifyListeners();
  }

  TransactionProvider({required this.authProvider})
    : _api = MyPertaminaApiService(authProvider.apiClient);

  Future<void> fetchAndEnrichMyPertaminaTransactions(
    List<Pelanggan> localCustomers,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final start =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
      final end =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final raw = await _api.fetchMyPertaminaTransactionReport(
        startDate: start,
        endDate: end,
      );
      final byName = <String, List<Pelanggan>>{};
      for (final customer in localCustomers) {
        byName
            .putIfAbsent(customer.nama.trim().toUpperCase(), () => [])
            .add(customer);
      }
      transactions = raw.map((item) {
        final name = (item['name'] ?? item['customerName']).toString();
        final masked = (item['nationalityId'] ?? item['nik'] ?? '').toString();
        final candidates = byName[name.trim().toUpperCase()] ?? const [];
        final match = candidates.cast<Pelanggan?>().firstWhere(
          (customer) => customer != null && _nikMatches(customer.nik, masked),
          orElse: () => null,
        );
        final date = DateTime.tryParse((item['createdAt'] ?? '').toString());
        return EnrichedMyPertaminaTransaction(
          name: name,
          maskedNik: masked,
          fullNik: match?.nik ?? '',
          category: (item['categories'] ?? item['category'] ?? 'Rumah Tangga')
              .toString(),
          total: _toInt(item['total'] ?? item['quantity']),
          createdAt: date,
          isEnriched: match != null,
          hasMasterData: match != null,
          customerPhoto: null,
        );
      }).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> syncAndSaveMyPertaminaTransactionsThisYear(
    List<Pelanggan> customers,
  ) async {
    debugPrint(
      '💳 [TRANSACTION PROVIDER] Memulai sinkronisasi transaksi MyPertamina...',
    );
    debugPrint(
      '💳 [TRANSACTION PROVIDER] Master pelanggan: ${customers.length}',
    );
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final chunkCount = now.month * 2 - (now.day < 16 ? 1 : 0);
      monthlyProgress = 0;
      monthlyTotal = chunkCount;
      notifyListeners();
      final raw = <Map<String, dynamic>>[];
      var chunkIndex = 0;
      for (var month = 1; month <= now.month; month++) {
        final lastDay = DateTime(now.year, month + 1, 0).day;
        final periods = <({int startDay, int endDay})>[
          (startDay: 1, endDay: 15),
          (startDay: 16, endDay: lastDay),
        ];
        for (final period in periods) {
          if (month == now.month && period.startDay > now.day) continue;
          final endDay = month == now.month && period.endDay > now.day
              ? now.day
              : period.endDay;
          final start =
              '${now.year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${period.startDay.toString().padLeft(2, '0')}';
          final end =
              '${now.year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${endDay.toString().padLeft(2, '0')}';
          chunkIndex++;
          monthlyProgress = chunkIndex;
          notifyListeners();
          debugPrint(
            '📅 [MYPTM] Chunk $chunkIndex/$monthlyTotal: $start - $end',
          );
          try {
            raw.addAll(
              await _api.fetchMyPertaminaTransactionReport(
                startDate: start,
                endDate: end,
              ),
            );
          } on DioException catch (e, stackTrace) {
            final status = e.response?.statusCode;
            if (status == 406 || status == 404) {
              debugPrint(
                '⚠️ [MYPTM] Skip chunk $start - $end; HTTP $status: $e',
              );
              debugPrint('📌 [MYPTM CHUNK STACKTRACE]: $stackTrace');
              continue;
            }
            rethrow;
          }
        }
      }
      final byName = <String, List<Pelanggan>>{};
      for (final customer in customers) {
        byName
            .putIfAbsent(customer.nama.trim().toUpperCase(), () => [])
            .add(customer);
      }
      debugPrint(
        '💳 [TRANSACTION PROVIDER] Transaksi berhasil ditarik: ${raw.length}',
      );
      final data = raw.map((item) {
        final name = (item['name'] ?? item['customerName'] ?? '').toString();
        final masked =
            (item['nationalityId'] ?? item['maskedNik'] ?? item['nik'] ?? '')
                .toString();
        final match = (byName[name.trim().toUpperCase()] ?? const <Pelanggan>[])
            .cast<Pelanggan?>()
            .firstWhere(
              (customer) =>
                  customer != null && _nikMatches(customer.nik, masked),
              orElse: () => null,
            );
        final created = (item['createdAt'] ?? item['timestamp'] ?? '')
            .toString();
        final reportId = (item['customerReportId'] ?? item['id'] ?? '')
            .toString();
        final id =
            '${reportId.isNotEmpty ? reportId : (match?.nik ?? masked)}_$created'
                .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        return {
          'documentId': id,
          'name': name,
          'maskedNik': masked,
          'fullNik': match?.nik ?? '',
          'isMatchedWithCustomer': match != null,
          'isEnriched': match != null,
          'hasMasterData': match != null,
          'nationalityId': match?.nik ?? masked,
          'customerReportId': reportId,
          'category': (item['categories'] ?? item['category'] ?? 'Rumah Tangga')
              .toString(),
          'total': _toInt(item['total'] ?? item['quantity']),
          'createdAt': created,
          'registrationId': authProvider.registrationId,
        };
      }).toList();
      for (final item in data) {
        await _database.upsertTransaction({
          'id': item['documentId'],
          'registrationId': item['registrationId'],
          'customerReportId': item['customerReportId'],
          'nationalityId': item['nationalityId'],
          'name': item['name'],
          'categories': item['category'],
          'totalQuantity': item['total'],
          'createdAt': item['createdAt'],
        });

        // Ekstrak & update Nama Asli resmi ke data pelanggan di SQLite jika full NIK valid
        final fullNik = item['fullNik'].toString().trim();
        final rawNik = item['nationalityId'].toString().trim();
        final targetNik = fullNik.isNotEmpty ? fullNik : rawNik;
        final realName = item['name'].toString().trim();

        if (RegExp(r'^\d{16}$').hasMatch(targetNik) &&
            realName.isNotEmpty &&
            !realName.startsWith('Pelanggan ')) {
          try {
            final db = await _database.database;
            await db.rawUpdate(
              'UPDATE customers SET nama = ?, isEnriched = 1, updatedAt = ? WHERE nik = ? AND (nama LIKE "Pelanggan %" OR nama = "")',
              [realName, DateTime.now().toIso8601String(), targetNik],
            );
          } catch (_) {}
        }
      }
      debugPrint(
        '✅ [TRANSACTION PROVIDER] ${data.length} transaksi tersimpan ke SQLite.',
      );
      await _database.autoCleanDuplicateTransactions(authProvider.registrationId);
      await loadSavedMyPertaminaTransactions(authProvider.registrationId);
      return data.length;
    } catch (e, stackTrace) {
      error = e.toString();
      developer.log(
        '❌ [MYPTM PROVIDER ERROR]: $e',
        name: 'TransactionProvider',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('❌ [TRANSACTION SYNC ERROR]: $e\n$stackTrace');
      debugPrint('📌 [MYPTM PROVIDER STACKTRACE]: $stackTrace');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTransactionHistoryFromPayload(
    Map<String, dynamic> data, [
    String? registrationIdHint,
  ]) async {
    try {
      final regId = (registrationIdHint != null && registrationIdHint.isNotEmpty)
          ? registrationIdHint
          : (authProvider.registrationId.isNotEmpty
              ? authProvider.registrationId
              : 'PANGKALAN_DEFAULT');

      final subHeader = (data['subHeader'] is Map)
          ? Map<String, dynamic>.from(data['subHeader'] as Map)
          : null;
      final subsidi = (data['subsidi'] is Map)
          ? Map<String, dynamic>.from(data['subsidi'] as Map)
          : null;
      final customer = (data['customer'] is Map)
          ? Map<String, dynamic>.from(data['customer'] as Map)
          : null;

      final trxId = (data['transactionId'] ??
              data['id'] ??
              subHeader?['transactionUniqueKey'] ??
              '')
          .toString()
          .trim();
      final uniqueKey =
          (subHeader?['transactionUniqueKey'] ?? '').toString().trim();
      final nik = (subsidi?['nik'] ??
              customer?['nik'] ??
              data['nationalityId'] ??
              data['nik'] ??
              '')
          .toString()
          .trim();
      final name = (subsidi?['nama'] ??
              subsidi?['name'] ??
              customer?['customerName'] ??
              customer?['name'] ??
              data['name'] ??
              data['customerName'] ??
              '')
          .toString()
          .trim();
      final category = (subsidi?['category'] ??
              customer?['customerType'] ??
              data['categories'] ??
              'Rumah Tangga')
          .toString()
          .trim();
      final date = (subHeader?['date'] ??
              data['createdAt'] ??
              DateTime.now().toIso8601String())
          .toString()
          .trim();

      int totalQty = 0;
      if (data['products'] is List) {
        for (final p in (data['products'] as List)) {
          if (p is Map) {
            final q = p['quantity'] ?? p['qty'] ?? p['totalQuantity'] ?? 0;
            totalQty += (q is num) ? q.toInt() : (int.tryParse('$q') ?? 0);
          }
        }
      }
      if (totalQty == 0) {
        final q =
            data['totalQuantity'] ?? data['quantity'] ?? data['total'] ?? 1;
        totalQty = (q is num) ? q.toInt() : (int.tryParse('$q') ?? 1);
      }

      final id = trxId.isNotEmpty
          ? trxId
          : (uniqueKey.isNotEmpty ? uniqueKey : '${regId}_${nik}_$date');

      debugPrint(
        '💾 [POST-TRX SQLITE] Simpan transaksi id=$id | NIK=$nik | Qty=$totalQty',
      );

      await _database.upsertTransaction({
        'id': id,
        'registrationId': regId,
        'customerReportId': uniqueKey.isNotEmpty ? uniqueKey : trxId,
        'nationalityId': nik,
        'name': name.isNotEmpty ? name : 'Pelanggan $nik',
        'categories': category.isNotEmpty ? category : 'Rumah Tangga',
        'totalQuantity': totalQty,
        'createdAt': date,
      });

      await loadSavedMyPertaminaTransactions(regId);
      notifyListeners();
      debugPrint('✅ [POST-TRX SQLITE SUCCESS] Transaksi $id berhasil disimpan!');
    } catch (e, stack) {
      debugPrint('❌ [POST-TRX SQLITE ERROR]: $e\n$stack');
    }
  }

  Future<void> saveCapturedTransactionToLocal(
    String registrationId,
    Map<String, dynamic> txData,
  ) async {
    final nik = '${txData['nationalityId'] ?? txData['nik'] ?? ''}'.trim();
    final createdAt = '${txData['createdAt'] ?? DateTime.now().toIso8601String()}';
    final id = '${txData['transactionId'] ?? ''}'.trim().isNotEmpty
        ? '${txData['transactionId']}'.trim()
        : '${registrationId}_${nik}_$createdAt';
    debugPrint('💾 [SQLITE TRANSACTION] Upsert id=$id nik=$nik');
    await _database.upsertTransaction({
      'id': id,
      'registrationId': registrationId,
      'nationalityId': nik,
      'name': txData['name'] ?? txData['customerName'] ?? '',
      'categories': txData['categories'] ?? txData['customerType'] ?? 'Rumah Tangga',
      'totalQuantity': txData['totalQuantity'] ?? txData['quantity'] ?? 0,
      'createdAt': createdAt,
    });
    await loadSavedMyPertaminaTransactions(registrationId);
    notifyListeners();
  }

  Future<void> loadSavedMyPertaminaTransactions(String? registrationId) async {
    if (registrationId == null || registrationId.trim().isEmpty) {
      debugPrint(
        '⚠️ [MYPTM PROVIDER] registrationId masih kosong/null. Menunggu AuthProvider...',
      );
      return;
    }
    final normalizedRegistrationId = registrationId.trim();
    await _database.autoCleanDuplicateTransactions(normalizedRegistrationId);
    final data = await _database.getTransactions(normalizedRegistrationId);
    transactions = data
        .map(
          (item) => EnrichedMyPertaminaTransaction(
            name: '${item['name'] ?? ''}',
            maskedNik: '${item['nationalityId'] ?? ''}',
            fullNik: '${item['nationalityId'] ?? ''}',
            category: '${item['categories'] ?? 'Rumah Tangga'}',
            total: _toInt(item['totalQuantity']),
            createdAt: DateTime.tryParse('${item['createdAt'] ?? ''}'),
            isEnriched:
                item['isEnriched'] == true ||
                item['isMatchedWithCustomer'] == true,
            hasMasterData:
                item['hasMasterData'] == true ||
                item['isMatchedWithCustomer'] == true,
            customerPhoto: null,
          ),
        )
        .toList();
    notifyListeners();
  }
  /// Fungsi ringan yang hanya membaca riwayat transaksi dari SQLite lokal dan memperbarui UI.
  Future<void> loadLocalTransactions([String? registrationId]) async {
    final regId = registrationId ?? authProvider.registrationId;
    await loadSavedMyPertaminaTransactions(regId);
  }

  /// Fungsi sinkronisasi manual yang memanggil API MyPertamina, menggabungkan data ke SQLite, lalu memuat ulang UI.
  Future<int> refreshFromMyPertamina([List<Pelanggan>? localCustomers]) async {
    List<Pelanggan> customers = localCustomers ?? [];
    if (customers.isEmpty && authProvider.registrationId.isNotEmpty) {
      try {
        customers = await FirebaseService().getAllPelanggan(authProvider.registrationId);
      } catch (e) {
        debugPrint('⚠️ [TRANSACTION PROVIDER] Gagal mengambil pelanggan: $e');
      }
    }
    return await syncAndSaveMyPertaminaTransactionsThisYear(customers);
  }


  static bool _nikMatches(String nik, String masked) {
    final clean = nik.replaceAll(RegExp(r'\D'), '');
    final mask = masked.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 6 || mask.length < 6) return false;
    return mask.startsWith(clean.substring(0, 3)) &&
        mask.endsWith(clean.substring(clean.length - 3));
  }

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
