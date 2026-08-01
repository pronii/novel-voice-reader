import 'dart:convert';

import 'package:crypto/crypto.dart';

final class TencentTc3Signature {
  const TencentTc3Signature({
    required this.authorization,
    required this.timestamp,
    required this.host,
    required this.contentType,
    required this.signedHeaders,
  });

  final String authorization;
  final int timestamp;
  final String host;
  final String contentType;
  final String signedHeaders;
}

final class TencentTc3Signer {
  const TencentTc3Signer();

  static const host = 'tts.tencentcloudapi.com';
  static const service = 'tts';
  static const contentType = 'application/json; charset=utf-8';
  static const signedHeaders = 'content-type;host';

  TencentTc3Signature sign({
    required String secretId,
    required String secretKey,
    required String payload,
    required DateTime now,
  }) {
    final timestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final date = _utcDate(now);
    final canonicalHeaders =
        'content-type:$contentType\n'
        'host:$host\n';
    final canonicalRequest = [
      'POST',
      '/',
      '',
      canonicalHeaders,
      signedHeaders,
      _sha256Hex(payload),
    ].join('\n');
    final credentialScope = '$date/$service/tc3_request';
    final stringToSign = [
      'TC3-HMAC-SHA256',
      timestamp,
      credentialScope,
      _sha256Hex(canonicalRequest),
    ].join('\n');
    final secretDate = _hmac(utf8.encode('TC3$secretKey'), date);
    final secretService = _hmac(secretDate, service);
    final secretSigning = _hmac(secretService, 'tc3_request');
    final signature = _hex(_hmac(secretSigning, stringToSign));
    return TencentTc3Signature(
      authorization:
          'TC3-HMAC-SHA256 '
          'Credential=$secretId/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature',
      timestamp: timestamp,
      host: host,
      contentType: contentType,
      signedHeaders: signedHeaders,
    );
  }

  static String _utcDate(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  static String _sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static List<int> _hmac(List<int> key, String value) {
    return Hmac(sha256, key).convert(utf8.encode(value)).bytes;
  }

  static String _hex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
