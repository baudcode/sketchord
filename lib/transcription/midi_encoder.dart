import 'dart:typed_data';

import 'types.dart';

class MidiEncoder {
  static const ticksPerQuarter = 480;

  /// Encodes a standards-compliant single-track MIDI file. Notes that share a
  /// timestamp emit note-off before note-on, avoiding accidental stuck notes.
  static Uint8List encode(
    List<MidiNote> notes, {
    double tempoBpm = 120,
  }) {
    if (tempoBpm <= 0) throw ArgumentError.value(tempoBpm, 'tempoBpm');
    final events = <_MidiEvent>[];
    for (final note in notes) {
      events
        ..add(_MidiEvent(_toTicks(note.start, tempoBpm), false, note))
        ..add(_MidiEvent(_toTicks(note.end, tempoBpm), true, note));
    }
    events.sort((a, b) {
      final byTime = a.tick.compareTo(b.tick);
      return byTime != 0 ? byTime : (a.isOff ? -1 : 1);
    });
    final track = BytesBuilder();
    final microsPerQuarter = (60000000 / tempoBpm).round();
    track.add([
      0,
      0xff,
      0x51,
      0x03,
      (microsPerQuarter >> 16) & 0xff,
      (microsPerQuarter >> 8) & 0xff,
      microsPerQuarter & 0xff
    ]);
    var previousTick = 0;
    for (final event in events) {
      track.add(_variableLength(event.tick - previousTick));
      previousTick = event.tick;
      track.add([
        event.isOff ? 0x80 : 0x90,
        event.note.pitch,
        event.isOff ? 0 : event.note.velocity
      ]);
    }
    track.add([0, 0xff, 0x2f, 0]);
    final output = BytesBuilder()
      ..add('MThd'.codeUnits)
      ..add([0, 0, 0, 6, 0, 0, 0, 1, 1, 0xe0])
      ..add('MTrk'.codeUnits)
      ..add(_uint32(track.length))
      ..add(track.toBytes());
    return output.toBytes();
  }

  static int _toTicks(Duration value, double tempo) =>
      (value.inMicroseconds * ticksPerQuarter * tempo / 60000000).round();

  static List<int> _uint32(int value) => [
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ];

  static List<int> _variableLength(int value) {
    var buffer = value & 0x7f;
    while ((value >>= 7) > 0) {
      buffer <<= 8;
      buffer |= (value & 0x7f) | 0x80;
    }
    final bytes = <int>[];
    while (true) {
      bytes.add(buffer & 0xff);
      if (buffer & 0x80 == 0) return bytes;
      buffer >>= 8;
    }
  }
}

class _MidiEvent {
  const _MidiEvent(this.tick, this.isOff, this.note);

  final int tick;
  final bool isOff;
  final MidiNote note;
}
