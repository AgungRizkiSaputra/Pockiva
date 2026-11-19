import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over encrypted platform key-value storage (Android Keystore / iOS Keychain).
abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Keys stored in encrypted local storage. Never store plaintext PINs!
class SecureStorageKeys {
  const SecureStorageKeys._();

  static const String lastActivityEpochMs = 'sec_last_activity_ms';
  static const String offlineQueueJson = 'sec_offline_tx_queue';
  static const String cachedTransactionsJson = 'sec_cached_transactions';
  static const String cachedProfileJson = 'sec_cached_profile';
  static const String cachedStreakJson = 'sec_cached_streak';
  static const String cachedBadgesJson = 'sec_cached_badges';
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageService();
});
