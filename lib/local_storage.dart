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

  Future<void> syncSet(NoteSet noteset) async {
    print("syncing noteset ${noteset.id}, ${noteset.name}");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    noteset.lastModified = DateTime.now();

    await prefs.setString(noteset.id.toString(), jsonEncode(noteset.toJson()));

    var setIDs = await getSetIDs(prefs);
    if (!setIDs.contains(noteset.id.toString())) {
      setIDs.add(noteset.id.toString());
      prefs.setStringList('sets', setIDs);
    }

    //_controller.sink.add(await getNotes());
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

  Future<void> deleteSet(NoteSet noteset) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(noteset.id);
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

  Future<bool> isInitialStart() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool started = prefs.getBool('started');
    return started == null ? true : !started;
  }

  Future<void> setInitialStartDone() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('started', true);
  }

  Future<List<String>> getNoteIDs(SharedPreferences prefs) async {
    var ids = prefs.getStringList('notes');
    if (ids == null)
      return [];
    else
      return ids;
  }

  Future<List<String>> getSetIDs(SharedPreferences prefs) async {
    var ids = prefs.getStringList('sets');
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
    return (await getNotes()).where((n) => !n.discarded && !n.isIdea).toList();
  }

  Future<List<Note>> getDiscardedNotes() async {
    return (await getNotes()).where((n) => n.discarded).toList();
  }

  Future<List<Note>> getIdeas() async {
    return (await getNotes()).where((n) => n.isIdea == true).toList();
  }

  Future<NoteSet> getSet(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var str = prefs.get(id);
    if (str == null) return null;
    var data = jsonDecode(str);
    data['notes'] = [];

    for (var noteId in data['ids']) {
      var noteData = prefs.get(noteId);
      if (noteData != null) data['notes'].add(jsonDecode(noteData));
    }

    return NoteSet.fromJson(data);
  }

  Future<List<NoteSet>> getSets() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> ids = await getSetIDs(prefs);
    // print(ids);
    List<NoteSet> sets = [];
    for (String id in ids) {
      sets.add(await getSet(id));
    }
    return sets;
  }

  Future<bool> syncSettings(Settings settings) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString("settings", jsonEncode(settings.toJson()));
  }

  Future<Settings> getSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String data = prefs.getString('settings');
    if (data == null) return null;
    return Settings.fromJson(jsonDecode(data));
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
