import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'types.dart';
import 'wav_decoder.dart';

/// TensorFlow Lite runner for Spotify's ICASSP 2022 Basic Pitch model.
///
/// This deliberately follows the upstream inference implementation: 22.05 kHz
/// mono input, 43,844-sample windows, and 30 output-frame overlap. The graph
/// emits note, onset, and contour activation maps; contour values describe
/// pitch bends, which cannot be represented by [MidiNote], so this runner
/// exports the discrete notes and velocities only.
class BasicPitchRunner {
  static const int sampleRate = 22050;
  static const int audioSamplesPerWindow = 43844;
  static const int framesPerWindow = 172;
  static const int outputOverlapFrames = 30;
  static const int outputBins = 88;
  static const int _midiOffset = 21;
  static const int _fftHop = 256;
  static const double _onsetThreshold = .5;
  static const double _frameThreshold = .3;
  static const int _energyToleranceFrames = 11;

  Future<List<MidiNote>> transcribe(
    PcmAudio source,
    File model,
    TranscriptionOptions options,
  ) async {
    final audio = _resample(source, sampleRate);
    if (audio.samples.isEmpty) return const [];

    final interpreter = Interpreter.fromFile(model);
    try {
      final inputTensor = interpreter.getInputTensor(0);
      if (inputTensor.shape.length != 3 ||
          inputTensor.shape[0] != 1 ||
          inputTensor.shape[1] != audioSamplesPerWindow ||
          inputTensor.shape[2] != 1 ||
          inputTensor.type != TensorType.float32) {
        throw ModelUnavailableException(
          'The downloaded Basic Pitch model has an unsupported input tensor.',
        );
      }

      final outputTensors = interpreter.getOutputTensors();
      if (outputTensors.length != 3 ||
          outputTensors.any((tensor) => tensor.type != TensorType.float32)) {
        throw ModelUnavailableException(
          'The downloaded Basic Pitch model has unsupported output tensors.',
        );
      }

      final padded = <double>[
        ...List<double>.filled(3840, 0),
        ...audio.samples
      ];
      final notesWindows = <Float32List>[];
      final onsetWindows = <Float32List>[];
      final hopSize = audioSamplesPerWindow - outputOverlapFrames * _fftHop;
      for (var offset = 0; offset < padded.length; offset += hopSize) {
        final window = Float32List(audioSamplesPerWindow);
        final available =
            math.min(audioSamplesPerWindow, padded.length - offset);
        for (var i = 0; i < available; i++) {
          window[i] = padded[offset + i];
        }
        final results = <int, Object>{
          for (var i = 0; i < outputTensors.length; i++)
            i: Uint8List(outputTensors[i].numBytes()),
        };
        interpreter.runForMultipleInputs([window.buffer], results);

        for (var i = 0; i < outputTensors.length; i++) {
          final tensor = outputTensors[i];
          final values = (results[i]! as Uint8List).buffer.asFloat32List();
          if (tensor.shape.length != 3 ||
              tensor.shape[0] != 1 ||
              tensor.shape[1] != framesPerWindow) {
            throw ModelUnavailableException(
              'The downloaded Basic Pitch model returned an invalid tensor.',
            );
          }
          // The upstream nmp.tflite graph orders its outputs as onset, note,
          // contour (StatefulPartitionedCall:2, :1, :0). Validate the 88-bin
          // maps instead of trusting a Flutter binding to preserve names.
          if (tensor.shape[2] == outputBins) {
            if (i == 0) {
              onsetWindows.add(values);
            } else if (i == 1) {
              notesWindows.add(values);
            } else {
              throw ModelUnavailableException(
                'The downloaded Basic Pitch model has an unknown output order.',
              );
            }
          } else if (tensor.shape[2] != outputBins * 3) {
            throw ModelUnavailableException(
              'The downloaded Basic Pitch model returned an invalid bin count.',
            );
          }
        }
      }
      if (notesWindows.length != onsetWindows.length || notesWindows.isEmpty) {
        throw ModelUnavailableException(
          'The downloaded Basic Pitch model did not return note activations.',
        );
      }

      final expectedFrames = (audio.samples.length /
              hopSize *
              (framesPerWindow - outputOverlapFrames))
          .floor();
      if (expectedFrames == 0) return const [];
      final frames = _unwrap(notesWindows, expectedFrames);
      final onsets = _unwrap(onsetWindows, expectedFrames);
      return decodeActivations(
        noteActivations: frames,
        onsetActivations: onsets,
        frameCount: frames.length ~/ outputBins,
        options: options,
      );
    } finally {
      interpreter.close();
    }
  }

