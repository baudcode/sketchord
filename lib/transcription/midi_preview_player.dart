import 'dart:async';

import 'package:flutter_midi_pro/flutter_midi_pro.dart';

import 'types.dart';

/// Minimal synthesizer boundary. Keeping the scheduler independent of the
/// platform plugin makes playback timing testable without a device or SF2.
abstract class MidiSynth {
  bool get isInitialized;

  Future<void> configurePlaybackSession();
  Future<void> initialize();
  Future<int> loadGrandPiano(String assetPath);
  Future<void> selectGrandPiano(int soundfontId);
  Future<void> configureSound(int soundfontId);
  Future<void> playNote(int soundfontId, int pitch, int velocity);
  Future<void> stopNote(int soundfontId, int pitch);
  Future<void> panic();
}

class FlutterMidiProSynth implements MidiSynth {
  FlutterMidiProSynth([MidiPro? midi]) : _midi = midi ?? MidiPro();

  final MidiPro _midi;

  @override
  bool get isInitialized => _midi.isInitialized;

  @override
  Future<void> configurePlaybackSession() => _midi.configureAudioSession(
        category: AudioSessionCategory.playback,
        mixWithOthers: true,
      );

  @override
  Future<void> initialize() => _midi.init(polyphony: 32);

  @override
  Future<int> loadGrandPiano(String assetPath) => _midi.loadSoundfontAsset(
        assetPath: assetPath,
        bank: 0,
        program: 0,
      );

  @override
  Future<void> selectGrandPiano(int soundfontId) => _midi.selectInstrument(
        sfId: soundfontId,
        bank: 0,
        program: 0, // General MIDI Acoustic Grand Piano.
      );

  @override
  Future<void> configureSound(int soundfontId) async {
    await _midi.setMasterGain(.8);
    await _midi.setReverb(enabled: true, roomSize: .35, level: .3);
  }

  @override
  Future<void> playNote(int soundfontId, int pitch, int velocity) =>
      _midi.playNote(sfId: soundfontId, key: pitch, velocity: velocity);

  @override
  Future<void> stopNote(int soundfontId, int pitch) =>
      _midi.stopNote(sfId: soundfontId, key: pitch);

  @override
  Future<void> panic() => _midi.panic();
}

/// Schedules the notes that were written to a MIDI file through the bundled
/// Grand Piano SF2. This works on Android and iOS without relying on a
/// platform-specific MIDI-file player.
class MidiPreviewPlayer {
  factory MidiPreviewPlayer() => _shared;

  MidiPreviewPlayer.forTesting(MidiSynth synth) : _synth = synth;

  MidiPreviewPlayer._() : _synth = FlutterMidiProSynth();
  static final MidiPreviewPlayer _shared = MidiPreviewPlayer._();

  static const soundfontAsset =
      'assets/soundfonts/generaluser-gs-v2.0.2-grand-piano.sf2';
  final MidiSynth _synth;
  final List<Timer> _timers = [];
  int? _soundfontId;
  int _generation = 0;

  bool get isPlaying => _timers.isNotEmpty;

  Future<void> play(List<MidiNote> notes, {void Function()? onComplete}) async {
    await stop();
    if (notes.isEmpty) {
      onComplete?.call();
      return;
    }
    await _prepare();
    final generation = ++_generation;
    final ordered = [...notes]..sort((a, b) => a.start.compareTo(b.start));
    for (final note in ordered) {
      _schedule(note.start, generation, () {
        unawaited(_ignoreErrors(
            _synth.playNote(_soundfontId!, note.pitch, note.velocity)));
      });
      _schedule(note.end, generation, () {
        unawaited(_ignoreErrors(_synth.stopNote(_soundfontId!, note.pitch)));
      });
    }
    _schedule(ordered.last.end + const Duration(milliseconds: 80), generation,
        () {
      _timers.clear();
      onComplete?.call();
    });
  }

  Future<void> stop() async {
    _generation++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    if (_synth.isInitialized) await _synth.panic();
  }

  Future<void> _prepare() async {
    await _synth.configurePlaybackSession();
    if (!_synth.isInitialized) await _synth.initialize();
    _soundfontId ??= await _synth.loadGrandPiano(soundfontAsset);
    await _synth.selectGrandPiano(_soundfontId!);
    await _synth.configureSound(_soundfontId!);
  }

  void _schedule(Duration delay, int generation, void Function() action) {
    _timers.add(Timer(delay.isNegative ? Duration.zero : delay, () {
      if (generation == _generation) action();
    }));
  }

  Future<void> _ignoreErrors(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // A route change can invalidate a scheduled native call; the player
      // remains stoppable and the next preview re-initializes the synth.
    }
  }
}
