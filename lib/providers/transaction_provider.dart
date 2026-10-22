import 'package:flutter/foundation.dart';
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
      final raw = await _api.fetchMyPertaminaTransactionReport(
        startDate: '${now.year.toString().padLeft(4, '0')}-01-01',
        endDate:
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );
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
      await loadSavedMyPertaminaTransactions();
      return data.length;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSavedMyPertaminaTransactions() async {
    final data = await _firebase.getMyPertaminaTransactions(
      authProvider.registrationId,
    );
    transactions = data
        .map(
          (item) => EnrichedMyPertaminaTransaction(
            name: '${item['name'] ?? ''}',
            maskedNik: '${item['maskedNik'] ?? ''}',
            fullNik: '${item['fullNik'] ?? ''}',
            category: '${item['category'] ?? 'Rumah Tangga'}',
            total: _toInt(item['total']),
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
