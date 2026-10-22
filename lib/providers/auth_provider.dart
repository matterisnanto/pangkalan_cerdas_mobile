import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/pangkalan.dart';
import '../models/mypertamina_models.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/mypertamina_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  late final ApiClient _apiClient;
  final FirebaseService _firebaseService = FirebaseService();

  String? _token;
  Pangkalan? _pangkalan;
  bool _isLoading = false;
  bool _isStockLoading = false;
  bool _isTokenValid = false;
  String? _errorMessage;
  PangkalanProfileModel? _profile;
  int _stockRedeem = 0;
  num _price = 0;
  ProductStockModel? _latestProductStock;
  VoidCallback? onTokenExpired;

  AuthProvider() {
    _apiClient = ApiClient(_storage, onTokenExpired: clearSession);
    _loadSavedState();
  }

  void safeNotifyListeners() {
    if (!hasListeners) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) safeNotifyListeners();
    });
  }

  Future<void> savePangkalanAccount(List<Map<String, String>> accounts) async {
    await _storage.savePangkalanAccounts(jsonEncode(accounts));
    safeNotifyListeners();
  }

  String? get token => _token;
  Pangkalan? get pangkalan => _pangkalan;
  bool get isLoading => _isLoading;
  bool get isStockLoading => _isStockLoading;
  String? get errorMessage => _errorMessage;
  bool get isTokenAvailable => _token != null && _token!.isNotEmpty;
  bool get isTokenValid => _isTokenValid;
  PangkalanProfileModel? get profile => _profile;

  Future<void> clearSession() async {
    _token = null;
    _pangkalan = null;
    _profile = null;
    _isTokenValid = false;
    await _storage.clearSession();
    safeNotifyListeners();
    onTokenExpired?.call();
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final exp = payload is Map
          ? int.tryParse(payload['exp'].toString())
          : null;
      return exp == null ||
          DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return true;
    }
  }

  Future<void> checkTokenValidity() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty || _isJwtExpired(token)) {
      await clearSession();
      return;
    }
    _token = token;
    _isTokenValid = true;
    safeNotifyListeners();
  }

  String get registrationId => _pangkalan?.registrationId ?? '';
  String get storeName => _pangkalan?.storeName ?? '';
  int get stockAvailable => _pangkalan?.stockAvailable ?? 0;
  int get sold => _pangkalan?.sold ?? 0;
  int get stockRedeem => _stockRedeem;
  num get price => _price;
  ProductStockModel? get latestProductStock => _latestProductStock;
  ApiClient get apiClient => _apiClient;

  Future<ProductStockModel?> fetchProductAndStockFromApi() async {
    if (!_isTokenValid || _isStockLoading) return null;
    _isStockLoading = true;
    _errorMessage = null;
    safeNotifyListeners();
    try {
      final product = await MyPertaminaApiService(
        _apiClient,
      ).fetchProductAndStockFromApi();
      await applyProductStock(product);
      return product;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isStockLoading = false;
      safeNotifyListeners();
    }
  }

  Future<void> applyProductStock(ProductStockModel product) async {
    final current = _pangkalan;
    _latestProductStock = product;
    _stockRedeem = product.stockRedeem;
    _price = product.price;
    if (current != null) {
      current.stockAvailable = product.stockAvailable;
      current.sold = product.sold;
      current.lastSyncAt = DateTime.now();
      await _firebaseService.savePangkalan(current);
    }
    safeNotifyListeners();
  }

  Future<void> _loadSavedState() async {
    await checkTokenValidity();
    if (!_isTokenValid) return;
    final regId = await _storage.getRegistrationId();
    if (regId != null && regId.isNotEmpty) {
      _pangkalan = await _firebaseService.getPangkalan(regId);
    }
    await fetchUserProfile();
    safeNotifyListeners();
  }

  /// Called when WebView interceptor captures a Bearer token.
  Future<void> onTokenCaptured(String newToken) async {
    final token = newToken.trim();
    if (token.isEmpty) return;
    await _storage.saveToken(token);
    _token = token;
    _isTokenValid = !_isJwtExpired(token);
    safeNotifyListeners();
    if (!_isTokenValid) return;
    await Future.wait([fetchUserProfile(), fetchProductAndStockFromApi()]);
  }

  /// Fetch user profile from MyPertamina API
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    safeNotifyListeners();

    try {
      final data = await MyPertaminaApiService(_apiClient).fetchProfile();
      _profile = data;

      if (data.registrationId.isEmpty) {
        _errorMessage = 'Respon API kosong';
        return;
      }

      final regId = data.registrationId;
      final name = data.storeName;
      // Profile endpoint is the authority for active scope; stock syncs separately.
      final stock =
          _pangkalan?.stockAvailable ??
          _latestProductStock?.stockAvailable ??
          0;
      final soldCount = _pangkalan?.sold ?? _latestProductStock?.sold ?? 0;

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
      safeNotifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    safeNotifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _pangkalan = null;
    await _storage.clearAll();
    safeNotifyListeners();
  }
}
