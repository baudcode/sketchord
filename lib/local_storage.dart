import 'dart:convert';
import 'dart:io';
import 'model.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._internal();
  static final LocalStorage _singleton = new LocalStorage._internal();

  final StreamController<List<Note>> _controller =
      StreamController<List<Note>>.broadcast();

  StreamController<List<Note>> get controller => _controller;

  Stream<List<Note>> get stream => _controller.stream.asBroadcastStream();
  factory LocalStorage() {
    return _singleton;
  }

  Future<void> deleteFile(File f) {
    return f.delete();
  }

  Future<void> syncNote(Note note) async {
    print("syncing note ${note.id}, ${note.title}");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    note.lastModified = DateTime.now();
    await prefs.setString(note.id.toString(), jsonEncode(note.toJson()));

    var noteIDs = await getNoteIDs(prefs);
    if (!noteIDs.contains(note.id.toString())) {
      noteIDs.add(note.id.toString());
      prefs.setStringList('notes', noteIDs);
    }
    _controller.sink.add(await getNotes());
  }

  Future<bool> _deleteAudioFile(AudioFile audioFile) async {
    FileSystemEntity e = await audioFile.file.delete();
    return !e.existsSync();
  }

  Future<void> deleteNote(Note note) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(note.id);
    for (AudioFile f in note.audioFiles) {
      await _deleteAudioFile(f);
    }
    _controller.sink.add(await getNotes());
  }

  Future<void> discardNote(Note note) async {
    note.discarded = true;
    return await syncNote(note);
  }

  Future<void> restoreNote(Note note) async {
    note.discarded = false;
    return await syncNote(note);
  }

  Future<void> syncNoteAttr(Note note, String attr) async {
    await syncNote(note);
    _controller.sink.add(await getNotes());
  }

  Future<List<String>> getNoteIDs(SharedPreferences prefs) async {
    var ids = prefs.getStringList('notes');
    if (ids == null)
      return [];
    else
      return ids;
  }

  Note getNote(String id, SharedPreferences prefs) {
    var str = prefs.get(id);
    if (str == null) return null;
    return Note.fromJson(jsonDecode(str), id);
  }

  Future<List<Note>> getActiveNotes() async {
    return (await getNotes()).where((n) => !n.discarded).toList();
  }

  Future<List<Note>> getDiscardedNotes() async {
    return (await getNotes()).where((n) => n.discarded).toList();
  }

  Future<List<Note>> getNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> ids = await getNoteIDs(prefs);
    // print(ids);
    var notes = ids
        .map((id) => getNote(id, prefs))
        .where((note) => note != null)
        .toList();
    return notes;
  }
}
