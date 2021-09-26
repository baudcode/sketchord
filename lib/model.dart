import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:sound/note_views/appbar.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

const EMPTY_TEXT = "Empty";

RangeValues deserializeRangeValues(String c) {
  if (c == null) return null;

  try {
    var range = c.split(",").map<double>((b) => double.parse(b)).toList();
    return RangeValues(range[0], range[1]);
  } catch (e) {
    return null;
  }
}

String serializeRangeValues(RangeValues v) {
  if (v == null) return null;
  return "${v.start},${v.end}";
}

class AudioFile {
  String path, id, name;
  DateTime createdAt, lastModified;
  RangeValues loopRange;

  File get file => File(path);
  String get loopString => loopRange == null
      ? null
      : "${(loopRange.end - loopRange.start).toStringAsFixed(1)}";

  Duration duration; // duration is milliseconds
  AudioFile(
      {@required this.path,
      @required this.duration,
      this.id,
      this.createdAt,
      this.lastModified,
      this.name,
      this.loopRange}) {
    //print("creating audio file with ${this.name} ${this.id}");
    if (id == null) id = Uuid().v4().toString();
    if (createdAt == null) createdAt = DateTime.now();
    if (lastModified == null) lastModified = DateTime.now();
    if (name == null) {
      name = path
          .split('/')
          .last
          .replaceAll(".mp4", "")
          .replaceAll(".m4a", "")
          .replaceAll(".mp3", "")
          .replaceAll('.wav', '');
    }
  }

  factory AudioFile.create(
      {String path, Duration duration, String id, String name}) {
    return AudioFile(
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        path: path,
        duration: duration,
        id: id,
        name: name);
  }

  factory AudioFile.fromJson(Map<dynamic, dynamic> map) {
    return AudioFile(
        createdAt: deserializeDateTime(map["createdAt"]),
        lastModified: deserializeDateTime(map["lastModified"]),
        duration: deserializeDuration(map["duration"]),
        loopRange: deserializeRangeValues(map['loopRange']),
        id: map["id"],
        name: map['name'],
        path: map["path"]);
  }

  Map<String, dynamic> toJson() {
    return {
      "createdAt": serializeDateTime(createdAt),
      "lastModified": serializeDateTime(lastModified),
      "loopRange": serializeRangeValues(loopRange),
      "id": id,
      "path": path,
      "name": name,
      "duration": serializeDuration(duration)
    };
  }

  @override
  int get hashCode => id.hashCode;

  bool operator ==(o) => o is AudioFile && id == o.id;

  String get durationString =>
      (duration.inMilliseconds / 1000).toStringAsFixed(1) + " s";
}

class Section {
  String title, content;
  String id;
  DateTime lastModified, createdAt;

  Section(
      {this.title, this.content, this.id, this.createdAt, this.lastModified}) {
    if (id == null) id = Uuid().v4().toString();
    if (lastModified == null) lastModified = DateTime.now();
    if (createdAt == null) createdAt = DateTime.now();
  }

  factory Section.fromJson(Map<dynamic, dynamic> map) {
    return Section(
      content: map['content'],
      title: map['title'],
      id: map['id'],
      createdAt: map.containsKey("createdAt")
          ? deserializeDateTime(map['createdAt'])
          : DateTime.now(),
      lastModified: map.containsKey("lastModified")
          ? deserializeDateTime(map['lastModified'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "content": content,
      "id": id,
      "lastModified": serializeDateTime(lastModified),
      "createdAt": serializeDateTime(createdAt)
    };
  }

  bool get hasEmptyTitle => title == null || title.trim() == "";

  @override
  int get hashCode => id.hashCode;

  bool operator ==(o) => o is Section && id == o.id;
}

Duration deserializeDuration(String s) {
  return Duration(microseconds: int.parse(s));
}

String serializeDuration(Duration d) {
  return d.inMicroseconds.toString();
}

DateTime deserializeDateTime(String s) {
  if (s == null) return null;
  List<String> params = s.split("-");
  List<int> t = params.map<int>((i) => int.parse(i)).toList();
  return DateTime(t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]);
}

String serializeDateTime(DateTime t) {
  return "${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute}-${t.second}-${t.microsecond}-${t.millisecond}";
}

String serializeColor(Color color) {
  return "${color.alpha};${color.red};${color.green};${color.blue}";
}

Color deserializeColor(dynamic data) {
  if (data == null || data is List) return null;
  try {
    List<int> args =
        (data as String).split(";").map((e) => int.parse(e)).toList();
    return Color.fromARGB(args[0], args[1], args[2], args[3]);
  } catch (e) {
    print("error: could not parse color $data");
  }
  return null;
}

class Note {
  List<Section> sections;
  String id;
  List<AudioFile> audioFiles;
  String title;
  String key;
  String tuning;
  String label;
  String instrument;
  bool starred;
  String capo;
  String artist;
  DateTime createdAt, lastModified;
  bool discarded;
  Color color;

