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
