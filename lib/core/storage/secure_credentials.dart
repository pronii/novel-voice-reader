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

  // In-memory cache of the last known value for each key. Synthesis reads the
  // API key once for every segment it renders; on a locked screen each read is
  // a Keychain platform-channel round-trip (slow, and prone to -25308 before
  // the first unlock). Every write in the process goes through this instance,
  // so caching successful reads and refreshing the entry on each write/delete
  // keeps the cache coherent without ever handing back a stale key. Only
  // successful reads are cached, so a transient locked-screen read failure is
  // retried on the next call instead of being remembered as "no key".
  final Map<String, String?> _cache = {};

  Future<String?> _read(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final value = await _storage.read(key);
    _cache[key] = value;
    return value;
  }

  Future<void> _write(String key, String value) async {
    await _storage.write(key, value);
    _cache[key] = value;
  }

  Future<void> _delete(String key) async {
    await _storage.delete(key);
    _cache[key] = null;
  }

  /// Re-persists stored API keys so they adopt the store's current Keychain
  /// accessibility. Installs from before the accessibility fix wrote keys with
  /// the SDK default (`whenUnlocked`), which fails background reads on a locked
  /// screen (-25308). Reading each key while the app is foregrounded (unlocked)
  /// and writing it back upgrades it to `afterFirstUnlock`. Best-effort and
  /// idempotent, so it is safe to call on every launch.
  Future<void> upgradeKeychainAccessibility() async {
    for (final key in const [_apiKeyKey, _mimoApiKeyKey]) {
      try {
        final value = await _read(key);
        if (value != null && value.isNotEmpty) {
          await _write(key, value);
        }
      } catch (_) {
        // Device still locked at launch, or a transient Keychain error: leave
        // the key for a later launch (or a manual re-save) to upgrade.
      }
    }
  }

  Future<String?> readApiKey() => _read(_apiKeyKey);

  Future<void> writeApiKey(String value) => _write(_apiKeyKey, value.trim());

  Future<void> deleteApiKey() => _delete(_apiKeyKey);

  Future<T> runWithApiKeyUpdate<T>({
    required String? apiKey,
    required Future<T> Function() commit,
  }) {
    return _runWithKeyUpdate(key: _apiKeyKey, value: apiKey, commit: commit);
  }

  Future<String?> readMiMoApiKey() => _read(_mimoApiKeyKey);

  Future<void> writeMiMoApiKey(String value) =>
      _write(_mimoApiKeyKey, value.trim());

  Future<void> deleteMiMoApiKey() => _delete(_mimoApiKeyKey);

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
    final previous = await _read(key);
    var wroteValue = false;
    try {
      await _write(key, normalizedValue);
      wroteValue = true;
      return await commit();
    } catch (error, stackTrace) {
      if (wroteValue) {
        if (previous == null) {
          await _delete(key);
        } else {
          await _write(key, previous);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
