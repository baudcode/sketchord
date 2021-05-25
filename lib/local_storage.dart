import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// table defintions
final String noteTable = 'notes';
final String sectionTable = 'sections';
final String audioFileTable = 'audiofiles';
final String noteSetTable = 'sets';

// up and downgrades of the database
final migrations = {
  4: {
    5: [
      //upgrade
      "CREATE TABLE $noteSetTable(id TEXT PRIMARY KEY, title TEXT, description TEXT, createdAt TEXT, lastModified TEXT);",
      "ALTER TABLE $noteTable ADD setId TEXT;"
    ]
  },
  5: {
    4: [
      // downgrade
      "DROP TABLE $noteSetTable;",
      "ALTER TABLE $noteTable DROP COLUMN setId;"
    ]
  }
};

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

  Future<Database> getDatabase() async {
    return openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'sketchord.db'),
      // When the database is first created, create a table to store dogs.
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        createDatabase(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        print("performing upgrade from $oldVersion to $newVersion");
        migrations[oldVersion][newVersion]
            .forEach((script) async => await db.execute(script));
      },
      onDowngrade: (Database db, int oldVersion, int newVersion) {
        print("performing downgrade from $oldVersion to $newVersion");
        migrations[oldVersion][newVersion]
            .forEach((script) async => await db.execute(script));
      },
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );
  }

  Future<void> createDatabase(Database db) async {
    // create initial database
    print("creating initial tables");
    await db.execute(
      """CREATE TABLE $noteTable(id TEXT PRIMARY KEY, title TEXT, createdAt TEXT, lastModified TEXT, 
          key TEXT, tuning TEXT, capo TEXT, instrument TEXT, label TEXT, artist TEXT, color TEXT, bpm REAL, zoom REAL, 
          scrollOffset REAL, starred INTEGER, discarded INTEGER);
          """,
    );
    await db.execute(
        'CREATE TABLE $sectionTable(id TEXT PRIMARY KEY, noteId TEXT, title TEXT, content TEXT, idx INTEGER);');

    await db.execute(
        'CREATE TABLE $audioFileTable(id TEXT PRIMARY KEY, noteId TEXT, idx INTEGER, duration TEXT, path TEXT, createdAt TEXT, lastModified TEXT, name TEXT, loopRange TEXT);');
  }

  Future<int> syncNote(Note note) async {
    print("Syncing note ${note.id} with title ${note.title}");
    final db = await getDatabase();

    for (int i = 0; i < note.sections.length; i++) {
      Map<String, dynamic> sectionData = note.sections[i].toJson();
      sectionData['idx'] = i;
      sectionData['noteId'] = note.id;

      await db.insert(sectionTable, sectionData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (int i = 0; i < note.audioFiles.length; i++) {
      Map<String, dynamic> autdioFileData = note.audioFiles[i].toJson();
      autdioFileData['idx'] = i;
      autdioFileData['noteId'] = note.id;

      await db.insert(audioFileTable, autdioFileData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Map<String, dynamic> data = note.toJson();
    data.remove('sections');
    data.remove('audioFiles');

    int row = await db.insert(noteTable, data,
        conflictAlgorithm: ConflictAlgorithm.replace);

    print("Done Syncing ${note.id} in row $row");
    _controller.sink.add(await getNotes());
    return row;
  }

  Future<List<Section>> getSections(String noteId) async {
    List<Map<String, dynamic>> maps = await (await getDatabase())
        .query(sectionTable, where: 'noteId = ?', whereArgs: [noteId]);

    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    if (maps == null) return [];

    // copy maps to sort them properly
    maps.sort((s1, s2) => s1['idx'] - s2['idx']);
    return maps.map((s) => Section.fromJson(s)).toList();
  }

  Future<List<AudioFile>> getAudioFiles(String noteId) async {
    List<Map<String, dynamic>> maps = await (await getDatabase())
        .query(audioFileTable, where: 'noteId = ?', whereArgs: [noteId]);
    if (maps == null) return [];

    // copy maps to sort them properly
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    maps.sort((s1, s2) => s1['idx'] - s2['idx']);
    return maps.map((s) => AudioFile.fromJson(s)).toList();
  }

  Future<Note> getNote(Map<String, dynamic> data) async {
    String noteId = data['id'];
    if (noteId == null) return null;

    Note note = Note.fromJson(data, noteId);
    note.sections = await getSections(noteId);
    note.audioFiles = await getAudioFiles(noteId);
    return note;
  }

  Future<List<Note>> getNotes() async {
    final List<Map<String, dynamic>> maps =
        await (await getDatabase()).query(noteTable);

    if (maps == null) return [];

    List<Note> notes = [];

    for (var map in maps) {
      Note note = await getNote(map);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  Future<bool> _deleteAudioFile(AudioFile audioFile) async {
    FileSystemEntity e = await audioFile.file.delete();
    return !e.existsSync();
  }

  Future<void> deleteNote(Note note) async {
    final db = await getDatabase();

    await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [note.id],
    );

    for (AudioFile f in note.audioFiles) {
      await _deleteAudioFile(f);
    }
    _controller.sink.add(await getNotes());
  }

  Future<int> _update(String table, Map<String, dynamic> data,
      {String where = 'id = ?'}) async {
    final db = await getDatabase();

    return await db.update(
      table,
      data,
      where: where,
      whereArgs: [data['id']],
    );
  }

  Future<void> discardNote(Note note) async {
    note.discarded = true;
    _updateNote(note);
  }

  Future<void> _updateNote(Note note) async {
    // this function does not update sections and audio files
    var data = note.toJson();
    data.remove("sections");
    data.remove("audioFiles");

    await _update(noteTable, data);
    _controller.sink.add(await getNotes());
  }

  Future<void> restoreNote(Note note) async {
    note.discarded = false;
    await _updateNote(note);
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

  Future<List<Note>> getActiveNotes() async {
    return (await getNotes()).where((n) => !n.discarded).toList();
  }

  Future<List<Note>> getDiscardedNotes() async {
    return (await getNotes()).where((n) => n.discarded).toList();
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
}