  /// Converts Basic Pitch's unwrapped `[time, 88]` note and onset maps to
  /// discrete MIDI events. Public for deterministic unit tests and to keep the
  /// model-specific decoder independent of the native TFLite binding.
  static List<MidiNote> decodeActivations({
    required List<double> noteActivations,
    required List<double> onsetActivations,
    required int frameCount,
    required TranscriptionOptions options,
  }) {
    if (frameCount < 1 ||
        noteActivations.length != frameCount * outputBins ||
        onsetActivations.length != frameCount * outputBins) {
      throw ArgumentError(
          'Basic Pitch activation maps have invalid dimensions.');
    }
    final frames = List<double>.from(noteActivations);
    final onsets = List<double>.from(onsetActivations);
    final minBin = (69 +
            12 * math.log(options.minFrequency / 440) / math.ln2 -
            _midiOffset)
        .round()
        .clamp(0, outputBins)
        .toInt();
    final maxBin = (69 +
            12 * math.log(options.maxFrequency / 440) / math.ln2 -
            _midiOffset)
        .round()
        .clamp(0, outputBins)
        .toInt();
    for (var time = 0; time < frameCount; time++) {
      for (var bin = 0; bin < outputBins; bin++) {
        if (bin < minBin || bin >= maxBin) {
          frames[time * outputBins + bin] = 0;
          onsets[time * outputBins + bin] = 0;
        }
      }
    }
    _inferOnsets(onsets, frames, frameCount);
    final remaining = List<double>.from(frames);
    final candidates = <_OnsetCandidate>[];
    for (var bin = 0; bin < outputBins; bin++) {
      for (var time = 1; time < frameCount - 1; time++) {
        final value = onsets[time * outputBins + bin];
        if (value >= _onsetThreshold &&
            value > onsets[(time - 1) * outputBins + bin] &&
            value > onsets[(time + 1) * outputBins + bin]) {
          candidates.add(_OnsetCandidate(time, bin));
        }
      }
    }

    final minNoteFrames = math.max(
      _energyToleranceFrames,
      (options.minimumNoteLength.inMicroseconds *
              sampleRate /
              _fftHop /
              1000000)
          .ceil(),
    );
    final events = <_NoteEvent>[];
    // Spotify's decoder processes peaks backwards in time. Doing the same
    // makes overlapping/adjacent-note suppression agree with upstream.
    for (final candidate in candidates.reversed) {
      final event = _extractFromOnset(
        frames,
        remaining,
        frameCount,
        candidate.time,
        candidate.bin,
        minNoteFrames,
      );
      if (event != null) events.add(event);
    }

    // The upstream "melodia trick" recovers sustained notes whose onset head
    // missed them by growing a note from the strongest remaining activation.
    while (true) {
      var peak = _frameThreshold;
      var peakIndex = -1;
      for (var i = 0; i < remaining.length; i++) {
        if (remaining[i] > peak) {
          peak = remaining[i];
          peakIndex = i;
        }
      }
      if (peakIndex < 0) break;
      final event = _extractMelodia(
        frames,
        remaining,
        frameCount,
        peakIndex ~/ outputBins,
        peakIndex % outputBins,
        minNoteFrames,
      );
      if (event != null) events.add(event);
    }

    events.sort((a, b) => a.startFrame.compareTo(b.startFrame));
    return events.map((event) {
      final start = _frameToDuration(event.startFrame);
      final end = _frameToDuration(event.endFrame);
      return MidiNote(
        start: start,
        end: end > start ? end : start + options.minimumNoteLength,
        pitch: event.bin + _midiOffset,
        velocity: (event.amplitude * 127).round().clamp(1, 127).toInt(),
        confidence: event.amplitude.clamp(0, 1).toDouble(),
      );
    }).toList(growable: false);
  }

  static PcmAudio _resample(PcmAudio audio, int outputRate) {
    if (audio.sampleRate == outputRate) return audio;
    final length =
        (audio.samples.length * outputRate / audio.sampleRate).round();
    return PcmAudio(
      sampleRate: outputRate,
      samples: List<double>.generate(length, (i) {
        final position = i * audio.sampleRate / outputRate;
        final lower = position.floor().clamp(0, audio.samples.length - 1);
        final upper = (lower + 1).clamp(0, audio.samples.length - 1);
        final fraction = position - lower;
        return audio.samples[lower] +
            (audio.samples[upper] - audio.samples[lower]) * fraction;
      }),
    );
  }

