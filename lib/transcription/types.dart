/// A discrete note produced by an on-device transcription model.
class MidiNote {
  MidiNote({
    required this.start,
    required this.end,
    required this.pitch,
    this.velocity = 96,
    this.confidence = 1,
  })  : assert(pitch >= 0 && pitch <= 127),
        assert(velocity >= 0 && velocity <= 127),
        assert(!end.isNegative && !start.isNegative);

  final Duration start;
  final Duration end;
  final int pitch;
  final int velocity;
  final double confidence;

  MidiNote copyWith({Duration? start, Duration? end, int? pitch}) => MidiNote(
        start: start ?? this.start,
        end: end ?? this.end,
        pitch: pitch ?? this.pitch,
        velocity: velocity,
        confidence: confidence,
      );
}

/// The order deliberately matches the on-device table in the product brief.
enum OnDeviceModel {
  basicPitch,
  crepeTiny,
  crepeFull,
  pesto,
  swiftF0,
  spice,
  aubioYin,
  pyin,
}

enum TranscriptionRuntime { tflite, coreMl, onnx, dart }

class OnDeviceModelInfo {
  const OnDeviceModelInfo({
    required this.model,
    required this.title,
    required this.runtime,
    required this.assetPath,
    required this.license,
    required this.directNotes,
    required this.productionReady,
  });

  final OnDeviceModel model;
  final String title;
  final TranscriptionRuntime runtime;

  /// Empty for algorithms implemented directly in Dart.
  final String assetPath;
  final String license;
  final bool directNotes;

  /// Whether the model's published licence permits product use without a
  /// separate legal review.  This does not mean its weight file is bundled.
  final bool productionReady;
}

class TranscriptionOptions {
  const TranscriptionOptions({
    this.minFrequency = 65,
    this.maxFrequency = 1000,
    this.minimumNoteLength = const Duration(milliseconds: 70),
    this.tempoBpm,
    this.quantizationDivisions = 4,
    this.scalePitchClasses,
  })  : assert(minFrequency > 0),
        assert(maxFrequency > minFrequency),
        assert(quantizationDivisions > 0);

  final double minFrequency;
  final double maxFrequency;
  final Duration minimumNoteLength;
  final double? tempoBpm;
  final int quantizationDivisions;

  /// Optional allowed chromatic pitch classes (C = 0).  This is the explicit
  /// opt-in equivalent of a Dubler-style scale lock.
  final Set<int>? scalePitchClasses;
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.model,
    required this.notes,
    this.warnings = const [],
  });

  final OnDeviceModel model;
  final List<MidiNote> notes;
  final List<String> warnings;
}

class ModelUnavailableException implements Exception {
  ModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
