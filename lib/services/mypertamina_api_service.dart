import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/mypertamina_models.dart';
import 'api_client.dart';

class TransactionSubmission {
  final String quantity;
  final String token;
  final String nationalityId;
  final String familyIdEncrypted;
  final String category;
  final String name;
  final String channelInject;
  final String coordinate;

  const TransactionSubmission({
    this.quantity = '1',
    required this.token,
    required this.nationalityId,
    required this.familyIdEncrypted,
    required this.category,
    required this.name,
    this.channelInject = 'MOBILE',
    required this.coordinate,
  });

  FormData toFormData() => FormData.fromMap({
    'quantity': quantity,
    'token': token,
    'nationalityId': nationalityId,
    'familyIdEncrypted': familyIdEncrypted,
    'category': category,
    'sourceTypeId': '1',
    'name': name,
    'channelInject': channelInject,
    'coordinate': coordinate,
  });
}

class AutoFetchedCustomer {
  final String nik;
  final String name;
  final String category;
  final String familyIdEncrypted;
  final int quotaRemaining;
  final num dailyRemaining;
  final num monthlyRemaining;
  final Map<String, dynamic> rawVerification;
  final Map<String, dynamic> rawQuota;

  const AutoFetchedCustomer({
    required this.nik,
    required this.name,
    required this.category,
    required this.familyIdEncrypted,
    required this.quotaRemaining,
    this.dailyRemaining = 0,
    this.monthlyRemaining = 0,
    this.rawVerification = const {},
    this.rawQuota = const {},
  });
}

class MyPertaminaApiService {
  static const baseUrl = 'https://api-map.my-pertamina.id';
  final ApiClient client;
  MyPertaminaApiService(this.client);
  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async =>
      unwrapJson((await client.dio.get(path, queryParameters: query)).data);
  Future<PangkalanProfileModel> fetchProfile() async =>
      PangkalanProfileModel.fromJson(await _get('/general/v1/users/profile'));

  /// Fetch official LPG stock data using the active Bearer token.
  Future<ProductStockModel> fetchProductAndStockFromApi() async {
    final products = await fetchStock();
    if (products.isEmpty) {
      throw StateError('Data produk/stok MyPertamina kosong');
    }
    return products.first;
  }

