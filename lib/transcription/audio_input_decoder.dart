import 'dart:io';

import 'package:flutter/services.dart';

import 'types.dart';
import 'wav_decoder.dart';

/// Decodes WAV directly and asks the platform media stack to turn compressed
/// recordings (AAC/M4A/MP3) into a temporary PCM WAV when necessary.
///
/// This keeps every model runner on the same, deterministic mono/multichannel
/// PCM input without shipping a second audio decoder in Dart.
class AudioInputDecoder {
  AudioInputDecoder({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('de.onenightproductions.sketchord/audio_input');

  final MethodChannel _channel;

  Future<PcmAudio> decode(String audioPath) async {
    final source = File(audioPath);
    try {
      return WavDecoder.decode(await source.readAsBytes());
    } on FormatException {
      // Recorder uses AAC/M4A on iOS, and imported clips can also be
      // compressed. Native platform decoders support those formats directly.
      final converted = await _channel.invokeMethod<String>('decodeToWav', {
        'audioPath': audioPath,
      });
      if (converted == null || converted.isEmpty) {
        throw ModelUnavailableException(
            'This audio format could not be decoded for transcription.');
      }
      return WavDecoder.decode(await File(converted).readAsBytes());
    }
  }
}