  static List<double> _unwrap(List<Float32List> windows, int expectedFrames) {
    const trim = outputOverlapFrames ~/ 2;
    final result = <double>[];
    for (final window in windows) {
      for (var frame = trim; frame < framesPerWindow - trim; frame++) {
        final start = frame * outputBins;
        result.addAll(window.sublist(start, start + outputBins));
      }
    }
    final wanted = math.min(result.length, expectedFrames * outputBins);
    return result.sublist(0, wanted);
  }

  static void _inferOnsets(
    List<double> onsets,
    List<double> frames,
    int frameCount,
  ) {
    var maxOnset = 0.0;
    var maxDiff = 0.0;
    final inferred = List<double>.filled(onsets.length, 0);
    for (final value in onsets) {
      if (value > maxOnset) maxOnset = value;
    }
    for (var time = 2; time < frameCount; time++) {
      for (var bin = 0; bin < outputBins; bin++) {
        final current = frames[time * outputBins + bin];
        final difference = math.min(
          current - frames[(time - 1) * outputBins + bin],
          current - frames[(time - 2) * outputBins + bin],
        );
        if (difference > 0) {
          inferred[time * outputBins + bin] = difference;
          if (difference > maxDiff) maxDiff = difference;
        }
      }
    }
    if (maxDiff == 0) return;
    for (var i = 0; i < onsets.length; i++) {
      onsets[i] = math.max(onsets[i], inferred[i] * maxOnset / maxDiff);
    }
  }

  static _NoteEvent? _extractFromOnset(
    List<double> activations,
    List<double> remaining,
    int frameCount,
    int start,
    int bin,
    int minFrames,
  ) {
    if (start >= frameCount - 1) return null;
    var time = start + 1;
    var below = 0;
    while (time < frameCount - 1 && below < _energyToleranceFrames) {
      if (remaining[time * outputBins + bin] < _frameThreshold) {
        below++;
      } else {
        below = 0;
      }
      time++;
    }
    time -= below;
    if (time - start <= minFrames) return null;
    final amplitude = _mean(activations, start, time, bin);
    _clear(remaining, start, time, bin);
    return _event(start, time, bin, amplitude);
  }

  static _NoteEvent? _extractMelodia(
    List<double> activations,
    List<double> remaining,
    int frameCount,
    int middle,
    int bin,
    int minFrames,
  ) {
    remaining[middle * outputBins + bin] = 0;
    var time = middle + 1;
    var below = 0;
    while (time < frameCount - 1 && below < _energyToleranceFrames) {
      if (remaining[time * outputBins + bin] < _frameThreshold) {
        below++;
      } else {
        below = 0;
      }
      _clearFrame(remaining, time, bin);
      time++;
    }
    final end = time - 1 - below;

    time = middle - 1;
    below = 0;
    while (time > 0 && below < _energyToleranceFrames) {
      if (remaining[time * outputBins + bin] < _frameThreshold) {
        below++;
      } else {
        below = 0;
      }
      _clearFrame(remaining, time, bin);
      time--;
    }
    final start = time + 1 + below;
    if (end - start <= minFrames) return null;
    return _event(start, end, bin, _mean(activations, start, end, bin));
  }

  static double _mean(
    List<double> remaining,
    int start,
    int end,
    int bin,
  ) {
    var sum = 0.0;
    for (var time = start; time < end; time++) {
      sum += remaining[time * outputBins + bin];
    }
    return sum / math.max(1, end - start);
  }

  static _NoteEvent _event(int start, int end, int bin, double amplitude) =>
      _NoteEvent(start, end, bin, amplitude);

  static void _clear(List<double> values, int start, int end, int bin) {
    for (var time = start; time < end; time++) {
      _clearFrame(values, time, bin);
    }
  }

  static void _clearFrame(List<double> values, int time, int bin) {
    values[time * outputBins + bin] = 0;
    if (bin > 0) values[time * outputBins + bin - 1] = 0;
    if (bin < outputBins - 1) values[time * outputBins + bin + 1] = 0;
  }

  static Duration _frameToDuration(int frame) {
    final seconds = frame * _fftHop / sampleRate;
    final window = frame ~/ framesPerWindow;
    final offset = _fftHop /
            sampleRate *
            (framesPerWindow - audioSamplesPerWindow / _fftHop) +
        .0018;
    return Duration(
        microseconds: ((seconds - offset * window) * 1000000).round());
  }
}

class _OnsetCandidate {
  const _OnsetCandidate(this.time, this.bin);

  final int time;
  final int bin;
}

class _NoteEvent {
  const _NoteEvent(this.startFrame, this.endFrame, this.bin, this.amplitude);

  final int startFrame;
  final int endFrame;
  final int bin;
  final double amplitude;
}
