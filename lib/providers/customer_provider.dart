import 'package:flutter/foundation.dart';

import '../services/mypertamina_api_service.dart';
import '../services/pelanggan_service.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart';

class CustomerProvider extends ChangeNotifier {
  final PelangganService _pelangganService;
  final AuthProvider _authProvider;
  final SecureStorageService _storage;
  bool _isSyncing = false;
  bool isSyncingQuota = false;
  int syncCurrentIndex = 0;
  int syncTotalCount = 0;

  CustomerProvider({
    PelangganService? pelangganService,
    required this._authProvider,
    SecureStorageService? storage,
  }) : _pelangganService = pelangganService ?? PelangganService(),
       _storage = storage ?? SecureStorageService();

  bool get isSyncing => _isSyncing;

  Future<void> syncAllCustomersQuotaFromMyPertamina() async {
    if (_isSyncing) return;
    final token = await _storage.getToken();
    if (token == null || token.isEmpty || !_authProvider.isTokenValid) {
      throw StateError('Sesi Habis - Silakan Login di WebView');
    }

    _isSyncing = true;
    isSyncingQuota = true;
    syncCurrentIndex = 0;
    notifyListeners();
    try {
      final customers = await _pelangganService.getAllPelanggan();
      syncTotalCount = customers.length;
      notifyListeners();
      final api = MyPertaminaApiService(_authProvider.apiClient);
      const chunkSize = 4;
      for (var start = 0; start < customers.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, customers.length);
        final currentBatch = customers.sublist(start, end);

        await Future.wait(
          currentBatch.map((customer) async {
            try {
              var familyId = customer.familyIdEncrypted;
              if (familyId == null || familyId.trim().isEmpty) {
                final verified = await api.verifyNik(customer.nik);
                familyId = verified.familyIdEncrypted.isNotEmpty
                    ? verified.familyIdEncrypted
                    : verified.familyId;
              }
              familyId = familyId.trim();
              if (familyId.isEmpty) return;
              final quota = await api.fetchCustomerQuota(
                customer.nik,
                familyId,
                customer.kategori,
              );
              final now = DateTime.now();
              await _pelangganService.updatePelanggan(
                customer.copyWith(
                  sisaKuota: quota,
                  sisaKuotaBulanan: quota,
                  familyIdEncrypted: familyId,
                  encryptedFamilyId: familyId,
                  lastQuotaUpdate: now,
                  lastSyncedAt: now,
                ),
              );
            } catch (_) {
              // Continue syncing remaining customers when one NIK fails.
            }
          }),
        );

        syncCurrentIndex += currentBatch.length;
        notifyListeners();
        if (end < customers.length) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    } finally {
      _isSyncing = false;
      isSyncingQuota = false;
      syncCurrentIndex = 0;
      syncTotalCount = 0;
      notifyListeners();
    }
  }
}
