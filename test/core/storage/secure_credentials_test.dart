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

  test('normalizes the cloud API key at the secure storage boundary', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    await credentials.writeApiKey('  compatible-secret  ');

    expect(await credentials.readApiKey(), 'compatible-secret');
  });

  test('MiMo API key uses a separate normalized secure value', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('compatible-secret');

    await credentials.writeMiMoApiKey('  mimo-secret  ');

    expect(await credentials.readMiMoApiKey(), 'mimo-secret');
    expect(await credentials.readApiKey(), 'compatible-secret');
    expect(store.values.keys, {'cloud_tts_api_key', 'mimo_tts_api_key'});

    await credentials.deleteMiMoApiKey();
    expect(await credentials.readMiMoApiKey(), isNull);
    expect(await credentials.readApiKey(), 'compatible-secret');
  });

  test('runWithMiMoApiKeyUpdate restores the previous key on failure', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeMiMoApiKey('old-secret');

    await expectLater(
      credentials.runWithMiMoApiKeyUpdate<void>(
        apiKey: 'new-secret',
        commit: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await credentials.readMiMoApiKey(), 'old-secret');
  });

  test('runWithMiMoApiKeyUpdate keeps the new key on success', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    final result = await credentials.runWithMiMoApiKeyUpdate<String>(
      apiKey: 'new-secret',
      commit: () async => 'done',
    );

    expect(result, 'done');
    expect(await credentials.readMiMoApiKey(), 'new-secret');
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
