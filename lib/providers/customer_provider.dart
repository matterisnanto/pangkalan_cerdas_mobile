import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../models/pelanggan_model.dart';
import '../services/mypertamina_api_service.dart';
import '../services/local_database_service.dart';
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

  Future<Database> get database => LocalDatabaseService.instance.database;

  Future<void> loadCustomers() async {
    notifyListeners();
  }

  void safeNotifyListeners() {
    if (!hasListeners) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  /// JANGAN panggil metode ini selama sesi WebView transaksi aktif!
  /// Pemanggilan /verify-nik dari Flutter di latar belakang membatalkan single-use token
  /// portal MyPertamina, menyebabkan CUSTOMER_DATA_INVALID / verifikasi NIK ulang.
  /// Ekstraksi Nama Asli dilakukan secara aman saat transaksi berhasil atau sinkronisasi report.
  Future<void> fetchAndEnrichCustomerDirectly(
    String nik, {
    String? familyIdHint,
    String? authToken,
  }) async {
    if (nik.length != 16) return;

    try {
      debugPrint('🚀 [DART DIRECT API] Memulai Direct Fetch untuk NIK $nik...');

      String finalNama = '';
      String finalFamilyId = familyIdHint ?? '';
      int finalQuota = 0;

      final token = (authToken != null && authToken.isNotEmpty)
          ? authToken
          : _authProvider.token;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        if (token != null && token.isNotEmpty)
          'Authorization':
              token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      // 1. CALL API VERIFY-NIK (AMBIL NAMA ASLI & FAMILY ID ENCRYPTED)
      try {
        final verifyUrl = Uri.parse(
          'https://api-map.my-pertamina.id/general/customer-service/v1/verify-nik?nationalityId=$nik',
        );
        final verifyRes = await http
            .get(verifyUrl, headers: headers)
            .timeout(const Duration(seconds: 5));

        if (verifyRes.statusCode == 200) {
          final vData = jsonDecode(verifyRes.body);
          if (vData['success'] == true && vData['data'] != null) {
            final realName = vData['data']['name']?.toString() ?? '';
            final famIdEnc =
                vData['data']['familyIdEncrypted']?.toString() ?? '';

            if (realName.isNotEmpty) finalNama = realName.trim();
            if (famIdEnc.isNotEmpty) finalFamilyId = famIdEnc.trim();

            debugPrint(
              '🎯 [DART API VERIFY SUCCESS] Nama: $finalNama | FamID: $finalFamilyId',
            );
          }
        }
      } catch (eVerify) {
        debugPrint('⚠️ [DART API VERIFY WARN]: $eVerify');
      }

      // 2. CALL API QUOTA (AMBIL SISA KUOTA BULANAN / KELUARGA)
      if (finalFamilyId.isNotEmpty) {
        try {
          final quotaUrl = Uri.parse(
            'https://api-map.my-pertamina.id/general/v5/customers/$nik/quota?familyId=${Uri.encodeComponent(finalFamilyId)}&customerType=Rumah+Tangga',
          );
          final quotaRes = await http
              .get(quotaUrl, headers: headers)
              .timeout(const Duration(seconds: 5));

          if (quotaRes.statusCode == 200) {
            final qData = jsonDecode(quotaRes.body);
            if (qData['success'] == true &&
                qData['data'] != null &&
                qData['data']['quotaRemaining'] != null) {
              final qr = qData['data']['quotaRemaining'];
              final q = (qr['monthly'] != null)
                  ? qr['monthly']
                  : (qr['family'] ?? 0);
              finalQuota = (q as num).toInt();

              debugPrint('🎯 [DART API QUOTA SUCCESS] Kuota: $finalQuota');
            }
          }
        } catch (eQuota) {
          debugPrint('⚠️ [DART API QUOTA WARN]: $eQuota');
        }
      }

      // 3. SIMPAN KE SQLITE SMART UPSERT
      await autoSaveCustomerFromPortalQuota({
        'nik': nik,
        'nama': finalNama,
        'familyId': finalFamilyId,
        'remainingQuota': finalQuota,
        'category': 'Rumah Tangga',
        'isEnriched': 1,
      });
    } catch (e, stack) {
      debugPrint('❌ [DART DIRECT API ERROR]: $e\n$stack');
    }
  }


  Future<void> autoSaveCustomerFromPortalQuota(Map<String, dynamic> data) async {
    try {
      final nik = data['nik']?.toString().trim() ?? '';
      if (nik.length != 16) return;

      final db = await database;
      final existingRows = await db.query(
        'customers',
        where: 'nik = ?',
        whereArgs: [nik],
        limit: 1,
      );

      String currentNama = '';
      String currentFamilyId = '';
      int currentQuota = 0;
      String currentCategory = 'Rumah Tangga';

      if (existingRows.isNotEmpty) {
        final old = existingRows.first;
        currentNama = old['nama']?.toString() ?? '';
        currentFamilyId = old['familyId']?.toString() ?? '';
        currentQuota = (old['remainingQuota'] as num?)?.toInt() ?? 0;
        currentCategory = old['category']?.toString() ?? 'Rumah Tangga';
      }

      // Jika incomingNama membawa Nama Asli resmi, WAJIB menimpa 'Pelanggan {NIK}'
      final incomingNama = data['nama']?.toString() ?? data['name']?.toString() ?? '';
      if (incomingNama.isNotEmpty && !incomingNama.startsWith('Pelanggan ')) {
        currentNama = incomingNama.trim();
      } else if (currentNama.isEmpty) {
        currentNama = incomingNama.isNotEmpty ? incomingNama.trim() : 'Pelanggan $nik';
      }

      final incomingFamId = data['familyId']?.toString() ?? '';
      if (incomingFamId.isNotEmpty) {
        currentFamilyId = incomingFamId.trim();
      }

      if (data.containsKey('remainingQuota') && data['remainingQuota'] != null) {
        final rawVal = data['remainingQuota'];
        final incomingQuota = rawVal is num
            ? rawVal.toInt()
            : (int.tryParse('$rawVal') ?? 0);
        // Pastikan kuota 0 (Skenario B) tersimpan akurat ke SQLite
        currentQuota = incomingQuota;
      }

      if (data['category'] != null && data['category'].toString().isNotEmpty) {
        currentCategory = data['category'].toString();
      }

      final customerMap = {
        'nik': nik,
        'nama': currentNama,
        'familyId': currentFamilyId,
        'category': currentCategory,
        'remainingQuota': currentQuota,
        'isEnriched': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      debugPrint('💾 [SQLITE SAVING DATA]: $customerMap');
      await db.insert('customers', customerMap, conflictAlgorithm: ConflictAlgorithm.replace);

      await loadCustomers();
      notifyListeners();
      debugPrint('✅ [SQLITE SUCCESS] NIK $nik | Nama: $currentNama | FamID: $currentFamilyId | Kuota: $currentQuota');
    } catch (e, stack) {
      debugPrint('❌ [SQLITE PROVIDER ERROR]: $e\n$stack');
    }
  }

  Future<void> saveEnrichedCustomerFromTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final subsidi = (data['subsidi'] is Map)
          ? Map<String, dynamic>.from(data['subsidi'] as Map)
          : null;
      final customer = (data['customer'] is Map)
          ? Map<String, dynamic>.from(data['customer'] as Map)
          : null;

      // 1. Ekstrak NIK
      String nik = (subsidi?['nik'] ??
              customer?['nik'] ??
              customer?['nationalityId'] ??
              data['nationalityId'] ??
              data['nik'] ??
              '')
          .toString()
          .trim();

      if (!RegExp(r'^\d{16}$').hasMatch(nik)) {
        debugPrint('⚠️ [POST-TRX CUSTOMER] NIK tidak valid: $nik');
        return;
      }

      // 2. Ekstrak Nama Asli Resmi
      String nama = (subsidi?['nama'] ??
              subsidi?['name'] ??
              customer?['customerName'] ??
              customer?['name'] ??
              data['customerName'] ??
              data['name'] ??
              '')
          .toString()
          .trim();

      // 3. Ekstrak Family ID Encrypted
      String familyId = (subsidi?['familyIdEncrypted'] ??
              subsidi?['familyId'] ??
              customer?['familyIdEncrypted'] ??
              customer?['familyId'] ??
              data['familyIdEncrypted'] ??
              data['familyId'] ??
              '')
          .toString()
          .trim();

      // 4. Ekstrak Kategori
      String category = (subsidi?['category'] ??
              subsidi?['categories'] ??
              customer?['customerType'] ??
              customer?['category'] ??
              data['categories'] ??
              data['customerType'] ??
              'Rumah Tangga')
          .toString()
          .trim();
      if (category.isEmpty) category = 'Rumah Tangga';

      // 5. Ekstrak Sisa Kuota
      int quota = 0;
      final rawQuota = subsidi?['quotaRemaining'] ??
          customer?['quotaRemaining'] ??
          data['quotaRemaining'];
      if (rawQuota is num) {
        quota = rawQuota.toInt();
      } else if (rawQuota is Map) {
        final q = rawQuota['monthly'] ?? rawQuota['family'] ?? 0;
        quota = (q is num) ? q.toInt() : (int.tryParse('$q') ?? 0);
      } else if (rawQuota != null) {
        quota = int.tryParse(rawQuota.toString()) ?? 0;
      }

      await autoSaveCustomerFromPortalQuota({
        'nik': nik,
        'nama': nama,
        'familyId': familyId,
        'category': category,
        'remainingQuota': quota,
        'isEnriched': 1,
      });

      debugPrint(
        '🎉 [POST-TRX CUSTOMER SAVED] NIK: $nik | Nama: $nama | Quota: $quota',
      );
    } catch (e, stack) {
      debugPrint('❌ [POST-TRX CUSTOMER ERROR]: $e\n$stack');
    }
  }

  Future<void> autoSaveCustomerFromTransactionPayload(
    Map<String, dynamic> txData,
  ) async {
    final nik = '${txData['nationalityId'] ?? txData['nik'] ?? ''}'.trim();
    if (!RegExp(r'^\d{16}$').hasMatch(nik)) {
      debugPrint('⚠️ [TRANSACTION CUSTOMER] NIK tidak valid: $nik');
      return;
    }
    await autoSaveCustomerFromPortalQuota({
      'nik': nik,
      'name': txData['name'] ?? txData['customerName'] ?? '',
      'category': txData['categories'] ?? txData['customerType'] ?? 'Rumah Tangga',
      'familyId': txData['familyId'] ?? '',
      'remainingQuota': txData['remainingQuota'] ?? 0,
      'phoneNumber': txData['phoneNumber'] ?? '',
      'address': txData['address'] ?? '',
    });
  }

  Future<void> autoSaveCustomerFromPortalTransaction(
    Map<String, dynamic> txData,
  ) => autoSaveCustomerFromTransactionPayload(txData);

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
