import 'package:flutter/foundation.dart';
import '../models/pelanggan_model.dart';
import '../services/mypertamina_api_service.dart';
import 'auth_provider.dart';

class EnrichedMyPertaminaTransaction {
  final String name;
  final String maskedNik;
  final String fullNik;
  final String category;
  final int total;
  final DateTime? createdAt;
  final bool isEnriched;
  final String? customerPhoto;

  const EnrichedMyPertaminaTransaction({
    required this.name,
    required this.maskedNik,
    required this.fullNik,
    required this.category,
    required this.total,
    required this.createdAt,
    required this.isEnriched,
    this.customerPhoto,
  });
}

class TransactionProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  final MyPertaminaApiService _api;
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
