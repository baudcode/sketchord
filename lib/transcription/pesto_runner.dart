import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'types.dart';
import 'wav_decoder.dart';

/// The exact streaming graph produced by `tool/export_pesto_onnx.sh`.
///
/// PESTO's ONNX graph has a fixed sample rate, chunk length and recurrent
/// convolution-cache length.  A model built with different values must use a
/// matching profile; it is intentionally not guessed at runtime because the
/// ONNX Runtime Dart binding does not expose input tensor dimensions.
class PestoModelProfile {
  const PestoModelProfile({
    required this.sampleRate,
    required this.chunkSize,
    required this.cacheLength,
    this.confidenceThreshold = .5,
  })  : assert(sampleRate > 0),
        assert(chunkSize > 0),
        assert(cacheLength >= 0),
        assert(confidenceThreshold >= 0 && confidenceThreshold <= 1);

  static const mir1kG7_44100_1024 = PestoModelProfile(
    sampleRate: 44100,
    chunkSize: 1024,
    cacheLength: 3584,
  );

  final int sampleRate;
  final int chunkSize;
  final int cacheLength;
  final double confidenceThreshold;
}

/// Runs PESTO's official streaming ONNX export one chunk at a time.
///
/// PESTO is an F0 model, so [PestoNoteSegmenter] turns its semitone contour
/// into MIDI notes.  Keep this separate from the model graph: users can tune
/// its note boundary policy without replacing a downloaded model.
class PestoRunner {
  Future<List<MidiNote>> transcribe(
    PcmAudio source,
    File model,
    TranscriptionOptions options, {
    PestoModelProfile profile = PestoModelProfile.mir1kG7_44100_1024,
  }) async {
    if (!await model.exists()) {
      throw ModelUnavailableException('The downloaded PESTO model is missing.');
    }
    final audio = _resample(source, profile.sampleRate);
    if (audio.samples.isEmpty) return const [];

    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final session = OrtSession.fromFile(model, sessionOptions);
    final audioInputName = _requireName(session.inputNames, 'audio');
    final cacheInputName = _requireName(session.inputNames, 'cache');
    final predictionIndex = _requireIndex(session.outputNames, 'prediction');
    final confidenceIndex = _requireIndex(session.outputNames, 'confidence');
    final cacheIndex = _requireIndex(session.outputNames, 'cache_out');
    var cache = Float32List(profile.cacheLength);
    final semitones = <double>[];
    final confidence = <double>[];

    try {
      for (var offset = 0;
          offset < audio.samples.length;
          offset += profile.chunkSize) {
        final chunk = Float32List(profile.chunkSize);
        final available =
            math.min(profile.chunkSize, audio.samples.length - offset);
        for (var i = 0; i < available; i++) {
          chunk[i] = audio.samples[offset + i];
        }
        final audioTensor = OrtValueTensor.createTensorWithDataList(
          chunk,
          [1, profile.chunkSize],
        );
        final cacheTensor = OrtValueTensor.createTensorWithDataList(
          cache,
          [1, profile.cacheLength],
        );
        final runOptions = OrtRunOptions();
        List<OrtValue?>? outputs;
        try {
          outputs = session.run(runOptions, {
            audioInputName: audioTensor,
            cacheInputName: cacheTensor,
          });
          if (outputs.length <= cacheIndex ||
              outputs[predictionIndex] == null ||
              outputs[confidenceIndex] == null ||
              outputs[cacheIndex] == null) {
            throw ModelUnavailableException(
                'PESTO returned incomplete output tensors.');
          }
          semitones.addAll(_numbers(outputs[predictionIndex]!.value));
          confidence.addAll(_numbers(outputs[confidenceIndex]!.value));
          final nextCache = _numbers(outputs[cacheIndex]!.value);
          if (nextCache.length != profile.cacheLength) {
            throw ModelUnavailableException(
              'PESTO cache shape does not match this model profile. '
              'Expected ${profile.cacheLength}, got ${nextCache.length}.',
            );
          }
          cache = Float32List.fromList(nextCache);
        } finally {
          for (final output in outputs ?? const <OrtValue?>[]) {
            output?.release();
          }
          audioTensor.release();
          cacheTensor.release();
          runOptions.release();
        }
      }
      return PestoNoteSegmenter.segment(
        semitones: semitones,
        confidence: confidence,
        profile: profile,
        options: options,
      );
    } finally {
      session.release();
      sessionOptions.release();
    }
  }

