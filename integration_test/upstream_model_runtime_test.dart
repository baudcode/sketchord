import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sound/transcription/transcriber.dart';
import 'package:sound/transcription/types.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('executes the pinned Basic Pitch artifact on Android',
      (tester) async {
    final directory = await getTemporaryDirectory();
    final wav = File(p.join(directory.path, 'transcription_runtime_440hz.wav'));
    await wav.writeAsBytes(_pcm16Wave(
      List<double>.generate(
        22050,
        (index) => .25 * math.sin(2 * math.pi * 440 * index / 22050),
      ),
      22050,
    ));

    final transcriber = OnDeviceTranscriber();
    for (final model in const [OnDeviceModel.basicPitch]) {
      final result = await transcriber.transcribe(wav.path, model);
      expect(result.model, model);
      expect(result.notes, isNotEmpty);
      expect(result.notes.first.pitch, closeTo(69, 2));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Uint8List _pcm16Wave(List<double> samples, int sampleRate) {
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  void ascii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  ascii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(
      44 + index * 2,
      (samples[index] * 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}
