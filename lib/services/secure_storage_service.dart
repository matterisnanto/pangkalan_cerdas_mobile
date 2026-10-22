import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'bearer_token';
  static const _registrationIdKey = 'registration_id';
  static const _storeNameKey = 'store_name';
  static const _delayKey = 'transaction_delay_seconds';
  static const pangkalanAccountsKey = 'pangkalan_accounts_json';

  Future<String?> readPangkalanAccounts() =>
      _storage.read(key: pangkalanAccountsKey);

  Future<void> savePangkalanAccounts(String json) =>
      _storage.write(key: pangkalanAccountsKey, value: json);
  static const _profilePrefix = 'pangkalan_profile_';

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

  Future<void> saveTransactionDelay(int seconds) async {
    await _storage.write(key: _delayKey, value: seconds.toString());
  }

  Future<int> getTransactionDelay() async {
    final value = await _storage.read(key: _delayKey);
    return int.tryParse(value ?? '')?.clamp(2, 5) ?? 3;
  }

  Future<void> savePangkalanProfile(
    int index, {
    required String id,
    required String name,
  }) async {
    await _storage.write(key: '$_profilePrefix${index}_id', value: id);
    await _storage.write(key: '$_profilePrefix${index}_name', value: name);
  }

  Future<Map<String, String>> getPangkalanProfile(int index) async => {
    'id': await _storage.read(key: '$_profilePrefix${index}_id') ?? '',
    'name': await _storage.read(key: '$_profilePrefix${index}_name') ?? '',
  };

  Future<void> clearSession() async {
    await Future.wait([
      deleteToken(),
      _storage.delete(key: _registrationIdKey),
      _storage.delete(key: _storeNameKey),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
