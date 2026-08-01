import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';

void main() {
  test('API key round-trips only through secure storage', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    await credentials.writeApiKey('secret');

    expect(await credentials.readApiKey(), 'secret');
    expect(store.values.keys, ['cloud_tts_api_key']);
  });

  test('deleting the API key removes the secure value', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('secret');

    await credentials.deleteApiKey();

    expect(await credentials.readApiKey(), isNull);
  });

  test('Azure subscription key uses a separate secure value', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('compatible-secret');

    await credentials.writeAzureSubscriptionKey('azure-secret');

    expect(await credentials.readApiKey(), 'compatible-secret');
    expect(await credentials.readAzureSubscriptionKey(), 'azure-secret');
    expect(store.values.keys, {
      'cloud_tts_api_key',
      'azure_tts_subscription_key',
    });

    await credentials.deleteAzureSubscriptionKey();

    expect(await credentials.readAzureSubscriptionKey(), isNull);
    expect(await credentials.readApiKey(), 'compatible-secret');
  });

  test('Zhipu API key uses a separate secure value', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('compatible-secret');
    await credentials.writeAzureSubscriptionKey('azure-secret');

    await credentials.writeZhipuApiKey('zhipu-secret');

    expect(await credentials.readZhipuApiKey(), 'zhipu-secret');
    expect(await credentials.readApiKey(), 'compatible-secret');
    expect(await credentials.readAzureSubscriptionKey(), 'azure-secret');
    expect(store.values.keys, {
      'cloud_tts_api_key',
      'azure_tts_subscription_key',
      'zhipu_tts_api_key',
    });

    await credentials.deleteZhipuApiKey();

    expect(await credentials.readZhipuApiKey(), isNull);
    expect(await credentials.readApiKey(), 'compatible-secret');
    expect(await credentials.readAzureSubscriptionKey(), 'azure-secret');
  });

  test('normalizes cloud credentials at the secure storage boundary', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    await credentials.writeApiKey('  compatible-secret  ');
    await credentials.writeAzureSubscriptionKey('  azure-secret  ');
    await credentials.writeZhipuApiKey('  zhipu-secret  ');

    expect(await credentials.readApiKey(), 'compatible-secret');
    expect(await credentials.readAzureSubscriptionKey(), 'azure-secret');
    expect(await credentials.readZhipuApiKey(), 'zhipu-secret');
  });

  test('Tencent credentials use separate secure values', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    await credentials.writeTencentSecretId('  tencent-id  ');
    await credentials.writeTencentSecretKey('  tencent-key  ');

    expect(await credentials.readTencentSecretId(), 'tencent-id');
    expect(await credentials.readTencentSecretKey(), 'tencent-key');
    expect(store.values.keys, {
      'tencent_tts_secret_id',
      'tencent_tts_secret_key',
    });

    await credentials.deleteTencentSecretId();

    expect(await credentials.readTencentSecretId(), isNull);
    expect(await credentials.readTencentSecretKey(), 'tencent-key');

    await credentials.deleteTencentSecretKey();
    expect(await credentials.readTencentSecretKey(), isNull);
  });
}

final class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
