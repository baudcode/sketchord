import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'types.dart';
import 'wav_decoder.dart';

/// A pitch/voicing estimate emitted at a known point in the input audio.
///
/// The class is deliberately model-neutral so the same note segmenter can be
/// used by CREPE and SPICE without pretending that their confidence scales are
/// interchangeable.
class PitchFrame {
  const PitchFrame({
    required this.time,
    required this.frequency,
    required this.confidence,
  });

  final Duration time;
  final double frequency;
  final double confidence;
}

/// Converts a voiced F0 contour into MIDI notes.
///
/// This is intentionally conservative: a semitone-sized fast movement starts
/// a new note while gradual vibrato remains part of the current note.  It is a
/// deterministic on-device segmenter, not a claim that either pitch model has
/// an onset/offset head.
class PitchContourSegmenter {
  const PitchContourSegmenter({
    this.voicingThreshold = .5,
    this.noteChangeSemitones = .75,
  });

  final double voicingThreshold;
  final double noteChangeSemitones;

  List<MidiNote> segment(
    List<PitchFrame> frames,
    TranscriptionOptions options, {
    required Duration framePeriod,
  }) {
    if (frames.isEmpty) return const [];
    final notes = <MidiNote>[];
    var start = -1;
    var currentMidi = 0.0;
    var confidenceSum = 0.0;
    var count = 0;

    void finish(int end) {
      if (start < 0 || end <= start) return;
      final startTime = frames[start].time;
      final endTime = end < frames.length
          ? frames[end].time
          : frames.last.time + framePeriod;
      if (endTime - startTime >= options.minimumNoteLength) {
        notes.add(MidiNote(
          start: startTime,
          end: endTime,
          pitch: _lockPitch(currentMidi.round(), options.scalePitchClasses),
          confidence: confidenceSum / math.max(1, count),
        ));
      }
      start = -1;
      confidenceSum = 0;
      count = 0;
    }

    for (var index = 0; index < frames.length; index++) {
      final frame = frames[index];
      final voiced = frame.confidence >= voicingThreshold &&
          frame.frequency >= options.minFrequency &&
          frame.frequency <= options.maxFrequency &&
          frame.frequency.isFinite;
      if (!voiced) {
        finish(index);
        continue;
      }
      final midi = _midiForFrequency(frame.frequency);
      if (start < 0 || (midi - currentMidi).abs() >= noteChangeSemitones) {
        finish(index);
        start = index;
        currentMidi = midi;
      }
      currentMidi = currentMidi * .8 + midi * .2;
      confidenceSum += frame.confidence;
      count++;
    }
    finish(frames.length);
    return notes;
  }

  static double _midiForFrequency(double frequency) =>
      69 + 12 * math.log(frequency / 440) / math.ln2;

  static int _lockPitch(int pitch, Set<int>? scale) {
    pitch = pitch.clamp(0, 127).toInt();
    if (scale == null || scale.isEmpty || scale.contains(pitch % 12)) {
      return pitch;
    }
    for (var distance = 1; distance <= 6; distance++) {
      final lower = pitch - distance;
      if (lower >= 0 && scale.contains(lower % 12)) return lower;
      final upper = pitch + distance;
      if (upper <= 127 && scale.contains(upper % 12)) return upper;
    }
    return pitch;
  }
}

/// Decodes CREPE's 360 salience bins using the upstream local weighted-cent
/// average.  CREPE bins are 20 cents apart, beginning at 1997.379 cents above
/// 10 Hz.  Keeping this separate makes the conversion unit-testable.
class CrepePitchDecoder {
  static const int bins = 360;
  static const double _firstBinCents = 1997.3794084376191;
  static const double _binStepCents = 20;

  const CrepePitchDecoder._();

  static PitchFrame decode(
    List<double> salience,
    Duration time,
  ) {
    if (salience.length != bins) {
      throw ArgumentError.value(salience.length, 'salience.length',
          'CREPE requires exactly $bins salience bins.');
    }
    var center = 0;
    var confidence = -double.infinity;
    for (var index = 0; index < salience.length; index++) {
      if (salience[index] > confidence) {
        confidence = salience[index];
        center = index;
      }
    }
    final start = math.max(0, center - 4);
    final end = math.min(salience.length, center + 5);
    var weightedCents = 0.0;
    var weight = 0.0;
    for (var index = start; index < end; index++) {
      final value = salience[index].isFinite ? salience[index] : 0.0;
      weightedCents += value * (_firstBinCents + index * _binStepCents);
      weight += value;
    }
    final cents = weight > 0
        ? weightedCents / weight
        : _firstBinCents + center * _binStepCents;
    return PitchFrame(
      time: time,
      frequency: 10 * math.pow(2, cents / 1200).toDouble(),
      confidence: confidence.isFinite ? confidence.clamp(0, 1).toDouble() : 0,
    );
  }
}

