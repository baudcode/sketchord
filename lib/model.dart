import 'package:flutter/material.dart';
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
      {this.path,
      this.duration,
      this.id,
      this.createdAt,
      this.lastModified,
      this.name,
      this.loopRange}) {
    if (id == null) id = Uuid().v4().toString();
    if (createdAt == null) createdAt = DateTime.now();
    if (name == null)
      name = path
          .split('/')
          .last
          .replaceAll(".mp4", "")
          .replaceAll(".m4a", "")
          .replaceAll('.wav', '');
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
        path: map["path"]);
  }

  Map<dynamic, dynamic> toJson() {
    return {
      "createdAt": serializeDateTime(createdAt),
      "downloadURL": downloadURL,
      "loopRange": serializeRangeValues(loopRange),
      "id": id,
      "path": path,
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
  DateTime createdAt, lastModified;
  bool discarded;

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
        starred: false,
        sections: [Section(content: "", title: "")],
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
      "starred": starred,
      "sections":
          sections.map<Map<dynamic, dynamic>>((s) => s.toJson()).toList(),
      "audioFiles":
          audioFiles.map<Map<dynamic, dynamic>>((a) => a.toJson()).toList(),
      "discarded": discarded,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json, String id) {
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
      starred: json['starred'],
      discarded: json.containsKey("discarded") ? json['discarded'] : false,
      sections:
          json['sections'].map<Section>((s) => Section.fromJson(s)).toList(),
      audioFiles: json['audioFiles']
          .map<AudioFile>((s) => AudioFile.fromJson(s))
          .toList(),
    );
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
      this.starred = false,
      this.discarded = false}) {
    if (this.id == null) {
      this.id = Uuid().v4();
    }
  }
}