  PcmAudio _resample(PcmAudio audio, int outputRate) {
    if (audio.sampleRate == outputRate) return audio;
    final length =
        (audio.samples.length * outputRate / audio.sampleRate).round();
    return PcmAudio(
      sampleRate: outputRate,
      samples: List<double>.generate(length, (index) {
        final position = index * audio.sampleRate / outputRate;
        final lower = position.floor();
        final fraction = position - lower;
        final a = audio.samples[lower.clamp(0, audio.samples.length - 1)];
        final b = audio.samples[(lower + 1).clamp(0, audio.samples.length - 1)];
        return a + (b - a) * fraction;
      }),
    );
  }
}

/// Conservative contour-to-note conversion for the F0-only PESTO model.
class PestoNoteSegmenter {
  static List<MidiNote> segment({
    required List<double> semitones,
    required List<double> confidence,
    required PestoModelProfile profile,
    required TranscriptionOptions options,
  }) {
    final notes = <MidiNote>[];
    final count = math.min(semitones.length, confidence.length);
    final frameMicros = (profile.chunkSize *
            Duration.microsecondsPerSecond /
            profile.sampleRate)
        .round();
    var start = -1;
    var currentPitch = 0.0;
    var confidenceSum = 0.0;
    var voicedFrames = 0;

    void finish(int end) {
      if (start < 0) return;
      final noteStart = Duration(microseconds: start * frameMicros);
      final noteEnd = Duration(microseconds: end * frameMicros);
      if (noteEnd - noteStart >= options.minimumNoteLength) {
        notes.add(MidiNote(
          start: noteStart,
          end: noteEnd,
          pitch: currentPitch.round().clamp(0, 127).toInt(),
          confidence: confidenceSum / math.max(1, voicedFrames),
        ));
      }
      start = -1;
      confidenceSum = 0;
      voicedFrames = 0;
    }

    for (var frame = 0; frame < count; frame++) {
      final pitch = semitones[frame];
      final score = confidence[frame];
      final frequency = 440 * math.pow(2, (pitch - 69) / 12).toDouble();
      final voiced = score >= profile.confidenceThreshold &&
          frequency >= options.minFrequency &&
          frequency <= options.maxFrequency;
      if (!voiced) {
        finish(frame);
        continue;
      }
      if (start < 0 || (pitch - currentPitch).abs() >= .8) {
        finish(frame);
        start = frame;
        currentPitch = pitch;
      }
      currentPitch = currentPitch * .8 + pitch * .2;
      confidenceSum += score;
      voicedFrames++;
    }
    finish(count);
    return notes;
  }
}

String _requireName(List<String> names, String required) {
  if (!names.contains(required)) {
    throw ModelUnavailableException(
        'This is not the expected PESTO ONNX graph: '
        'missing input "$required".');
  }
  return required;
}

int _requireIndex(List<String> names, String required) {
  final index = names.indexOf(required);
  if (index < 0) {
    throw ModelUnavailableException(
        'This is not the expected PESTO ONNX graph: '
        'missing output "$required".');
  }
  return index;
}

List<double> _numbers(Object? value) {
  final result = <double>[];
  void visit(Object? item) {
    if (item is num) {
      result.add(item.toDouble());
    } else if (item is List) {
      for (final nested in item) {
        visit(nested);
      }
    } else {
      throw ModelUnavailableException('PESTO returned a non-numeric tensor.');
    }
  }

  visit(value);
  return result;
}
