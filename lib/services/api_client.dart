import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static const String _baseUrl = 'https://api-map.my-pertamina.id';
  static const String _origin = 'https://subsiditepatlpg.mypertamina.id';
  static const String _referer = 'https://subsiditepatlpg.mypertamina.id/';
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  final SecureStorageService _storage;
  late final Dio _dio;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Origin'] = _origin;
        options.headers['Referer'] = _referer;
        options.headers['Accept'] = 'application/json, text/plain, */*';
        options.headers['User-Agent'] = _userAgent;
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  /// GET /general/products/v1/products/user
  Future<Response> fetchUserProducts() async {
    return _dio.get('/general/products/v1/products/user');
  }

  /// GET /general/customer-service/v1/verify-nik-transaction-manual
  Future<Response> verifyNikTransaction(String nik) async {
    return _dio.get(
      '/general/customer-service/v1/verify-nik-transaction-manual',
      queryParameters: {'nationalityId': nik},
    );
  }

  /// GET /general/v3/transactions/report
  Future<Response> fetchTransactionReport({
    required String startDate,
    required String endDate,
    String sort = 'latest',
  }) async {
    return _dio.get(
      '/general/v3/transactions/report',
      queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
        'sort': sort,
      },
    );
  }

  /// Parse DioException into readable message
  static String parseDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 401 || statusCode == 403) {
        return 'Sesi token kadaluarsa (HTTP $statusCode). Silakan refresh WebView.';
      }
      if (statusCode == 429) {
        return 'Rate limit tercapai (HTTP 429). Coba lagi nanti.';
      }
      if (data is Map<String, dynamic>) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            'Error server (HTTP $statusCode)';
      }
      return 'Error server (HTTP $statusCode): ${data?.toString() ?? "Unknown"}';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout. Periksa jaringan internet.';
    }
    return 'Network error: ${e.message ?? "Unknown"}';
  }

  /// Check if error is token expired
  static bool isTokenExpired(DioException e) {
    final code = e.response?.statusCode ?? 0;
    return code == 401 || code == 403;
  }
}
