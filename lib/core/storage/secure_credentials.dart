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

  final SecureKeyValueStore _storage;

  Future<String?> readApiKey() => _storage.read(_apiKeyKey);

  Future<void> writeApiKey(String value) => _storage.write(_apiKeyKey, value);

  Future<void> deleteApiKey() => _storage.delete(_apiKeyKey);

  Future<String?> readAzureSubscriptionKey() =>
      _storage.read(_azureSubscriptionKeyKey);

  Future<void> writeAzureSubscriptionKey(String value) =>
      _storage.write(_azureSubscriptionKeyKey, value);

  Future<void> deleteAzureSubscriptionKey() =>
      _storage.delete(_azureSubscriptionKeyKey);

  Future<String?> readZhipuApiKey() => _storage.read(_zhipuApiKeyKey);

  Future<void> writeZhipuApiKey(String value) =>
      _storage.write(_zhipuApiKeyKey, value);

  Future<void> deleteZhipuApiKey() => _storage.delete(_zhipuApiKeyKey);
}
