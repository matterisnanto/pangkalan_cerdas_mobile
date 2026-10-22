import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../models/pelanggan_model.dart';
import '../services/mypertamina_api_service.dart';
import '../services/firebase_service.dart';
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
  final FirebaseService _firebase = FirebaseService();
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
      await _firebase.upsertMyPertaminaTransactions(
        authProvider.registrationId,
        data,
      );
      await _firebase.deleteDuplicateMyPertaminaTransactions(
        authProvider.registrationId,
      );
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
      debugPrint('📌 [MYPTM PROVIDER STACKTRACE]: $stackTrace');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSavedMyPertaminaTransactions(String? registrationId) async {
    if (registrationId == null || registrationId.trim().isEmpty) {
      debugPrint(
        '⚠️ [MYPTM PROVIDER] registrationId masih kosong/null. Menunggu AuthProvider...',
      );
      return;
    }
    final normalizedRegistrationId = registrationId.trim();
    await _firebase.deleteDuplicateMyPertaminaTransactions(
      normalizedRegistrationId,
    );
    final data = await _firebase.getMyPertaminaTransactions(
      normalizedRegistrationId,
    );
    transactions = data
        .map(
          (item) => EnrichedMyPertaminaTransaction(
            name: '${item['name'] ?? ''}',
            maskedNik: '${item['maskedNik'] ?? ''}',
            fullNik: '${item['fullNik'] ?? ''}',
            category: '${item['category'] ?? 'Rumah Tangga'}',
            total: _toInt(item['total']),
            createdAt: item['createdAt'] is Timestamp
                ? (item['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse('${item['createdAt'] ?? ''}'),
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

  Future<int> cleanDuplicateMyPertaminaTransactions() async {
    final registrationId = authProvider.registrationId.trim();
    if (registrationId.isEmpty) return 0;
    final removed = await _firebase.deleteDuplicateMyPertaminaTransactions(
      registrationId,
    );
    await loadSavedMyPertaminaTransactions(registrationId);
    return removed;
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
