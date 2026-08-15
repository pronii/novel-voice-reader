import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';

void main() {
  test('builds a valid silent PCM WAV of the requested duration', () {
    final bytes = buildSilenceWav(const Duration(seconds: 1));

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');

    final view = ByteData.sublistView(bytes);
    expect(view.getUint16(20, Endian.little), 1); // PCM
    expect(view.getUint16(22, Endian.little), 1); // mono
    expect(view.getUint32(24, Endian.little), 8000); // sample rate
    expect(view.getUint16(34, Endian.little), 16); // bits per sample

    // 1 second of 8 kHz mono 16-bit silence == 16000 payload bytes, all zero.
    const expectedPayload = 8000 * 2;
    expect(view.getUint32(40, Endian.little), expectedPayload);
    expect(bytes.length, 44 + expectedPayload);
    expect(bytes.sublist(44).every((byte) => byte == 0), isTrue);
  });
}
