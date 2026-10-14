import 'package:flutter/foundation.dart';
import '../models/pangkalan.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  late final ApiClient _apiClient;
  final FirebaseService _firebaseService = FirebaseService();

  String? _token;
  Pangkalan? _pangkalan;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _apiClient = ApiClient(_storage);
    _loadSavedState();
  }

  String? get token => _token;
  Pangkalan? get pangkalan => _pangkalan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTokenAvailable => _token != null && _token!.isNotEmpty;
  String get registrationId => _pangkalan?.registrationId ?? '';
  String get storeName => _pangkalan?.storeName ?? '';
  int get stockAvailable => _pangkalan?.stockAvailable ?? 0;
  ApiClient get apiClient => _apiClient;

  Future<void> _loadSavedState() async {
    _token = await _storage.getToken();
    final regId = await _storage.getRegistrationId();
    if (regId != null && regId.isNotEmpty) {
      _pangkalan = await _firebaseService.getPangkalan(regId);
    }
    notifyListeners();
  }

  /// Called when WebView interceptor captures a Bearer token
  Future<void> onTokenCaptured(String newToken) async {
    _token = newToken;
    await _storage.saveToken(newToken);
    notifyListeners();
    await fetchUserProfile();
  }

  /// Fetch user profile from MyPertamina API
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.fetchUserProducts();
      final data = response.data;

      if (data == null) {
        _errorMessage = 'Respon API kosong';
        return;
      }

      // Handle response structure: { data: { registrationId, ... } }
      final Map<String, dynamic> productData =
          data is Map<String, dynamic>
              ? (data['data'] is Map<String, dynamic>
                  ? data['data'] as Map<String, dynamic>
                  : data)
              : {};

      final regId = productData['registrationId']?.toString() ?? '';
      final name = productData['storeName']?.toString() ??
          productData['productName']?.toString() ??
          '';
      final stock =
          (productData['stockAvailable'] as num?)?.toInt() ?? 0;
      final soldCount = (productData['sold'] as num?)?.toInt() ?? 0;

      if (regId.isEmpty) {
        _errorMessage = 'registrationId tidak ditemukan dalam respon API';
        return;
      }

      _pangkalan = Pangkalan(
        registrationId: regId,
        storeName: name,
        stockAvailable: stock,
        sold: soldCount,
        lastTokenUpdate: DateTime.now(),
        lastSyncAt: DateTime.now(),
      );

      await _storage.saveRegistrationId(regId);
      await _storage.saveStoreName(name);
      await _firebaseService.savePangkalan(_pangkalan!);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _pangkalan = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
