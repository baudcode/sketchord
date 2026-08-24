import 'dart:math' as math;

import 'types.dart';
import 'wav_decoder.dart';

class YinTranscriber {
  const YinTranscriber();

  List<MidiNote> transcribe(PcmAudio audio, TranscriptionOptions options,
      {required bool pyinStyle}) {
    final target = _resample(audio, 16000);
    const frameSize = 1024;
    const hopSize = 320; // 20 ms at 16 kHz
    if (target.samples.length < frameSize) return const [];
    final frames = <_PitchFrame>[];
    for (var start = 0;
        start + frameSize <= target.samples.length;
        start += hopSize) {
      final frame = target.samples.sublist(start, start + frameSize);
      frames.add(_estimateFrame(
        frame,
        start / target.sampleRate,
        target.sampleRate,
        options.minFrequency,
        options.maxFrequency,
        pyinStyle,
      ));
    }
    return _segment(frames, options, pyinStyle: pyinStyle);
  }

  PcmAudio _resample(PcmAudio audio, int rate) {
    if (audio.sampleRate == rate) return audio;
    final length = (audio.samples.length * rate / audio.sampleRate).floor();
    final result = List<double>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      final position = i * audio.sampleRate / rate;
      final left = position.floor();
      final fraction = position - left;
      final a = audio.samples[left.clamp(0, audio.samples.length - 1)];
      final b = audio.samples[(left + 1).clamp(0, audio.samples.length - 1)];
      result[i] = a + (b - a) * fraction;
    }
    return PcmAudio(sampleRate: rate, samples: result);
  }

  _PitchFrame _estimateFrame(
    List<double> input,
    double start,
    int sampleRate,
    double minFrequency,
    double maxFrequency,
    bool pyinStyle,
  ) {
    var energy = 0.0;
    final frame = List<double>.generate(input.length, (index) {
      final window =
          .5 - .5 * math.cos(2 * math.pi * index / (input.length - 1));
      final sample = input[index] * window;
      energy += sample * sample;
      return sample;
    });
    final rms = math.sqrt(energy / frame.length);
    if (rms < (pyinStyle ? .006 : .01)) return _PitchFrame(start, null, 0);

    final minLag = math.max(2, (sampleRate / maxFrequency).floor());
    final maxLag =
        math.min(frame.length ~/ 2, (sampleRate / minFrequency).ceil());
    final difference = List<double>.filled(maxLag + 1, 0);
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var index = 0; index + lag < frame.length; index++) {
        final delta = frame[index] - frame[index + lag];
        sum += delta * delta;
      }
      difference[lag] = sum;
    }
    var running = 0.0;
    var bestLag = 0;
    var bestScore = double.infinity;
    final threshold = pyinStyle ? .19 : .15;
    for (var lag = minLag; lag <= maxLag; lag++) {
      running += difference[lag];
      final double cmnd = running == 0 ? 1 : difference[lag] * lag / running;
      if (cmnd < bestScore) {
        bestScore = cmnd;
        bestLag = lag;
      }
      if (cmnd < threshold &&
          lag > minLag &&
          cmnd <= difference[lag - 1] * lag / running) {
        bestLag = lag;
        bestScore = cmnd;
        break;
      }
    }
    if (bestLag == 0 || bestScore > (pyinStyle ? .35 : .25)) {
      return _PitchFrame(start, null, 0);
    }
    final refined = _refineLag(difference, bestLag);
    return _PitchFrame(
        start, sampleRate / refined, (1 - bestScore).clamp(0, 1).toDouble());
  }

  double _refineLag(List<double> difference, int lag) {
    if (lag <= 1 || lag >= difference.length - 1) return lag.toDouble();
    final left = difference[lag - 1];
    final center = difference[lag];
    final right = difference[lag + 1];
    final denominator = left - 2 * center + right;
    if (denominator.abs() < 1e-12) return lag.toDouble();
    return lag + .5 * (left - right) / denominator;
  }

  List<MidiNote> _segment(
    List<_PitchFrame> input,
    TranscriptionOptions options, {
    required bool pyinStyle,
  }) {
    if (input.isEmpty) return const [];
    final frames = List<_PitchFrame>.from(input);
    // A short median filter removes tracker jitter without flattening a real
    // semitone transition; pYIN uses a slightly longer temporal prior.
    final radius = pyinStyle ? 2 : 1;
    for (var i = 0; i < input.length; i++) {
      final pitches = <double>[];
      for (var j = math.max(0, i - radius);
          j <= math.min(input.length - 1, i + radius);
          j++) {
        if (input[j].frequency != null) pitches.add(input[j].midi);
      }
      if (pitches.isNotEmpty) {
        pitches.sort();
        frames[i] = input[i].copyWithMidi(pitches[pitches.length ~/ 2]);
      }
    }

    final notes = <MidiNote>[];
    var start = -1;
    var currentPitch = 0.0;
    var confidence = 0.0;
    var count = 0;
    void finish(int end) {
      if (start < 0 || end <= start) return;
      final startTime =
          Duration(microseconds: (frames[start].time * 1000000).round());
      final endSeconds =
          end < frames.length ? frames[end].time : frames.last.time + .02;
      final endTime = Duration(microseconds: (endSeconds * 1000000).round());
      if (endTime - startTime >= options.minimumNoteLength) {
        notes.add(MidiNote(
          start: startTime,
          end: endTime,
          pitch: _lockPitch(currentPitch.round(), options.scalePitchClasses),
          confidence: confidence / math.max(1, count),
        ));
      }
      start = -1;
      currentPitch = 0;
      confidence = 0;
      count = 0;
    }

    for (var index = 0; index < frames.length; index++) {
      final frame = frames[index];
      if (frame.frequency == null) {
        finish(index);
        continue;
      }
      if (start < 0) {
        start = index;
        currentPitch = frame.midi;
      } else if ((frame.midi - currentPitch).abs() > (pyinStyle ? .9 : .65)) {
        finish(index);
        start = index;
        currentPitch = frame.midi;
      }
      // Slow portamento follows the note; rapid pitch changes have split above.
      currentPitch = currentPitch * .8 + frame.midi * .2;
      confidence += frame.confidence;
      count++;
    }
    finish(frames.length);
    return notes;
  }

  int _lockPitch(int pitch, Set<int>? scale) {
    if (scale == null || scale.isEmpty) return pitch.clamp(0, 127).toInt();
    if (scale.contains(pitch % 12)) return pitch.clamp(0, 127).toInt();
    for (var distance = 1; distance <= 6; distance++) {
      final lower = pitch - distance;
      if (lower >= 0 && scale.contains(lower % 12)) return lower;
      final upper = pitch + distance;
      if (upper <= 127 && scale.contains(upper % 12)) return upper;
    }
    return pitch.clamp(0, 127).toInt();
  }
}

class _PitchFrame {
  const _PitchFrame(this.time, this.frequency, this.confidence,
      {this.midiValue});

  final double time;
  final double? frequency;
  final double confidence;
  final double? midiValue;
  double get midi =>
      midiValue ?? 69 + 12 * math.log(frequency! / 440) / math.ln2;

  _PitchFrame copyWithMidi(double value) =>
      _PitchFrame(time, frequency, confidence, midiValue: value);
}
