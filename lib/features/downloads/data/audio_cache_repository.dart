import 'dart:io';
import 'dart:typed_data';

import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class CloudSpeechSynthesizer {
  Future<Uint8List> synthesize(SpeechSegment segment, VoiceProfile profile);
}

final class AudioCacheRepository {
  const AudioCacheRepository({
    required this.directory,
    required this.synthesizer,
  });

  final Directory directory;
  final CloudSpeechSynthesizer synthesizer;

  Future<File> obtain(SpeechSegment segment, VoiceProfile profile) async {
    await directory.create(recursive: true);
    final key = CacheKey.forSegment(segment, profile);
    final extension = _normalizedExtension(profile.outputFormat);
    final finalFile = File(
      '${directory.path}${Platform.pathSeparator}$key.$extension',
    );
    if (await finalFile.exists()) {
      return finalFile;
    }

    final partial = File('${finalFile.path}.partial');
    if (await partial.exists()) {
      await partial.delete();
    }

    try {
      final bytes = await synthesizer.synthesize(segment, profile);
      _validateAudio(bytes, extension);
      await partial.writeAsBytes(bytes, flush: true);
      return await partial.rename(finalFile.path);
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
  }

  static String _normalizedExtension(String? outputFormat) {
    final extension = (outputFormat ?? 'mp3').trim().toLowerCase();
    if (extension.endsWith('-mp3')) {
      return 'mp3';
    }
    const supported = {'mp3', 'opus', 'aac', 'flac', 'wav', 'pcm', 'ogg'};
    if (!supported.contains(extension)) {
      throw ArgumentError.value(
        outputFormat,
        'outputFormat',
        'Unsupported audio format.',
      );
    }
    return extension;
  }

  static void _validateAudio(Uint8List bytes, String extension) {
    final valid = switch (extension) {
      'mp3' =>
        _startsWith(bytes, const [0x49, 0x44, 0x33]) ||
            (bytes.length >= 2 &&
                bytes[0] == 0xff &&
                (bytes[1] & 0xe0) == 0xe0),
      'wav' =>
        bytes.length >= 12 &&
            _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
            _startsWith(bytes, const [0x57, 0x41, 0x56, 0x45], offset: 8),
      'opus' || 'ogg' => _startsWith(bytes, const [0x4f, 0x67, 0x67, 0x53]),
      'flac' => _startsWith(bytes, const [0x66, 0x4c, 0x61, 0x43]),
      'aac' =>
        bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xf6) == 0xf0,
      'pcm' => bytes.isNotEmpty && bytes.length.isEven,
      _ => false,
    };
    if (!valid) {
      throw FormatException('Cloud TTS returned invalid $extension audio.');
    }
  }

  static bool _startsWith(
    Uint8List bytes,
    List<int> signature, {
    int offset = 0,
  }) {
    if (bytes.length < offset + signature.length) {
      return false;
    }
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) {
        return false;
      }
    }
    return true;
  }
}