  int bpm; // beats per minute
  int length; // length in seconds

  double scrollOffset;
  double zoom; // text scaling factor

  bool get hasEmptyTitle {
    return this.title == null || this.title.trim() == "";
  }

  factory Note.empty() {
    return Note(
        title: "",
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        key: null,
        tuning: null,
        id: Uuid().v4(),
        capo: null,
        instrument: "Guitar",
        label: "",
        artist: null,
        starred: false,
        sections: [Section(content: "", title: "")],
        color: null,
        bpm: null,
        zoom: 1.0,
        scrollOffset: 1.0,
        length: null, // seconds
        audioFiles: []);
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "createdAt": serializeDateTime(createdAt),
      "lastModified": serializeDateTime(lastModified),
      "key": key,
      "tuning": tuning,
      "capo": capo,
      "instrument": instrument,
      "label": label,
      "artist": artist,
      "starred": (starred) ? 1 : 0,
      "scrollOffset": scrollOffset,
      "zoom": zoom,
      "bpm": bpm,
      "length": length,
      "color": color == null ? null : serializeColor(color),
      "sections":
          sections.map<Map<dynamic, dynamic>>((s) => s.toJson()).toList(),
      "audioFiles":
          audioFiles.map<Map<dynamic, dynamic>>((a) => a.toJson()).toList(),
      "discarded": discarded ? 1 : 0,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json, String id) {
    return Note(
        // general info
        id: id,
        title: json['title'],
        createdAt: json.containsKey('createdAt')
            ? deserializeDateTime(json['createdAt'])
            : DateTime.now(),
        lastModified: json.containsKey("lastModified")
            ? deserializeDateTime(json['lastModified'])
            : DateTime.now(),
        length: json.containsKey('length') ? json['length'] : null,
        // additional info
        key: json.containsKey("key") ? json['key'] : null,
        tuning: json.containsKey("tuning") ? json['tuning'] : null,
        capo: json.containsKey("capo") ? json['capo'] : null,
        instrument: json.containsKey("instrument") ? json['instrument'] : null,
        label: json.containsKey("label") ? json['label'] : null,
        bpm: json.containsKey("bpm") ? json['bpm'] : null,
        starred: json.containsKey("starred") ? json['starred'] == 1 : false,
        color:
            json.containsKey("color") ? deserializeColor(json['color']) : null,
        discarded:
            json.containsKey("discarded") ? json['discarded'] == 1 : false,
        artist: json.containsKey("artist") ? json['artist'] : null,

        // viewer info
        zoom: json.containsKey("zoom") ? json['zoom'] : 1.0,
        scrollOffset:
            json.containsKey("scrollOffset") ? json['scrollOffset'] : 1.0,

        // sections/audiofiles
        sections: json.containsKey("sections")
            ? json['sections'].map<Section>((s) => Section.fromJson(s)).toList()
            : [],
        audioFiles: json.containsKey("audioFiles")
            ? json['audioFiles']
                .map<AudioFile>((s) => AudioFile.fromJson(s))
                .toList()
            : []);
  }
  String getInfoText() {
    List<String> info = [];
    if (capo != null) {
      info.add("Capo: $capo");
    }
    if (key != null) {
      info.add("Key: $key");
    }
    if (tuning != null) {
      info.add("Tuning: $tuning");
    }
    if (info.length == 0) return null;
    return info.join(" | ");
  }

  Note(
      {this.id,
      this.title,
      this.createdAt,
      this.lastModified,
      this.key,
      this.tuning,
      this.capo,
      this.instrument,
      this.label,
      this.sections,
      this.audioFiles,
      this.artist,
      this.color,
      this.bpm,
      this.length,
      this.zoom = 1.0,
      this.scrollOffset = 1.0,
      this.starred = false,
      this.discarded = false}) {
    if (this.id == null) {
      this.id = Uuid().v4();
    }
  }
}

enum SettingsTheme { dark, light }
enum EditorView { onePage, tabs }
enum NoteListType { single, double }
enum SortBy { created, lastModified, az }
enum SortDirection { up, down }

String serializeTheme(SettingsTheme theme) {
  return theme == SettingsTheme.dark ? "dark" : "light";
}

String serializeEditorView(EditorView view) {
  return view == EditorView.onePage ? "onePage" : "tabs";
}

String serializeNoteListType(NoteListType view) {
  return view == NoteListType.single ? "single" : "double";
}

String serializeAudioFormat(AudioFormat audioFormat) {
  return audioFormat == AudioFormat.AAC ? "aac" : "wav";
}

String serializeSortDirection(SortDirection direction) {
  return direction == SortDirection.up ? "up" : "down";
}

String serializeSortBy(SortBy by) {
  switch (by) {
    case SortBy.created:
      return "created";
    case SortBy.lastModified:
      return "lastModified";
    case SortBy.az:
      return "az";
    default:
      return "lastModified";
  }
}

SortBy deserializeSortBy(String by) {
  switch (by) {
    case "created":
      return SortBy.created;
    case "lastModified":
      return SortBy.lastModified;
    case "az":
      return SortBy.az;
    default:
      return SortBy.lastModified;
  }
}

class Settings {
  SettingsTheme theme;
  NoteListType noteListType; // single, double
  AudioFormat audioFormat; // aac, wav
  String name;
  EditorView editorView;
  bool isInitialStart;
  SortBy sortBy;
  SortDirection sortDirection;
  double sectionContentFontSize;

