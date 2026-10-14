import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'bearer_token';
  static const _registrationIdKey = 'registration_id';
  static const _storeNameKey = 'store_name';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> saveRegistrationId(String id) async {
    await _storage.write(key: _registrationIdKey, value: id);
  }

  Future<String?> getRegistrationId() async {
    return _storage.read(key: _registrationIdKey);
  }

  Future<void> saveStoreName(String name) async {
    await _storage.write(key: _storeNameKey, value: name);
  }

  Future<String?> getStoreName() async {
    return _storage.read(key: _storeNameKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
