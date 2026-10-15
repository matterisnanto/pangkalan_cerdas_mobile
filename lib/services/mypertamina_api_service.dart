import 'package:dio/dio.dart';
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

  Future<List<TransactionReceiptModel>> fetchReport(
    String startDate,
    String endDate,
  ) async =>
      unwrapList(
            (await client.dio.get(
              '/general/v3/transactions/report',
              queryParameters: {
                'search': '',
                'startDate': startDate,
                'endDate': endDate,
                'sort': 'latest',
              },
            )).data,
          )
          .whereType<Map>()
          .map(
            (e) =>
                TransactionReceiptModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
  Future<Map<String, dynamic>> fetchSummary(
    String startDate,
    String endDate,
  ) async => _get(
    '/general/transactions/v1/summary',
    query: {'startDate': startDate, 'endDate': endDate},
  );
}
