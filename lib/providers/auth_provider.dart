import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pangkalan.dart';
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
  bool _isTokenValid = false;
  String? _errorMessage;
  VoidCallback? onTokenExpired;

  AuthProvider() {
    _apiClient = ApiClient(_storage, onTokenExpired: clearSession);
    _loadSavedState();
  }

  String? get token => _token;
  Pangkalan? get pangkalan => _pangkalan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTokenAvailable => _token != null && _token!.isNotEmpty;
  bool get isTokenValid => _isTokenValid;

  Future<void> clearSession() async {
    _token = null;
    _pangkalan = null;
    _isTokenValid = false;
    await _storage.clearSession();
    notifyListeners();
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
    notifyListeners();
  }

  String get registrationId => _pangkalan?.registrationId ?? '';
  String get storeName => _pangkalan?.storeName ?? '';
  int get stockAvailable => _pangkalan?.stockAvailable ?? 0;
  ApiClient get apiClient => _apiClient;

  Future<void> _loadSavedState() async {
    await checkTokenValidity();
    if (!_isTokenValid) return;
    final regId = await _storage.getRegistrationId();
    if (regId != null && regId.isNotEmpty) {
      _pangkalan = await _firebaseService.getPangkalan(regId);
    }
    notifyListeners();
  }

  /// Called when WebView interceptor captures a Bearer token
  Future<void> onTokenCaptured(String newToken) async {
    await _storage.saveToken(newToken);
    await checkTokenValidity();
    if (!_isTokenValid) return;
    await fetchUserProfile();
  }

  /// Fetch user profile from MyPertamina API
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await MyPertaminaApiService(_apiClient).fetchProfile();

      if (data.registrationId.isEmpty) {
        _errorMessage = 'Respon API kosong';
        return;
      }

      final regId = data.registrationId;
      final name = data.storeName;
      // Profile endpoint is the authority for active scope; stock syncs separately.
      const stock = 0;
      const soldCount = 0;

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