  Settings(
      {this.theme,
      this.noteListType,
      this.audioFormat,
      this.name,
      this.isInitialStart,
      this.sortBy,
      this.sortDirection,
      this.editorView,
      this.sectionContentFontSize});

  Map<String, dynamic> toJson() {
    return {
      "theme": serializeTheme(theme),
      "editorView": serializeEditorView(editorView),
      "audioFormat": serializeAudioFormat(audioFormat),
      "sortBy": serializeSortBy(sortBy),
      "sortDirection": serializeSortDirection(sortDirection),
      "name": name,
      "isInitialStart": isInitialStart,
      "noteListType": serializeNoteListType(noteListType),
      "sectionContentFontSize": sectionContentFontSize
    };
  }

  factory Settings.defaults() {
    return Settings(
        audioFormat: AudioFormat.WAV,
        theme: SettingsTheme.dark,
        isInitialStart: false,
        sortBy: SortBy.created,
        sortDirection: SortDirection.down,
        name: null,
        sectionContentFontSize: 10,
        noteListType: NoteListType.double,
        editorView: EditorView.tabs);
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
        theme:
            json['theme'] == 'dark' ? SettingsTheme.dark : SettingsTheme.light,
        editorView: json['editorView'] == "onePage"
            ? EditorView.onePage
            : EditorView.tabs,
        noteListType: json['noteListType'] == "double"
            ? NoteListType.double
            : NoteListType.single,
        name: json.containsKey("name") ? json['name'] : null,
        isInitialStart:
            json.containsKey("isInitialStart") ? json['isInitialStart'] : false,
        audioFormat:
            json["audioFormat"] == "aac" ? AudioFormat.AAC : AudioFormat.WAV,
        sortDirection: json.containsKey("sortDirection")
            ? json['sortDirection'] == "up"
                ? SortDirection.up
                : SortDirection.down
            : SortDirection.up,
        sectionContentFontSize: json.containsKey("sectionContentFontSize") &&
                json['sectionContentFontSize'] != null
            ? json['sectionContentFontSize']
            : 10,
        sortBy: json.containsKey('sortBy')
            ? deserializeSortBy(json['sortBy'])
            : SortBy.lastModified);
  }
}

class NoteCollection {
  String id;
  List<Note> notes;
  String title, description;
  bool starred;

  DateTime lastModified, createdAt;

  NoteCollection(
      {this.id,
      this.notes,
      this.title,
      this.starred,
      this.description,
      this.createdAt,
      this.lastModified});

  List<Note> get activeNotes =>
      notes.where((element) => !element.discarded).toList();

  factory NoteCollection.empty() {
    return NoteCollection(
        id: Uuid().v4(),
        notes: [],
        title: "",
        description: "",
        starred: false,
        createdAt: DateTime.now(),
        lastModified: DateTime.now());
  }
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "notes": notes.map((e) => e.toJson()).toList(),
      "title": title,
      "description": description,
      "starred": starred ? 1 : 0,
      "createdAt": createdAt == null ? null : serializeDateTime(createdAt),
      "lastModified":
          lastModified == null ? null : serializeDateTime(lastModified),
    };
  }

  bool get empty =>
      title.trim() == "" && description.trim() == "" && notes.length == 0;

  factory NoteCollection.fromJson(Map<String, dynamic> json) {
    return NoteCollection(
      id: json.containsKey("id") ? json['id'] : Uuid().v4(),
      notes: json.containsKey("notes")
          ? json['notes'].map<Note>((n) => Note.fromJson(n, n['id'])).toList()
          : [],
      title: json.containsKey("title") ? json['title'] : "",
      description: json.containsKey("description") ? json['description'] : "",
      starred: json.containsKey("starred") ? json['starred'] == 1 : false,
      lastModified: json.containsKey("lastModified")
          ? deserializeDateTime(json['lastModified'])
          : DateTime.now(),
      createdAt: json.containsKey("createdAt")
          ? deserializeDateTime(json['createdAt'])
          : DateTime.now(),
    );
  }
}