  Future<List<ProductStockModel>> fetchStock() async =>
      unwrapList(
            (await client.dio.get('/general/products/v1/products/user')).data,
          )
          .whereType<Map>()
          .map((e) => ProductStockModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  Future<CustomerVerificationModel> verifyNik(String nik) async =>
      CustomerVerificationModel.fromJson(
        await _get(
          '/general/customer-service/v1/verify-nik',
          query: {'nationalityId': nik},
        ),
      );

  Future<Map<String, dynamic>> fetchCustomerQuota(
    String nik,
    String familyIdEncrypted,
    String category,
  ) async {
    final encodedFamilyId = Uri.encodeComponent(familyIdEncrypted.trim());
    final normalizedCategory =
        category.trim().toUpperCase().contains('UMKM') ||
            category.trim().toUpperCase().contains('USAHA MIKRO')
        ? 'Usaha Mikro'
        : category.trim();
    final encodedCategory = Uri.encodeComponent(normalizedCategory);
    debugPrint(
      '🔍 [API QUOTA REQUEST] NIK: $nik | Category: $category | '
      'Encoded familyId: $encodedFamilyId',
    );
    try {
      final response = await client.dio.get(
        '$baseUrl/general/v5/customers/${Uri.encodeComponent(nik.trim())}/quota'
        '?familyId=$encodedFamilyId'
        '&customerType=$encodedCategory',
      );
      debugPrint(
        '📥 [API QUOTA RESPONSE] Status: ${response.statusCode} | '
        'Data: ${response.data}',
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body is Map
          ? Map<String, dynamic>.from(body)
          : const <String, dynamic>{};
      final quotaObj = data['quotaRemaining'];
      int toInt(dynamic value) =>
          value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      final map = quotaObj is Map ? quotaObj : const <String, dynamic>{};
      return {
        'monthly': toInt(map['monthly']),
        'all': toInt(map['all']),
        'family': toInt(map['family']),
      };
    } catch (e) {
      debugPrint('❌ [API QUOTA ERROR] NIK: $nik | Exception: $e');
      rethrow;
    }
  }

  /// SMART AUTO-FILL NIK berdasarkan API MyPertamina
  Future<AutoFetchedCustomer> autoFetchCustomerByNik(String nik) async {
    final cleanNik = nik.trim();
    if (cleanNik.length != 16) {
      throw ArgumentError('NIK harus 16 digit angka');
    }

    // a. GET https://api-map.my-pertamina.id/general/customer-service/v1/verify-nik?nationalityId=$nik
    final resp = await _get(
      '/general/customer-service/v1/verify-nik',
      query: {'nationalityId': cleanNik},
    );

    // b. Ekstrak data JSON
    final name = resp['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw StateError('NIK tidak terdaftar atau tidak valid di MyPertamina');
    }

    String category = 'Rumah Tangga';
    if (resp['customerTypes'] is List &&
        (resp['customerTypes'] as List).isNotEmpty) {
      final first = (resp['customerTypes'] as List).first;
      if (first is Map && first['name'] != null) {
        category = first['name'].toString().trim();
      }
    } else if (resp['customerTypes'] is Map &&
        resp['customerTypes']['name'] != null) {
      category = resp['customerTypes']['name'].toString().trim();
    }

    final familyIdEncrypted =
        resp['familyIdEncrypted']?.toString() ??
        resp['familyId']?.toString() ??
        '';

    // c. GET https://api-map.my-pertamina.id/general/v5/customers/$nik/quota?familyId=$familyIdEncrypted&customerType=$category
    Map<String, dynamic> quotaJson = {};
    int quotaRemaining = 0;
    num daily = 0;
    num monthly = 0;

    if (familyIdEncrypted.isNotEmpty) {
      try {
        quotaJson = await fetchCustomerQuota(
          cleanNik,
          familyIdEncrypted,
          category,
        );
        monthly = (quotaJson['monthly'] as num? ?? 0);
        quotaRemaining = monthly.toInt();
      } catch (_) {
        quotaRemaining =
            (category.toLowerCase().contains('umkm') ||
                category.toLowerCase().contains('usaha'))
            ? 5
            : 2;
      }
    }

    // d. Kembalikan objek Customer lengkap
    return AutoFetchedCustomer(
      nik: cleanNik,
      name: name,
      category: category,
      familyIdEncrypted: familyIdEncrypted,
      quotaRemaining: quotaRemaining,
      dailyRemaining: daily,
      monthlyRemaining: monthly,
      rawVerification: resp,
      rawQuota: quotaJson,
    );
  }

  Future<(CustomerVerificationModel, QuotaRemainingModel)> syncCustomerQuota(
    String nik,
    String category,
  ) async {
    final verification = await verifyNik(nik);
    final familyId = verification.familyIdEncrypted.isNotEmpty
        ? verification.familyIdEncrypted
        : verification.familyId;
    if (familyId.isEmpty) {
      throw StateError('encryptedFamilyId tidak ditemukan untuk NIK $nik');
    }
    final quota = await checkQuota(nik, familyId, category);
    return (verification, quota);
  }

  Future<QuotaRemainingModel> checkQuota(
    String nik,
    String encryptedFamilyId,
    String category,
  ) async => QuotaRemainingModel.fromJson(
    await _get(
      '/general/v5/customers/$nik/quota',
      query: {'familyId': encryptedFamilyId, 'customerType': category},
    ),
  );
  Future<TransactionReceiptModel> fetchTransactionDetail(
    String transactionId,
  ) async => TransactionReceiptModel.fromJson(
    await _get('/general/v1/transactions/$transactionId'),
  );
  Future<Response<dynamic>> submitTransactionV3(
    TransactionSubmission request,
  ) => client.dio.post('/general/v3/transactions', data: request.toFormData());

  Future<List<dynamic>> fetchLogbook(
    String startPeriode,
    String endPeriode,
  ) async => unwrapList(
    (await client.dio.get(
      '/general/v1/transactions/logbook',
      queryParameters: {'startPeriode': startPeriode, 'endPeriode': endPeriode},
    )).data,
  );

  Future<List<Map<String, dynamic>>> fetchMyPertaminaTransactionReport({
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now();
    final resolvedStart =
        startDate ?? '${now.year.toString().padLeft(4, '0')}-01-01';
    final resolvedEnd = endDate ?? _formatDate(now);

    final response = await client.dio.get(
      '/general/v3/transactions/report',
      queryParameters: {
        'startDate': resolvedStart,
        'endDate': resolvedEnd,
        'sort': 'latest',
      },
    );
    return unwrapList(
      response.data,
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<List<TransactionReceiptModel>> fetchReport({
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? _formatDate(DateTime(now.year, now.month, 1));
    final end = endDate ?? _formatDate(now);
    final response = await client.dio.get(
      '$baseUrl/general/v3/transactions/report',
      queryParameters: {
        'search': '',
        'sort': 'latest',
        'startDate': start,
        'endDate': end,
      },
    );
    return unwrapList(response.data)
        .whereType<Map>()
        .map(
          (e) => TransactionReceiptModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> fetchSummary(
    String startDate,
    String endDate,
  ) async => _get(
    '/general/transactions/v1/summary',
    query: {'startDate': startDate, 'endDate': endDate},
  );
}
