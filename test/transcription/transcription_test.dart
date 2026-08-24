import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound/transcription/midi_encoder.dart';
import 'package:sound/transcription/midi_preview_player.dart';
import 'package:sound/transcription/basic_pitch_runner.dart';
import 'package:sound/transcription/pesto_runner.dart';
import 'package:sound/transcription/types.dart';
import 'package:sound/transcription/wav_decoder.dart';
import 'package:sound/transcription/yin_transcriber.dart';

void main() {
  test('decodes PCM WAV and produces a note for a stable tone', () {
    const sampleRate = 16000;
    final samples = List<double>.generate(
      sampleRate,
      (index) => .4 * math.sin(2 * math.pi * 440 * index / sampleRate),
    );
    final audio = WavDecoder.decode(_pcm16Wave(samples, sampleRate));
    final notes = const YinTranscriber().transcribe(
      audio,
      const TranscriptionOptions(),
      pyinStyle: false,
    );

    expect(audio.sampleRate, sampleRate);
    expect(notes, isNotEmpty);
    expect(notes.first.pitch, closeTo(69, 1));
  });

  test('writes a type-0 MIDI track with note on and note off events', () {
    final bytes = MidiEncoder.encode([
      MidiNote(
        start: Duration.zero,
        end: const Duration(milliseconds: 500),
        pitch: 69,
      ),
    ]);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'MThd');
    expect(String.fromCharCodes(bytes.sublist(14, 18)), 'MTrk');
    expect(bytes, containsAllInOrder([0x90, 69, 96, 0x80, 69, 0]));
  });

  test('Grand Piano preview loads once and schedules MIDI note events',
      () async {
    final synth = _FakeSynth();
    final player = MidiPreviewPlayer.forTesting(synth);
    var completed = 0;

    await player.play([
      MidiNote(
        start: Duration.zero,
        end: const Duration(milliseconds: 12),
        pitch: 60,
        velocity: 87,
      ),
    ], onComplete: () => completed++);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(
        synth.calls,
        containsAllInOrder([
          'session',
          'init',
          'load:${MidiPreviewPlayer.soundfontAsset}',
          'select:7',
          'sound:7',
          'on:7:60:87',
          'off:7:60',
        ]));
    expect(completed, 1);
    expect(player.isPlaying, isFalse);
  });

  test('stopping a preview cancels pending note-offs and panics the synth',
      () async {
    final synth = _FakeSynth();
    final player = MidiPreviewPlayer.forTesting(synth);
    await player.play([
      MidiNote(
        start: Duration.zero,
        end: const Duration(milliseconds: 100),
        pitch: 64,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 115));

    expect(synth.calls, contains('panic'));
    expect(synth.calls, isNot(contains('off:7:64')));
    expect(player.isPlaying, isFalse);
  });

  test('Basic Pitch activation decoder extracts a MIDI note and velocity', () {
    const frames = 24;
    final note = List<double>.filled(frames * BasicPitchRunner.outputBins, 0);
    final onset = List<double>.filled(frames * BasicPitchRunner.outputBins, 0);
    const a4Bin = 69 - 21;
    for (var time = 3; time <= 18; time++) {
      note[time * BasicPitchRunner.outputBins + a4Bin] = .9;
    }
    onset[3 * BasicPitchRunner.outputBins + a4Bin] = .9;
    onset[2 * BasicPitchRunner.outputBins + a4Bin] = .1;
    onset[4 * BasicPitchRunner.outputBins + a4Bin] = .1;

    final decoded = BasicPitchRunner.decodeActivations(
      noteActivations: note,
      onsetActivations: onset,
      frameCount: frames,
      options: const TranscriptionOptions(),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.pitch, 69);
    expect(decoded.single.velocity, 114);
    expect(decoded.single.start.inMilliseconds, closeTo(35, 2));
    expect(decoded.single.end, greaterThan(decoded.single.start));
  });

  test('Basic Pitch decoder honors the selected frequency range', () {
    const frames = 24;
    final note = List<double>.filled(frames * BasicPitchRunner.outputBins, 0);
    final onset = List<double>.filled(frames * BasicPitchRunner.outputBins, 0);
    const a4Bin = 69 - 21;
    for (var time = 3; time <= 18; time++) {
      note[time * BasicPitchRunner.outputBins + a4Bin] = .9;
    }
    onset[3 * BasicPitchRunner.outputBins + a4Bin] = .9;
    onset[2 * BasicPitchRunner.outputBins + a4Bin] = .1;
    onset[4 * BasicPitchRunner.outputBins + a4Bin] = .1;

    expect(
      BasicPitchRunner.decodeActivations(
        noteActivations: note,
        onsetActivations: onset,
        frameCount: frames,
        options: const TranscriptionOptions(maxFrequency: 400),
      ),
      isEmpty,
    );
  });

  test('PESTO contour segmentation keeps stable pitches and splits note jumps',
      () {
    const profile = PestoModelProfile(
      sampleRate: 44100,
      chunkSize: 1024,
      cacheLength: 3584,
    );
    final notes = PestoNoteSegmenter.segment(
      semitones: const [69, 69.05, 68.98, 69.02, 72, 72.03, 71.98, 72.01],
      confidence: const [.9, .9, .9, .9, .9, .9, .9, .9],
      profile: profile,
      options: const TranscriptionOptions(),
    );

    expect(notes.map((note) => note.pitch), [69, 72]);
    expect(notes.first.start, Duration.zero);
    expect(notes.first.end, const Duration(microseconds: 92880));
    expect(notes.first.confidence, closeTo(.9, .001));
  });
}

class _FakeSynth implements MidiSynth {
  final List<String> calls = [];
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> configurePlaybackSession() async => calls.add('session');

  @override
  Future<void> configureSound(int soundfontId) async =>
      calls.add('sound:$soundfontId');

  @override
  Future<void> initialize() async {
    _initialized = true;
    calls.add('init');
  }

  @override
  Future<int> loadGrandPiano(String assetPath) async {
    calls.add('load:$assetPath');
    return 7;
  }

  @override
  Future<void> panic() async => calls.add('panic');

  @override
  Future<void> playNote(int soundfontId, int pitch, int velocity) async =>
      calls.add('on:$soundfontId:$pitch:$velocity');

  @override
  Future<void> selectGrandPiano(int soundfontId) async =>
      calls.add('select:$soundfontId');

  @override
  Future<void> stopNote(int soundfontId, int pitch) async =>
      calls.add('off:$soundfontId:$pitch');
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
        44 + index * 2, (samples[index] * 32767).round(), Endian.little);
  }
  return bytes;
}
