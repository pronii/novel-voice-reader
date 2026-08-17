import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/data/buffered_playback_telemetry.dart';

void main() {
  test('attaches the shared-secret token header when configured', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final uploader = DioTelemetryUploader(dio, token: 'sekret');

    final ok = await uploader.upload('https://collector.example/nvr/collect', [
      {'seq': 0, 'name': 'e'},
    ]);

    expect(ok, isTrue);
    expect(adapter.lastHeaders['X-Telemetry-Token'], 'sekret');
  });

  test('omits the token header when none is configured', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final uploader = DioTelemetryUploader(dio);

    await uploader.upload('https://collector.example/nvr/collect', [
      {'seq': 0, 'name': 'e'},
    ]);

    expect(adapter.lastHeaders.containsKey('X-Telemetry-Token'), isFalse);
  });

  test('treats a non-2xx response as a rejected batch', () async {
    final adapter = _CapturingAdapter(status: 401);
    final dio = Dio()..httpClientAdapter = adapter;
    final uploader = DioTelemetryUploader(dio, token: 'sekret');

    final ok = await uploader.upload('https://collector.example/nvr/collect', [
      {'seq': 0, 'name': 'e'},
    ]);

    expect(ok, isFalse);
  });
}

final class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({this.status = 200});

  final int status;
  Map<String, dynamic> lastHeaders = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = options.headers;
    return ResponseBody.fromString('{"ok":true}', status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
