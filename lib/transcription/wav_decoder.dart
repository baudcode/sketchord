import 'dart:typed_data';

class PcmAudio {
  const PcmAudio({required this.sampleRate, required this.samples});

  final int sampleRate;
  final List<double> samples;
}

/// Small, dependency-free WAV decoder for recorded/imported PCM audio.
/// It intentionally rejects compressed WAV and AAC/M4A: neural runners on the
/// native side may decode those formats, while this offline fallback must not
/// silently analyse bytes as PCM.
class WavDecoder {
  static PcmAudio decode(Uint8List bytes) {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Only uncompressed WAV audio is supported.');
    }

    final data = ByteData.sublistView(bytes);
    int? format;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    Uint8List? pcm;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset, 4);
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + size > bytes.length) {
        throw const FormatException('Invalid WAV chunk length.');
      }
      if (id == 'fmt ' && size >= 16) {
        format = data.getUint16(start, Endian.little);
        channels = data.getUint16(start + 2, Endian.little);
        sampleRate = data.getUint32(start + 4, Endian.little);
        bitsPerSample = data.getUint16(start + 14, Endian.little);
      } else if (id == 'data') {
        pcm = Uint8List.sublistView(bytes, start, start + size);
      }
      offset = start + size + (size.isOdd ? 1 : 0);
    }

    if (format == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        pcm == null) {
      throw const FormatException('WAV is missing a fmt or data chunk.');
    }
    if (channels < 1 || (format != 1 && format != 3)) {
      throw const FormatException(
          'WAV must contain PCM or IEEE float samples.');
    }
    final bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample < 1 || pcm.length % (bytesPerSample * channels) != 0) {
      throw const FormatException('Invalid WAV sample layout.');
    }
    final frameCount = pcm.length ~/ (bytesPerSample * channels);
    final source = ByteData.sublistView(pcm);
    final samples = List<double>.filled(frameCount, 0);
    for (var frame = 0; frame < frameCount; frame++) {
      var mixed = 0.0;
      for (var channel = 0; channel < channels; channel++) {
        final position = (frame * channels + channel) * bytesPerSample;
        mixed += _sample(source, position, format, bitsPerSample);
      }
      samples[frame] = mixed / channels;
    }
    return PcmAudio(sampleRate: sampleRate, samples: samples);
  }

  static String _ascii(Uint8List bytes, int start, int length) =>
      String.fromCharCodes(bytes.sublist(start, start + length));

  static double _sample(ByteData data, int offset, int format, int bits) {
    if (format == 3 && bits == 32)
      return data.getFloat32(offset, Endian.little);
    if (format != 1) {
      throw const FormatException(
          'Only 32-bit float WAV is supported for IEEE float.');
    }
    switch (bits) {
      case 8:
        return (data.getUint8(offset) - 128) / 128;
      case 16:
        return data.getInt16(offset, Endian.little) / 32768;
      case 24:
        final value = data.getUint8(offset) |
            (data.getUint8(offset + 1) << 8) |
            (data.getUint8(offset + 2) << 16);
        final signed = value & 0x800000 != 0 ? value - 0x1000000 : value;
        return signed / 8388608;
      case 32:
        return data.getInt32(offset, Endian.little) / 2147483648;
      default:
        throw const FormatException('Unsupported PCM bit depth.');
    }
  }
}