/// Executes a TFLite export of CREPE-tiny or CREPE-full.
///
/// The model must preserve CREPE's public contract: float32 input shaped
/// `[batch, 1024]` (or `[batch, 1024, 1]`) and a 360-bin float32 salience
/// output.  This deliberately fails loudly for an incompatible conversion
/// rather than returning musically plausible but wrong MIDI.
class CrepeTfliteRunner {
  static const _sampleRate = 16000;
  static const _frameSamples = 1024;
  static const _hopSamples = 160; // 10 ms, as in upstream CREPE.

  Future<List<MidiNote>> transcribe(
    PcmAudio source,
    File model,
    TranscriptionOptions options,
  ) async {
    final audio = _resample(source, _sampleRate);
    final frames = _makeNormalizedFrames(audio.samples);
    if (frames.frameCount == 0) return const [];
    final activations = _TfliteFloatRunner.run(
      model,
      frames.values,
      [frames.frameCount, _frameSamples],
    ).single;
    if (activations.length != frames.frameCount * CrepePitchDecoder.bins) {
      throw ModelUnavailableException(
        'The selected CREPE file returned ${activations.length} values; '
        'expected ${frames.frameCount * CrepePitchDecoder.bins}.',
      );
    }
    final contour = List<PitchFrame>.generate(frames.frameCount, (index) {
      final offset = index * CrepePitchDecoder.bins;
      return CrepePitchDecoder.decode(
        activations.sublist(offset, offset + CrepePitchDecoder.bins),
        Duration(milliseconds: index * 10),
      );
    });
    return const PitchContourSegmenter().segment(
      contour,
      options,
      framePeriod: const Duration(milliseconds: 10),
    );
  }

  _CrepeFrames _makeNormalizedFrames(List<double> source) {
    // Upstream CREPE zero-pads 512 samples on either side so each timestamp
    // represents the centre of its analysis frame.
    final padded = List<double>.filled(source.length + _frameSamples, 0)
      ..setRange(
          _frameSamples ~/ 2, _frameSamples ~/ 2 + source.length, source);
    final frameCount = 1 + (padded.length - _frameSamples) ~/ _hopSamples;
    final result = Float32List(frameCount * _frameSamples);
    for (var frame = 0; frame < frameCount; frame++) {
      final start = frame * _hopSamples;
      var mean = 0.0;
      for (var sample = 0; sample < _frameSamples; sample++) {
        mean += padded[start + sample];
      }
      mean /= _frameSamples;
      var variance = 0.0;
      for (var sample = 0; sample < _frameSamples; sample++) {
        final delta = padded[start + sample] - mean;
        variance += delta * delta;
      }
      final standardDeviation =
          math.sqrt(variance / _frameSamples).clamp(1e-8, double.infinity);
      for (var sample = 0; sample < _frameSamples; sample++) {
        result[frame * _frameSamples + sample] =
            (padded[start + sample] - mean) / standardDeviation;
      }
    }
    return _CrepeFrames(result, frameCount);
  }
}

/// Converts the published SPICE 0..1 pitch coordinate to Hz.  The constants
/// are the calibration values published alongside the TF Hub SPICE model.
class SpicePitchDecoder {
  static const _pitchOffset = 25.58;
  static const _pitchSlope = 63.07;
  static const _minimumFrequency = 10.0;
  static const _binsPerOctave = 12.0;

  const SpicePitchDecoder._();

  static double toFrequency(double output) {
    final cqtBin = output * _pitchSlope + _pitchOffset;
    return _minimumFrequency * math.pow(2, cqtBin / _binsPerOctave).toDouble();
  }
}

/// Executes Google's published SPICE TFLite graph.  Its input is a mono 16 kHz
/// waveform and it emits a pitch coordinate plus an uncertainty every 512
/// samples.  Confidence is therefore `1 - uncertainty`.
class SpiceTfliteRunner {
  static const _sampleRate = 16000;
  static const _hopSamples = 512;

