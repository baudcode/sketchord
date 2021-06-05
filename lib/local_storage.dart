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
final String collectionTable = 'collections';
final String collectionMappingTable = 'collectionmapping';

// up and downgrades of the database
final migrations = {
  1: {
    2: [
      //upgrade
      "CREATE TABLE $collectionTable(id TEXT PRIMARY KEY, title TEXT, description TEXT, createdAt TEXT, lastModified TEXT, starred INTEGER);",
      "CREATE TABLE $collectionMappingTable (noteId TEXT, collectionId TEXT);"
    ]
  },
  2: {
    1: [
      // downgrade
      "DROP TABLE $collectionTable;",
      "DROP TABLE $collectionMappingTable;",
    ],
  }
};

class LocalStorage {
  LocalStorage._internal();
  static final LocalStorage _singleton = new LocalStorage._internal();

  final StreamController<List<Note>> _controller =
      StreamController<List<Note>>.broadcast();

  final StreamController<List<NoteCollection>> _collectionController =
      StreamController<List<NoteCollection>>.broadcast();

  StreamController<List<Note>> get controller => _controller;
  StreamController<List<NoteCollection>> get collectionController =>
      _collectionController;

  Stream<List<Note>> get stream => _controller.stream.asBroadcastStream();
  Stream<List<NoteCollection>> get collectionStream =>
      _collectionController.stream.asBroadcastStream();

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
        onCreate: (db, version) async {
      // Run the CREATE TABLE statement on the database.
      await createDatabase(db);

      if (version != 1) {
        for (int i = 2; i <= version; i++) {
          int oldVersion = i - 1;
          int newVersion = i;
          migrations[oldVersion][newVersion]
              .forEach((script) async => await db.execute(script));
        }
      }
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      print("performing upgrade from $oldVersion to $newVersion");
      migrations[oldVersion][newVersion]
          .forEach((script) async => await db.execute(script));
    }, onDowngrade: (Database db, int oldVersion, int newVersion) {
      print("performing downgrade from $oldVersion to $newVersion");
      migrations[oldVersion][newVersion]
          .forEach((script) async => await db.execute(script));
    },
        // Set the version. This executes the onCreate function and provides a
        // path to perform database upgrades and downgrades.
        version: 2);
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

    note.lastModified = DateTime.now();
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

  Future<List<NoteCollection>> getCollections() async {
    final List<Map<String, dynamic>> maps =
        await (await getDatabase()).query(collectionTable);

    if (maps == null) return [];
    List<NoteCollection> collections = [];

    for (var map in maps) {
      String collectionId = map['id'];
      NoteCollection collection = NoteCollection.fromJson(map);
      // add notes by id
      collection.notes = await getNotesByCollectionId(collectionId);
      collections.add(collection);
    }

    return collections;
  }

  Future<void> syncCollection(NoteCollection collection) async {
    collection.lastModified = DateTime.now();
    var data = collection.toJson();
    data.remove('notes');

    var db = await getDatabase();

    var query = await db
        .query(collectionTable, where: "id = ?", whereArgs: [collection.id]);
    if (query == null || query.length == 0) {
      int row = await db.insert(collectionTable, data,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print("Insert into row $row");
    } else {
      print(query);
      print("update table");
      _updateTable(collectionTable, data);
    }

    var noteIds = await _getNoteIdsByCollectionId(collection.id, db);
    print("note ids: $noteIds");

    for (var note in collection.notes) {
      if (!noteIds.contains(note.id)) {
        // add setId / noteId pair
        Map<String, dynamic> pair = {
          "noteId": note.id,
          "collectionId": collection.id
        };

        int row = await db.insert(collectionMappingTable, pair,
            conflictAlgorithm: ConflictAlgorithm.replace);
        print(
            "insert noteId ${note.id} into collection ${collection.id} | row: $row");
      } else {
        noteIds.remove(note.id);
      }
    }
    // if any noteId left in list, remove entry from table
    for (var noteId in noteIds) {
      print("delete noteId: $noteId | collectionId: ${collection.id}");
      await db.delete(collectionMappingTable,
          where: "collectionId = ? AND noteId = ?",
          whereArgs: [collection.id, noteId]);
    }

    var collections = await getCollections();
    print("collections: ${collections.length}");
    _collectionController.sink.add(collections);
  }

  Future<List<Note>> getNotesByCollectionId(String collectionId) async {
    final List<Map<String, dynamic>> maps = await (await getDatabase()).query(
        collectionMappingTable,
        where: "collectionId = ?",
        whereArgs: [collectionId]);

    if (maps == null) return [];

    List<Note> notes = [];

    for (var map in maps) {
      Note note = await getNote(map);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  Future<List<String>> _getNoteIdsByCollectionId(
      String collectionId, Database db) async {
    final List<Map<String, dynamic>> maps = await (db.query(
        collectionMappingTable,
        where: "collectionId = ?",
        whereArgs: [collectionId]));

    if (maps == null) return [];
    return maps.asMap().values.map<String>((value) => value['noteId']).toList();
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

  Future<void> deleteCollection(NoteCollection collection) async {
    final db = await getDatabase();

    await db.delete(
      collectionTable,
      where: 'id = ?',
      whereArgs: [collection.id],
    );

    await db.delete(
      collectionMappingTable,
      where: 'collectionId = ?',
      whereArgs: [collection.id],
    );
    _collectionController.sink.add(await getCollections());
  }

  Future<int> _updateTable(String table, Map<String, dynamic> data,
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
    note.lastModified = DateTime.now();
    var data = note.toJson();
    data.remove("sections");
    data.remove("audioFiles");

    await _updateTable(noteTable, data);
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
