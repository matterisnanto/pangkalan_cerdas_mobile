import 'package:flutter/widgets.dart';

import '../models/pelanggan_model.dart';
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

  void safeNotifyListeners() {
    if (!hasListeners) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> autoSaveCustomerFromPortalTransaction(
    Map<String, dynamic> txData,
  ) => autoSaveCustomerFromPortal(txData);

  Future<void> autoSaveCustomerFromPortal(
    Map<String, dynamic> portalData,
  ) async {
    debugPrint(
      '👤 [CUSTOMER PROVIDER] Memproses auto-save pelanggan dari portal...',
    );
    try {
      final nik =
          (portalData['nik'] ??
                  portalData['NIK'] ??
                  portalData['nationalityId'] ??
                  '')
              .toString()
              .trim();
      final nama =
          (portalData['nama'] ??
                  portalData['name'] ??
                  portalData['customerName'] ??
                  '')
              .toString()
              .trim();
      debugPrint('👤 [CUSTOMER PROVIDER] Extracted NIK: $nik | Nama: $nama');
      if (nik.isEmpty || nama.isEmpty) {
        debugPrint(
          '⚠️ [CUSTOMER PROVIDER] NIK/nama kosong; proses dibatalkan.',
        );
        return;
      }
      final familyId =
          (portalData['familyId'] ??
                  portalData['familyIdEncrypted'] ??
                  portalData['encryptedFamilyId'] ??
                  '')
              .toString()
              .trim();
      final category = Pelanggan.normalizeKategori(
        (portalData['kategori'] ??
                portalData['category'] ??
                portalData['categories'])
            ?.toString(),
      );
      int readQuota(String key) => (portalData[key] is num)
          ? (portalData[key] as num).toInt()
          : int.tryParse('${portalData[key] ?? ''}') ?? 0;
      final quota = readQuota('sisaKuota') != 0
          ? readQuota('sisaKuota')
          : readQuota('sisaKuotaBulanan');
      debugPrint(
        '👤 [CUSTOMER PROVIDER] Family ID: $familyId | Kategori: $category | Sisa Kuota: $quota',
      );
      final existing = await _pelangganService.getPelangganByNik(nik);
      debugPrint(
        existing == null
            ? '➕ [CUSTOMER PROVIDER] Pelanggan NIK $nik BELUM ADA. Mendaftarkan pelanggan baru ke Firestore...'
            : 'ℹ️ [CUSTOMER PROVIDER] Pelanggan NIK $nik SUDAH TERDAFTAR. Mengupdate Family ID...',
      );
      final customer =
          (existing ?? Pelanggan(nik: nik, nama: nama, kategori: category))
              .copyWith(
                nama: nama,
                kategori: category,
                familyIdEncrypted: familyId.isEmpty ? null : familyId,
                encryptedFamilyId: familyId.isEmpty ? null : familyId,
                sisaKuota: readQuota('sisaKuota') == 0
                    ? null
                    : readQuota('sisaKuota'),
                sisaKuotaBulanan: readQuota('sisaKuotaBulanan') == 0
                    ? readQuota('sisa_kuota') == 0
                          ? null
                          : readQuota('sisa_kuota')
                    : readQuota('sisaKuotaBulanan'),
                sisaKuotaTotal: readQuota('sisaKuotaTotal') == 0
                    ? null
                    : readQuota('sisaKuotaTotal'),
              );
      await _pelangganService.addPelanggan(customer);
      debugPrint('✅ [AUTO-CUSTOMER] Pelanggan tersimpan: $nik');
    } catch (e, stackTrace) {
      debugPrint('❌ [CUSTOMER SAVE ERROR]: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> syncAllCustomersQuotaFromMyPertamina() async {
    if (_isSyncing) return;
    final token = await _storage.getToken();
    if (token == null || token.isEmpty || !_authProvider.isTokenValid) {
      throw StateError('Sesi Habis - Silakan Login di WebView');
    }

    _isSyncing = true;
    isSyncingQuota = true;
    syncCurrentIndex = 0;
    safeNotifyListeners();
    try {
      final customers = await _pelangganService.getAllPelanggan();
      syncTotalCount = customers.length;
      debugPrint('🚀 [SYNC STARTED] Total Pelanggan: ${customers.length}');
      safeNotifyListeners();
      final api = MyPertaminaApiService(_authProvider.apiClient);
      const chunkSize = 3;
      for (var start = 0; start < customers.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, customers.length);
        final currentBatch = customers.sublist(start, end);
        debugPrint(
          '🔄 [SYNC BATCH] Processing Index: $syncCurrentIndex / $syncTotalCount',
        );

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
              if (familyId.isEmpty) {
                debugPrint(
                  '⚠️ [SYNC ITEM FAILED] NIK: ${customer.nik} Gagal dengan Error: familyIdEncrypted kosong',
                );
                syncCurrentIndex++;
                safeNotifyListeners();
                return;
              }
              final quotaMap = await api.fetchCustomerQuota(
                customer.nik,
                familyId,
                customer.kategori,
              );
              final newQuota = (quotaMap['monthly'] as num? ?? 0).toInt();
              debugPrint(
                '✅ [SYNC SUCCESS] NIK: ${customer.nik} | Quota Lama: ${customer.sisaKuota} -> Quota Baru: $newQuota',
              );
              final now = DateTime.now();
              final updatedCustomer = customer.copyWith(
                sisaKuota: newQuota,
                sisaKuotaBulanan: newQuota,
                sisaKuotaTotal: (quotaMap['all'] as num? ?? 0).toInt(),
                sisaKuotaKeluarga: (quotaMap['family'] as num? ?? 0).toInt(),
                familyIdEncrypted: familyId,
                encryptedFamilyId: familyId,
                lastQuotaUpdate: now,
                lastSyncedAt: now,
              );

              // Update progress locally before Firestore, so permission errors
              // cannot block UI progress.
              syncCurrentIndex++;
              safeNotifyListeners();
              try {
                await _pelangganService.updatePelanggan(updatedCustomer);
              } catch (fsError) {
                debugPrint(
                  '⚠️ [FIRESTORE WRITE WARN] Gagal simpan ke Firestore '
                  '(Permission Denied), tetapi UI lokal tetap di-update: $fsError',
                );
              }
            } catch (e) {
              debugPrint(
                '⚠️ [SYNC ITEM FAILED] NIK: ${customer.nik} Gagal dengan Error: $e',
              );
              syncCurrentIndex++;
              safeNotifyListeners();
            }
          }),
        );

        if (end < customers.length) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    } finally {
      _isSyncing = false;
      isSyncingQuota = false;
      debugPrint('🏁 [SYNC FINISHED] State isSyncingQuota di-reset ke FALSE');
      syncCurrentIndex = 0;
      syncTotalCount = 0;
      safeNotifyListeners();
    }
  }
}
