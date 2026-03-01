import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const EMPTY_TEXT = 'Empty';

RangeValues? deserializeRangeValues(String? c) {
  if (c == null || c.isEmpty) return null;
  try {
    final range = c.split(',').map<double>((b) => double.parse(b)).toList();
    return RangeValues(range[0], range[1]);
  } catch (_) {
    return null;
  }
}

String? serializeRangeValues(RangeValues? v) {
  if (v == null) return null;
  return '${v.start},${v.end}';
}

class AudioFile {
  String path;
  String id;
  String name;
  DateTime createdAt;
  DateTime lastModified;
  RangeValues? loopRange;
  Duration duration;
  String text;
  bool starred;

  File get file => File(path);
  String? get loopString => loopRange == null
      ? null
      : (loopRange!.end - loopRange!.start).toStringAsFixed(1);

  AudioFile({
    required this.path,
    required this.duration,
    String? id,
    DateTime? createdAt,
    DateTime? lastModified,
    String? name,
    String? text,
    bool? starred,
    this.loopRange,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        text = text ?? '',
        starred = starred ?? false,
        name = name ??
            path
                .split('/')
                .last
                .replaceAll('.mp4', '')
                .replaceAll('.m4a', '')
                .replaceAll('.mp3', '')
                .replaceAll('.wav', '');

  factory AudioFile.create({
    required String path,
    required Duration duration,
    String? id,
    String? name,
    String? text,
    bool? starred,
  }) {
    return AudioFile(
      path: path,
      duration: duration,
      id: id,
      name: name,
      text: text,
      starred: starred,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    );
  }

  factory AudioFile.fromJson(Map<dynamic, dynamic> map) {
    return AudioFile(
      createdAt: deserializeDateTime(map['createdAt']),
      lastModified: deserializeDateTime(map['lastModified'] ?? map['createdAt']),
      duration: deserializeDuration(map['duration']),
      loopRange: deserializeRangeValues(map['loopRange']),
      id: map['id'],
      name: map['name'],
      path: map['path'],
      text: map['text'] ?? '',
      starred: (map['starred'] ?? 0) == 1 || map['starred'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': serializeDateTime(createdAt),
      'lastModified': serializeDateTime(lastModified),
      'loopRange': serializeRangeValues(loopRange),
      'id': id,
      'path': path,
      'name': name,
      'text': text,
      'starred': starred ? 1 : 0,
      'duration': serializeDuration(duration),
    };
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object o) => o is AudioFile && id == o.id;

  String get durationString =>
      '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
}

class Section {
  String title;
  String content;
  String id;
  DateTime lastModified;
  DateTime createdAt;

  Section({
    String? title,
    String? content,
    String? id,
  })  : title = title ?? '',
        content = content ?? '',
        id = id ?? const Uuid().v4(),
        lastModified = DateTime.now(),
        createdAt = DateTime.now();

  factory Section.fromJson(Map<dynamic, dynamic> map) {
    return Section(
      content: map['content'],
      title: map['title'],
      id: map['id'],
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'content': content, 'id': id};

  bool get hasEmptyTitle => title.trim().isEmpty;

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object o) => o is Section && id == o.id;
}

Duration deserializeDuration(String s) => Duration(microseconds: int.parse(s));
String serializeDuration(Duration d) => d.inMicroseconds.toString();

DateTime deserializeDateTime(String? s) {
  if (s == null || s.isEmpty) return DateTime.now();
  final params = s.split('-');
  final t = params.map<int>((i) => int.parse(i)).toList();
  return DateTime(t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]);
}

String serializeDateTime(DateTime t) =>
    '${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute}-${t.second}-${t.microsecond}-${t.millisecond}';

List<int>? serializeColor(Color? color) {
  if (color == null) return null;
  return [
    (color.a * 255.0).round() & 0xff,
    (color.r * 255.0).round() & 0xff,
    (color.g * 255.0).round() & 0xff,
    (color.b * 255.0).round() & 0xff,
  ];
}

Color? deserializeColor(List<dynamic>? data) {
  if (data == null) return null;
  return Color.fromARGB(data[0], data[1], data[2], data[3]);
}

class Note {
  List<Section> sections;
  String id;
  List<AudioFile> audioFiles;
  String title;
  String? key;
  String? tuning;
  String? label;
  String? instrument;
  bool starred;
  String? capo;
  String? artist;
  DateTime createdAt;
  DateTime lastModified;
  bool discarded;
  Color? color;
  int? bpm;
  int? length;
  double scrollOffset;
  double zoom;

  factory Note.empty() {
    return Note(
      title: '',
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      id: const Uuid().v4(),
      instrument: 'Guitar',
      label: '',
      starred: false,
      sections: [Section(content: '', title: '')],
      zoom: 1.0,
      scrollOffset: 1.0,
      audioFiles: [],
    );
  }

  Note({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastModified,
    this.key,
    this.tuning,
    this.capo,
    this.instrument,
    this.label,
    List<Section>? sections,
    List<AudioFile>? audioFiles,
    this.artist,
    this.color,
    this.bpm,
    this.length,
    this.zoom = 1.0,
    this.scrollOffset = 1.0,
    this.starred = false,
    this.discarded = false,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? '',
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        sections = sections ?? [],
        audioFiles = audioFiles ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': serializeDateTime(createdAt),
      'lastModified': serializeDateTime(lastModified),
      'key': key,
      'tuning': tuning,
      'capo': capo,
      'instrument': instrument,
      'label': label,
      'artist': artist,
      'starred': starred ? 1 : 0,
      'scrollOffset': scrollOffset,
      'zoom': zoom,
      'bpm': bpm,
      'length': length,
      'color': serializeColor(color),
      'sections': sections.map((s) => s.toJson()).toList(),
      'audioFiles': audioFiles.map((a) => a.toJson()).toList(),
      'discarded': discarded ? 1 : 0,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json, String id) {
    final sectionsRaw = json['sections'] as List<dynamic>?;
    final audioRaw = json['audioFiles'] as List<dynamic>?;
    return Note(
      id: id,
      title: json['title'],
      createdAt: deserializeDateTime(json['createdAt']),
      lastModified: deserializeDateTime(json['lastModified']),
      key: json['key'],
      tuning: json['tuning'],
      capo: json['capo'],
      instrument: json['instrument'],
      label: json['label'],
      bpm: json['bpm'],
      length: json['length'] == null ? null : (json['length'] as num).toInt(),
      starred: (json['starred'] ?? 0) == 1 || json['starred'] == true,
      color: deserializeColor((json['color'] as List?)?.cast<dynamic>()),
      discarded: (json['discarded'] ?? 0) == 1 || json['discarded'] == true,
      artist: json['artist'],
      zoom: (json['zoom'] ?? 1.0).toDouble(),
      scrollOffset: (json['scrollOffset'] ?? 1.0).toDouble(),
      sections: sectionsRaw == null
          ? []
          : sectionsRaw.map((s) => Section.fromJson(s)).toList(),
      audioFiles:
          audioRaw == null ? [] : audioRaw.map((s) => AudioFile.fromJson(s)).toList(),
    );
  }

  bool get hasEmptyTitle => title.trim().isEmpty;

  String get lengthStr {
    if (length == null) return '';
    final totalSeconds = length!;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String? getInfoText() {
    final info = <String>[];
    if (capo != null && capo!.isNotEmpty) info.add('Capo: $capo');
    if (key != null && key!.isNotEmpty) info.add('Key: $key');
    if (tuning != null && tuning!.isNotEmpty) info.add('Tuning: $tuning');
    if (info.isEmpty) return null;
    return info.join(' | ');
  }
}

class NoteCollection {
  String id;
  List<Note> notes;
  String title;
  String description;
  bool starred;
  DateTime createdAt;
  DateTime lastModified;

  NoteCollection({
    String? id,
    List<Note>? notes,
    String? title,
    String? description,
    bool? starred,
    DateTime? createdAt,
    DateTime? lastModified,
  })  : id = id ?? const Uuid().v4(),
        notes = notes ?? [],
        title = title ?? '',
        description = description ?? '',
        starred = starred ?? false,
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  factory NoteCollection.empty() => NoteCollection();

  factory NoteCollection.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] as List<dynamic>?;
    return NoteCollection(
      id: json['id'],
      notes: rawNotes == null
          ? []
          : rawNotes
              .map((n) => Note.fromJson(
                  Map<String, dynamic>.from(n), (n['id'] ?? '') as String))
              .toList(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      starred: (json['starred'] ?? 0) == 1 || json['starred'] == true,
      createdAt: deserializeDateTime(json['createdAt']),
      lastModified: deserializeDateTime(json['lastModified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notes': notes.map((e) => e.toJson()).toList(),
      'title': title,
      'description': description,
      'starred': starred ? 1 : 0,
      'createdAt': serializeDateTime(createdAt),
      'lastModified': serializeDateTime(lastModified),
    };
  }

  List<Note> get activeNotes => notes.where((element) => !element.discarded).toList();

  int get length => notes.fold<int>(0, (p, e) => p + (e.length ?? 0));

  String get lengthStr {
    if (length == 0) return '';
    final hours = length ~/ 3600;
    final minutes = (length % 3600) ~/ 60;
    final seconds = length % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get empty => title.trim().isEmpty && description.trim().isEmpty && notes.isEmpty;
}

enum SettingsTheme { dark, light }
enum EditorView { single, double }
enum AudioFormat { aac, wav }

class Settings {
  SettingsTheme theme;
  EditorView view;
  AudioFormat audioFormat;
  String? name;
  bool isInitialStart;

  Settings({
    required this.theme,
    required this.view,
    required this.audioFormat,
    this.name,
    this.isInitialStart = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'theme': theme == SettingsTheme.dark ? 'dark' : 'light',
      'view': view == EditorView.single ? 'single' : 'double',
      'audioFormat': audioFormat == AudioFormat.aac ? 'aac' : 'wav',
      'name': name,
      'isInitialStart': isInitialStart,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      theme: json['theme'] == 'dark' ? SettingsTheme.dark : SettingsTheme.light,
      view: json['view'] == 'single' ? EditorView.single : EditorView.double,
      name: json['name'],
      isInitialStart: json['isInitialStart'] ?? false,
      audioFormat: json['audioFormat'] == 'aac' ? AudioFormat.aac : AudioFormat.wav,
    );
  }
}
