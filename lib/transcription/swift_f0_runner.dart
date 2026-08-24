import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'types.dart';
import 'wav_decoder.dart';

/// Executes the upstream SwiftF0 graph: a `[1, samples]` 16 kHz mono tensor
/// producing pitch-Hz and confidence contours.
class SwiftF0Runner {
  Future<List<MidiNote>> transcribe(
    PcmAudio source,
    File model,
    TranscriptionOptions options,
  ) async {
    final audio = _resample(source, 16000);
    if (audio.samples.isEmpty) return const [];
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final session = OrtSession.fromFile(model, sessionOptions);
    final input = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(audio.samples),
      [1, audio.samples.length],
    );
    final runOptions = OrtRunOptions();
    try {
      final outputs =
          session.run(runOptions, {session.inputNames.single: input});
      if (outputs.length < 2 || outputs[0] == null || outputs[1] == null) {
        throw ModelUnavailableException(
            'SwiftF0 returned invalid output tensors.');
      }
      return _segment(
        (outputs[0]!.value as List).cast<num>(),
        (outputs[1]!.value as List).cast<num>(),
        options,
      );
    } finally {
      input.release();
      runOptions.release();
      session.release();
    }
  }

  PcmAudio _resample(PcmAudio audio, int outputRate) {
    if (audio.sampleRate == outputRate) return audio;
    final length =
        (audio.samples.length * outputRate / audio.sampleRate).round();
    return PcmAudio(
      sampleRate: outputRate,
      samples: List<double>.generate(length, (i) {
        final position = i * audio.sampleRate / outputRate;
        final lower = position.floor();
        final fraction = position - lower;
        final a = audio.samples[lower.clamp(0, audio.samples.length - 1)];
        final b = audio.samples[(lower + 1).clamp(0, audio.samples.length - 1)];
        return a + (b - a) * fraction;
      }),
    );
  }

  List<MidiNote> _segment(
    List<num> pitches,
    List<num> confidence,
    TranscriptionOptions options,
  ) {
    final notes = <MidiNote>[];
    var start = -1;
    var currentMidi = 0.0;
    var confidenceSum = 0.0;
    var count = 0;
    void finish(int end) {
      if (start < 0) return;
      const frameMicros = 16000 * 1000000 ~/ 256;
      final startTime = Duration(microseconds: start * frameMicros + 7969);
      final endTime = Duration(microseconds: end * frameMicros + 7969);
      if (endTime - startTime >= options.minimumNoteLength) {
        notes.add(MidiNote(
          start: startTime,
          end: endTime,
          pitch: currentMidi.round().clamp(0, 127).toInt(),
          confidence: confidenceSum / math.max(1, count),
        ));
      }
      start = -1;
      count = 0;
      confidenceSum = 0;
    }

    final length = math.min(pitches.length, confidence.length);
    for (var i = 0; i < length; i++) {
      final frequency = pitches[i].toDouble();
      final score = confidence[i].toDouble();
      final voiced = score >= .9 &&
          frequency >= options.minFrequency &&
          frequency <= options.maxFrequency;
      if (!voiced) {
        finish(i);
        continue;
      }
      final midi = 69 + 12 * math.log(frequency / 440) / math.ln2;
      if (start < 0 || (midi - currentMidi).abs() >= .8) {
        finish(i);
        start = i;
        currentMidi = midi;
      }
      currentMidi = currentMidi * .8 + midi * .2;
      confidenceSum += score;
      count++;
    }
    finish(length);
    return notes;
  }
}
