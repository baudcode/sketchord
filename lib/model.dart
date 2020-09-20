import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

RangeValues deserializeRangeValues(dynamic c) {
  if (c == null) return null;
  var s = new Map<String, double>.from(c);
  return RangeValues(s['start'], s['end']);
}

Map<String, double> serializeRangeValues(RangeValues v) {
  if (v == null) return null;

  return {"start": v.start, "end": v.end};
}

class AudioFile {
  String path, id, name;
  String downloadURL;
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
    print("creating audio file with ${this.name} ${this.id}");
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
        lastModified: deserializeDateTime(map["createdAt"]),
        duration: deserializeDuration(map["duration"]),
        loopRange: deserializeRangeValues(map['loopRange']),
        id: map["id"],
        name: map['name'],
        path: map["path"]);
  }

  Map<dynamic, dynamic> toJson() {
    return {
      "createdAt": serializeDateTime(createdAt),
      "downloadURL": downloadURL,
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

  String get durationString => duration.inSeconds.toString() + " s";
}

class Section {
  String title, content;
  String id;
  DateTime lastModified, createdAt;

  Section({
    this.title,
    this.content,
    this.id,
  }) {
    if (id == null) id = Uuid().v4().toString();
    this.lastModified = DateTime.now();
    this.createdAt = DateTime.now();
  }

  factory Section.fromJson(Map<dynamic, dynamic> map) {
    return Section(content: map['content'], title: map['title'], id: map['id']);
  }

  Map<dynamic, dynamic> toJson() {
    return {"title": title, "content": content, "id": id};
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
  List<String> params = s.split("-");
  List<int> t = params.map<int>((i) => int.parse(i)).toList();
  return DateTime(t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]);
}

String serializeDateTime(DateTime t) {
  return "${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute}-${t.second}-${t.microsecond}-${t.millisecond}";
}

List<int> serializeColor(Color color) {
  return [color.alpha, color.red, color.green, color.blue];
}

Color deserializeColor(List<dynamic> data) {
  if (data == null) return null;
  return Color.fromARGB(data[0], data[1], data[2], data[3]);
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
  int bpm;

  double scrollOffset;
  double zoom; // text scaling factor

  factory Note.empty() {
    return Note(
        title: "",
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        key: null,
        tuning: null,
        id: null,
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
        audioFiles: []);
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "createdAt": serializeDateTime(createdAt),
      "lastModified": serializeDateTime(lastModified),
      "key": key,
      "tuning": tuning,
      "capo": capo,
      "instrument": instrument,
      "label": label,
      "artist": artist,
      "starred": starred,
      "scrollOffset": scrollOffset,
      "zoom": zoom,
      "bpm": bpm,
      "color": color == null ? null : serializeColor(color),
      "sections":
          sections.map<Map<dynamic, dynamic>>((s) => s.toJson()).toList(),
      "audioFiles":
          audioFiles.map<Map<dynamic, dynamic>>((a) => a.toJson()).toList(),
      "discarded": discarded,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json, String id) {
    return Note(
        // general info
        id: id,
        title: json['title'],
        createdAt: json.containsKey(json['createdAt'])
            ? deserializeDateTime(json['createdAt'])
            : DateTime.now(),
        lastModified: json.containsKey(json['lastModified'])
            ? deserializeDateTime(json['lastModified'])
            : DateTime.now(),

        // additional info
        key: json.containsKey("key") ? json['key'] : null,
        tuning: json.containsKey("tuning") ? json['tuning'] : null,
        capo: json.containsKey("capo") ? json['capo'] : null,
        instrument: json.containsKey("instrument") ? json['instrument'] : null,
        label: json.containsKey("label") ? json['label'] : null,
        bpm: json.containsKey("bpm") ? json['bpm'] : null,
        starred: json.containsKey("starred") ? json['starred'] : false,
        color:
            json.containsKey("color") ? deserializeColor(json['color']) : null,
        discarded: json.containsKey("discarded") ? json['discarded'] : false,
        artist: json.containsKey("artist") ? json['artist'] : null,

        // viewer info
        zoom: json.containsKey("zoom") ? json['zoom'] : 1.0,
        scrollOffset:
            json.containsKey("scrollOffset") ? json['scrollOffset'] : 1.0,

        // sections/audiofiles
        sections:
            json['sections'].map<Section>((s) => Section.fromJson(s)).toList(),
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
enum EditorView { single, double }

class Settings {
  SettingsTheme theme;
  EditorView view; // single, double
  AudioFormat audioFormat; // aac, wav
  String name;

  Settings({this.theme, this.view, this.audioFormat, this.name});

  Map<String, dynamic> toJson() {
    return {
      "theme": theme == SettingsTheme.dark ? "dark" : "light",
      "view": view == EditorView.single ? "single" : "double",
      "audioFormat": audioFormat == AudioFormat.AAC ? "aac" : "wav",
      "name": name
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
        theme:
            json['theme'] == 'dark' ? SettingsTheme.dark : SettingsTheme.light,
        view: json['view'] == "single" ? EditorView.single : EditorView.double,
        name: json.containsKey("name") ? json['name'] : null,
        audioFormat:
            json["audioFormat"] == "aac" ? AudioFormat.AAC : AudioFormat.WAV);
  }
}
