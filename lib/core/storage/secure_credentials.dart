import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

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

  Future<String?> readApiKey() => _storage.read(_apiKeyKey);

  Future<void> writeApiKey(String value) =>
      _storage.write(_apiKeyKey, value.trim());

  Future<void> deleteApiKey() => _storage.delete(_apiKeyKey);

  Future<String?> readMiMoApiKey() => _storage.read(_mimoApiKeyKey);

  Future<void> writeMiMoApiKey(String value) =>
      _storage.write(_mimoApiKeyKey, value.trim());

  Future<void> deleteMiMoApiKey() => _storage.delete(_mimoApiKeyKey);

  Future<T> runWithMiMoApiKeyUpdate<T>({
    required String? apiKey,
    required Future<T> Function() commit,
  }) async {
    if (apiKey == null) {
      return commit();
    }

    final previousApiKey = await readMiMoApiKey();
    var wroteApiKey = false;
    try {
      await writeMiMoApiKey(apiKey);
      wroteApiKey = true;
      return await commit();
    } catch (error, stackTrace) {
      if (wroteApiKey) {
        if (previousApiKey == null) {
          await deleteMiMoApiKey();
        } else {
          await writeMiMoApiKey(previousApiKey);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
