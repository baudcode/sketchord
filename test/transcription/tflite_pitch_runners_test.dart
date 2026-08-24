import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sound/transcription/tflite_pitch_runners.dart';
import 'package:sound/transcription/types.dart';

void main() {
  group('CREPE output decoding', () {
    test('uses upstream local weighted-cent averaging', () {
      final salience = List<double>.filled(CrepePitchDecoder.bins, 0)
        ..[120] = .5
        ..[121] = 1
        ..[122] = .5;

      final frame = CrepePitchDecoder.decode(salience, Duration.zero);

      // The symmetric local weighting resolves to the centre CREPE bin.
      final cents = 1997.3794084376191 + 121 * 20;
      final expectedFrequency = 10 * math.pow(2, cents / 1200);
      expect(frame.confidence, closeTo(1, 1e-9));
      expect(frame.frequency, closeTo(expectedFrequency, 1e-9));
    });

    test('rejects an incompatible activation shape', () {
      expect(
        () => CrepePitchDecoder.decode(const [1], Duration.zero),
        throwsArgumentError,
      );
    });
  });

  test('SPICE calibration converts the published coordinate to Hz', () {
    const output = .5;
    final expected = 10 * math.pow(2, (output * 63.07 + 25.58) / 12);
    expect(SpicePitchDecoder.toFrequency(output), closeTo(expected, 1e-9));
  });

  group('pitch contour segmentation', () {
    const options = TranscriptionOptions(
      minimumNoteLength: Duration(milliseconds: 10),
    );

    test('keeps vibrato together and splits a semitone transition', () {
      final notes = const PitchContourSegmenter().segment(
        const [
          PitchFrame(time: Duration.zero, frequency: 440, confidence: .95),
          PitchFrame(
              time: Duration(milliseconds: 10),
              frequency: 446,
              confidence: .95),
          PitchFrame(
              time: Duration(milliseconds: 20),
              frequency: 493.883,
              confidence: .95),
          PitchFrame(
              time: Duration(milliseconds: 30),
              frequency: 493.883,
              confidence: .95),
        ],
        options,
        framePeriod: const Duration(milliseconds: 10),
      );

      expect(notes, hasLength(2));
      expect(notes[0].pitch, 69);
      expect(notes[0].start, Duration.zero);
      expect(notes[0].end, const Duration(milliseconds: 20));
      expect(notes[1].pitch, 71);
    });

    test('does not turn low-confidence output into a note', () {
      final notes = const PitchContourSegmenter().segment(
        const [
          PitchFrame(time: Duration.zero, frequency: 440, confidence: .2),
          PitchFrame(
              time: Duration(milliseconds: 10), frequency: 440, confidence: .2),
        ],
        options,
        framePeriod: const Duration(milliseconds: 10),
      );
      expect(notes, isEmpty);
    });
  });
}
