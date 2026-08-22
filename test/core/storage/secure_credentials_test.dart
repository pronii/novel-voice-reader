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

  test(
    'runWithMiMoApiKeyUpdate restores the previous key on failure',
    () async {
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
    },
  );

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

  test('runWithApiKeyUpdate restores the cloud key on failure', () async {
    final store = FakeSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('old-secret');

    await expectLater(
      credentials.runWithApiKeyUpdate<void>(
        apiKey: 'new-secret',
        commit: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await credentials.readApiKey(), 'old-secret');
  });

  test('upgradeKeychainAccessibility re-persists stored keys', () async {
    final store = RecordingSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeApiKey('cloud-secret');
    await credentials.writeMiMoApiKey('mimo-secret');
    store.writes.clear();

    await credentials.upgradeKeychainAccessibility();

    expect(store.writes, {
      'cloud_tts_api_key': 'cloud-secret',
      'mimo_tts_api_key': 'mimo-secret',
    });
  });

  test('upgradeKeychainAccessibility skips unset keys', () async {
    final store = RecordingSecureKeyValueStore();
    final credentials = SecureCredentials(store);
    await credentials.writeMiMoApiKey('mimo-secret');
    store.writes.clear();

    await credentials.upgradeKeychainAccessibility();

    expect(store.writes, {'mimo_tts_api_key': 'mimo-secret'});
  });

  test('upgradeKeychainAccessibility tolerates a locked Keychain', () async {
    final store = RecordingSecureKeyValueStore()..failReads = true;
    final credentials = SecureCredentials(store);

    await expectLater(
      credentials.upgradeKeychainAccessibility(),
      completes,
    );
  });

  test('caches the key so repeated reads skip the secure store', () async {
    final store = RecordingSecureKeyValueStore()..values['mimo_tts_api_key'] = 'k';
    final credentials = SecureCredentials(store);

    expect(await credentials.readMiMoApiKey(), 'k');
    expect(await credentials.readMiMoApiKey(), 'k');
    expect(await credentials.readMiMoApiKey(), 'k');

    // The value is fetched from the store once; later reads hit the cache.
    expect(store.reads, 1);
  });

  test('a failed read is not cached and is retried on the next call', () async {
    final store = RecordingSecureKeyValueStore()
      ..failReads = true
      ..values['mimo_tts_api_key'] = 'k';
    final credentials = SecureCredentials(store);

    await expectLater(credentials.readMiMoApiKey(), throwsException);
    store.failReads = false;

    // The transient failure was not remembered as "no key": the next read hits
    // the store again and returns the real value (locked-screen recovery).
    expect(await credentials.readMiMoApiKey(), 'k');
    expect(store.reads, 2);
  });

  test('a write updates the cache read by later lookups', () async {
    final store = RecordingSecureKeyValueStore();
    final credentials = SecureCredentials(store);

    await credentials.writeMiMoApiKey('first');
    expect(await credentials.readMiMoApiKey(), 'first');

    await credentials.writeMiMoApiKey('second');
    expect(await credentials.readMiMoApiKey(), 'second');

    // Both reads are served from the cache the writes refreshed.
    expect(store.reads, 0);
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

/// Records the writes issued during a run so a test can assert exactly which
/// keys were re-persisted, and can simulate a locked Keychain that fails reads.
final class RecordingSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  final Map<String, String> writes = {};
  int reads = 0;
  bool failReads = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    if (failReads) throw Exception('errSecInteractionNotAllowed');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    writes[key] = value;
  }
}
