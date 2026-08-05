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
  static const _azureSubscriptionKeyKey = 'azure_tts_subscription_key';
  static const _zhipuApiKeyKey = 'zhipu_tts_api_key';
  static const _tencentSecretIdKey = 'tencent_tts_secret_id';
  static const _tencentSecretKeyKey = 'tencent_tts_secret_key';
  static const _mimoApiKeyKey = 'mimo_tts_api_key';

  final SecureKeyValueStore _storage;

  Future<String?> readApiKey() => _storage.read(_apiKeyKey);

  Future<void> writeApiKey(String value) =>
      _storage.write(_apiKeyKey, value.trim());

  Future<void> deleteApiKey() => _storage.delete(_apiKeyKey);

  Future<String?> readAzureSubscriptionKey() =>
      _storage.read(_azureSubscriptionKeyKey);

  Future<void> writeAzureSubscriptionKey(String value) =>
      _storage.write(_azureSubscriptionKeyKey, value.trim());

  Future<void> deleteAzureSubscriptionKey() =>
      _storage.delete(_azureSubscriptionKeyKey);

  Future<String?> readZhipuApiKey() => _storage.read(_zhipuApiKeyKey);

  Future<void> writeZhipuApiKey(String value) =>
      _storage.write(_zhipuApiKeyKey, value.trim());

  Future<void> deleteZhipuApiKey() => _storage.delete(_zhipuApiKeyKey);

  Future<String?> readTencentSecretId() => _storage.read(_tencentSecretIdKey);

  Future<void> writeTencentSecretId(String value) =>
      _storage.write(_tencentSecretIdKey, value.trim());

  Future<void> deleteTencentSecretId() => _storage.delete(_tencentSecretIdKey);

  Future<String?> readTencentSecretKey() => _storage.read(_tencentSecretKeyKey);

  Future<void> writeTencentSecretKey(String value) =>
      _storage.write(_tencentSecretKeyKey, value.trim());

  Future<void> deleteTencentSecretKey() =>
      _storage.delete(_tencentSecretKeyKey);

  Future<String?> readMiMoApiKey() => _storage.read(_mimoApiKeyKey);

  Future<void> writeMiMoApiKey(String value) =>
      _storage.write(_mimoApiKeyKey, value.trim());

  Future<void> deleteMiMoApiKey() => _storage.delete(_mimoApiKeyKey);

  Future<T> runWithTencentCredentialUpdate<T>({
    required String? secretId,
    required String? secretKey,
    required Future<T> Function() commit,
  }) async {
    if (secretId == null && secretKey == null) {
      return commit();
    }

    final previousSecretId = await readTencentSecretId();
    final previousSecretKey = await readTencentSecretKey();
    var wroteSecretId = false;
    var wroteSecretKey = false;
    try {
      if (secretId != null) {
        await writeTencentSecretId(secretId);
        wroteSecretId = true;
      }
      if (secretKey != null) {
        await writeTencentSecretKey(secretKey);
        wroteSecretKey = true;
      }
      return await commit();
    } catch (error, stackTrace) {
      await _restoreTencentCredentials(
        secretId: previousSecretId,
        secretKey: previousSecretKey,
        restoreSecretId: wroteSecretId,
        restoreSecretKey: wroteSecretKey,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _restoreTencentCredentials({
    required String? secretId,
    required String? secretKey,
    required bool restoreSecretId,
    required bool restoreSecretKey,
  }) async {
    Object? rollbackError;
    StackTrace? rollbackStackTrace;

    Future<void> restore(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        rollbackError ??= error;
        rollbackStackTrace ??= stackTrace;
      }
    }

    if (restoreSecretKey) {
      await restore(
        () => secretKey == null
            ? deleteTencentSecretKey()
            : writeTencentSecretKey(secretKey),
      );
    }
    if (restoreSecretId) {
      await restore(
        () => secretId == null
            ? deleteTencentSecretId()
            : writeTencentSecretId(secretId),
      );
    }
    if (rollbackError != null) {
      Error.throwWithStackTrace(rollbackError!, rollbackStackTrace!);
    }
  }
}
