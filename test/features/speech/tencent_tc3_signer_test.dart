import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tc3_signer.dart';

void main() {
  test('matches a fixed TC3-HMAC-SHA256 signature vector', () {
    final result = const TencentTc3Signer().sign(
      secretId: 'AKIDEXAMPLE',
      secretKey: 'secret-key',
      payload: '{"Text":"测试"}',
      now: DateTime.fromMillisecondsSinceEpoch(1722470400 * 1000, isUtc: true),
    );

    expect(result.timestamp, 1722470400);
    expect(result.host, 'tts.tencentcloudapi.com');
    expect(result.contentType, 'application/json; charset=utf-8');
    expect(result.signedHeaders, 'content-type;host');
    expect(
      result.authorization,
      'TC3-HMAC-SHA256 '
      'Credential=AKIDEXAMPLE/2024-08-01/tts/tc3_request, '
      'SignedHeaders=content-type;host, '
      'Signature=92cf370d809fb43e319329f729fa932baf89dd78f66b20eb060f43e1a3f9da6c',
    );
  });

  test('uses the UTC calendar date for credential scope', () {
    final localTime = DateTime.parse('2024-08-02T00:30:00+08:00');

    final result = const TencentTc3Signer().sign(
      secretId: 'id',
      secretKey: 'key',
      payload: '{}',
      now: localTime,
    );

    expect(result.authorization, contains('Credential=id/2024-08-01/tts/'));
  });
}