  Future<List<MidiNote>> transcribe(
    PcmAudio source,
    File model,
    TranscriptionOptions options,
  ) async {
    final audio = _resample(source, _sampleRate);
    if (audio.samples.isEmpty) return const [];
    final output = _TfliteFloatRunner.run(
      model,
      Float32List.fromList(audio.samples),
      [audio.samples.length],
    );
    if (output.length != 2) {
      throw ModelUnavailableException(
          'The selected SPICE file must expose pitch and uncertainty outputs.');
    }
    // The official lite-model signature exposes outputs in this order:
    // pitches, uncertainties.  This mirrors the model card's TFLite metadata.
    final pitches = output[0];
    final uncertainty = output[1];
    final length = math.min(pitches.length, uncertainty.length);
    if (length == 0) return const [];
    final contour = List<PitchFrame>.generate(
        length,
        (index) => PitchFrame(
              time: Duration(
                  microseconds: index * 1000000 * _hopSamples ~/ _sampleRate),
              frequency: SpicePitchDecoder.toFrequency(pitches[index]),
              confidence: (1 - uncertainty[index]).clamp(0, 1).toDouble(),
            ));
    return const PitchContourSegmenter(voicingThreshold: .9).segment(
      contour,
      options,
      framePeriod: const Duration(milliseconds: 32),
    );
  }
}

class _CrepeFrames {
  const _CrepeFrames(this.values, this.frameCount);

  final Float32List values;
  final int frameCount;
}

/// Minimal float32 TFLite invocation helper.  Reading/writing tensors as raw
/// bytes avoids allocating deeply nested Dart lists for long recordings.
class _TfliteFloatRunner {
  static List<List<double>> run(
    File model,
    Float32List values,
    List<int> preferredInputShape,
  ) {
    final interpreter = Interpreter.fromFile(model);
    try {
      final input = interpreter.getInputTensor(0);
      final inputShape =
          _compatibleInputShape(input.shape, preferredInputShape);
      interpreter.resizeInputTensor(0, inputShape);
      interpreter.allocateTensors();
      final allocatedInput = interpreter.getInputTensor(0);
      if (allocatedInput.numBytes() != values.lengthInBytes) {
        throw ModelUnavailableException(
          'The selected TFLite model expects ${allocatedInput.numBytes()} input bytes, '
          'but this runner prepared ${values.lengthInBytes}.',
        );
      }
      final outputs = <int, Object>{
        for (var index = 0;
            index < interpreter.getOutputTensors().length;
            index++)
          index: Uint8List(interpreter.getOutputTensor(index).numBytes()),
      };
      // Tensor.data is read-only convenience state in tflite_flutter. Use its
      // supported copy/invoke API so the native tensor buffer is populated.
      interpreter.runForMultipleInputs([values.buffer], outputs);
      return List<List<double>>.generate(outputs.length, (index) {
        final tensor = interpreter.getOutputTensor(index);
        final bytes = outputs[index]! as Uint8List;
        return _readFloatBytes(tensor, bytes);
      }, growable: false);
    } on ModelUnavailableException {
      rethrow;
    } catch (error) {
      throw ModelUnavailableException('TFLite transcription failed: $error');
    } finally {
      interpreter.close();
    }
  }

  static List<int> _compatibleInputShape(
    List<int> actual,
    List<int> preferred,
  ) {
    if (actual.length == preferred.length) return preferred;
    if (actual.length == preferred.length + 1 && actual.last == 1) {
      return [...preferred, 1];
    }
    if (preferred.length == 1 && actual.length == 2 && actual.first == 1) {
      return [1, preferred.single];
    }
    throw ModelUnavailableException(
      'Unsupported TFLite input shape $actual; expected $preferred or '
      '${[...preferred, 1]}.',
    );
  }

  static List<double> _readFloatBytes(Tensor tensor, Uint8List bytes) {
    if (tensor.type != TensorType.float32) {
      throw ModelUnavailableException(
          'Expected a float32 TFLite output, received ${tensor.type}.');
    }
    final floats = Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.map((value) => value.toDouble()).toList(growable: false);
  }
}

PcmAudio _resample(PcmAudio audio, int outputRate) {
  if (audio.sampleRate == outputRate) return audio;
  if (audio.samples.isEmpty) {
    return PcmAudio(sampleRate: outputRate, samples: const []);
  }
  final length = (audio.samples.length * outputRate / audio.sampleRate).round();
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
