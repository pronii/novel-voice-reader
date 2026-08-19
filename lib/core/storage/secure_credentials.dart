import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? _defaultStorage;

  /// iOS Keychain items default to `kSecAttrAccessibleWhenUnlocked`, so reading
  /// a stored key while the screen is locked throws `errSecInteractionNotAllowed`
  /// (-25308). Background playback synthesizes the next segment on a locked
  /// screen and must read the API key, so persist with `first_unlock`
  /// (`kSecAttrAccessibleAfterFirstUnlock`): readable once the device has been
  /// unlocked at least once since boot, including while it is locked again.
  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class SecureCredentials {
  SecureCredentials(this._storage);

  static const _apiKeyKey = 'cloud_tts_api_key';
  static const _mimoApiKeyKey = 'mimo_tts_api_key';

  final SecureKeyValueStore _storage;

  /// Re-persists stored API keys so they adopt the store's current Keychain
  /// accessibility. Installs from before the accessibility fix wrote keys with
  /// the SDK default (`whenUnlocked`), which fails background reads on a locked
  /// screen (-25308). Reading each key while the app is foregrounded (unlocked)
  /// and writing it back upgrades it to `afterFirstUnlock`. Best-effort and
  /// idempotent, so it is safe to call on every launch.
  Future<void> upgradeKeychainAccessibility() async {
    for (final key in const [_apiKeyKey, _mimoApiKeyKey]) {
      try {
        final value = await _storage.read(key);
        if (value != null && value.isNotEmpty) {
          await _storage.write(key, value);
        }
      } catch (_) {
        // Device still locked at launch, or a transient Keychain error: leave
        // the key for a later launch (or a manual re-save) to upgrade.
      }
    }
  }

  Future<String?> readApiKey() => _storage.read(_apiKeyKey);

  Future<void> writeApiKey(String value) =>
      _storage.write(_apiKeyKey, value.trim());

  Future<void> deleteApiKey() => _storage.delete(_apiKeyKey);

  Future<T> runWithApiKeyUpdate<T>({
    required String? apiKey,
    required Future<T> Function() commit,
  }) {
    return _runWithKeyUpdate(key: _apiKeyKey, value: apiKey, commit: commit);
  }

  Future<String?> readMiMoApiKey() => _storage.read(_mimoApiKeyKey);

  Future<void> writeMiMoApiKey(String value) =>
      _storage.write(_mimoApiKeyKey, value.trim());

  Future<void> deleteMiMoApiKey() => _storage.delete(_mimoApiKeyKey);

  Future<T> runWithMiMoApiKeyUpdate<T>({
    required String? apiKey,
    required Future<T> Function() commit,
  }) {
    return _runWithKeyUpdate(
      key: _mimoApiKeyKey,
      value: apiKey,
      commit: commit,
    );
  }

  Future<T> _runWithKeyUpdate<T>({
    required String key,
    required String? value,
    required Future<T> Function() commit,
  }) async {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) return commit();
    final previous = await _storage.read(key);
    var wroteValue = false;
    try {
      await _storage.write(key, normalizedValue);
      wroteValue = true;
      return await commit();
    } catch (error, stackTrace) {
      if (wroteValue) {
        if (previous == null) {
          await _storage.delete(key);
        } else {
          await _storage.write(key, previous);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
