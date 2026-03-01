import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'model.dart';

final String noteTable = 'notes';
final String sectionTable = 'sections';
final String audioFileTable = 'audiofiles';
final String collectionTable = 'collections';
final String collectionMappingTable = 'collectionmapping';

class LocalStorage {
  LocalStorage._internal();
  static final LocalStorage _singleton = LocalStorage._internal();

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

  factory LocalStorage() => _singleton;

  Future<void> deleteFile(File f) => f.delete();

  Future<Database> getDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'sketchord.db'),
      version: 2,
      onCreate: (db, version) async => createDatabase(db),
      onUpgrade: (db, oldVersion, newVersion) async => _ensureSchema(db),
      onOpen: (db) async => _ensureSchema(db),
    );
  }

  Future<void> createDatabase(Database db) async {
    await db.execute(
      '''CREATE TABLE $noteTable(
        id TEXT PRIMARY KEY,
        title TEXT,
        createdAt TEXT,
        lastModified TEXT,
        key TEXT,
        tuning TEXT,
        capo TEXT,
        instrument TEXT,
        label TEXT,
        artist TEXT,
        color TEXT,
        bpm REAL,
        length REAL,
        zoom REAL,
        scrollOffset REAL,
        starred INTEGER,
        discarded INTEGER
      );''',
    );
    await db.execute(
      'CREATE TABLE $sectionTable(id TEXT PRIMARY KEY, noteId TEXT, title TEXT, content TEXT, idx INTEGER);',
    );
    await db.execute(
      'CREATE TABLE $audioFileTable(id TEXT PRIMARY KEY, noteId TEXT, idx INTEGER, duration TEXT, path TEXT, createdAt TEXT, lastModified TEXT, name TEXT, loopRange TEXT, text TEXT, starred INTEGER);',
    );
    await db.execute(
      'CREATE TABLE $collectionTable(id TEXT PRIMARY KEY, title TEXT, description TEXT, createdAt TEXT, lastModified TEXT, starred INTEGER);',
    );
    await db.execute(
      'CREATE TABLE $collectionMappingTable(noteId TEXT, collectionId TEXT);',
    );
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $collectionTable(id TEXT PRIMARY KEY, title TEXT, description TEXT, createdAt TEXT, lastModified TEXT, starred INTEGER);',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $collectionMappingTable(noteId TEXT, collectionId TEXT);',
    );

    if (!await _hasColumn(db, noteTable, 'length')) {
      await db.execute('ALTER TABLE $noteTable ADD length REAL;');
    }
    if (!await _hasColumn(db, audioFileTable, 'text')) {
      await db.execute('ALTER TABLE $audioFileTable ADD text TEXT;');
    }
    if (!await _hasColumn(db, audioFileTable, 'starred')) {
      await db.execute('ALTER TABLE $audioFileTable ADD starred INTEGER;');
    }
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    final res = await db.rawQuery('PRAGMA table_info($table)');
    return res.any((row) => row['name'] == column);
  }

  Future<int> syncNote(Note note) async {
    final db = await getDatabase();

    await db.delete(sectionTable, where: 'noteId = ?', whereArgs: [note.id]);
    for (int i = 0; i < note.sections.length; i++) {
      final sectionData = note.sections[i].toJson();
      sectionData['idx'] = i;
      sectionData['noteId'] = note.id;
      await db.insert(sectionTable, sectionData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await db.delete(audioFileTable, where: 'noteId = ?', whereArgs: [note.id]);
    for (int i = 0; i < note.audioFiles.length; i++) {
      final audioFileData = note.audioFiles[i].toJson();
      audioFileData['idx'] = i;
      audioFileData['noteId'] = note.id;
      await db.insert(audioFileTable, audioFileData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    note.lastModified = DateTime.now();
    final data = note.toJson()..remove('sections')..remove('audioFiles');
    final row = await db.insert(noteTable, data,
        conflictAlgorithm: ConflictAlgorithm.replace);

    _controller.sink.add(await getNotes());
    return row;
  }

  Future<int> addAudioIdea(AudioFile f) async {
    final db = await getDatabase();
    final data = f.toJson();
    data.remove('noteId');
    data.remove('idx');
    return db.insert(audioFileTable, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> syncAudioFile(AudioFile f) async {
    final db = await getDatabase();
    return db.update(audioFileTable, f.toJson(),
        where: 'id = ?',
        whereArgs: [f.id],
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Section>> getSections(String noteId) async {
    var maps = await (await getDatabase())
        .query(sectionTable, where: 'noteId = ?', whereArgs: [noteId]);
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    maps.sort((s1, s2) => (s1['idx'] as int) - (s2['idx'] as int));
    return maps.map((s) => Section.fromJson(s)).toList();
  }

  Future<List<AudioFile>> getAudioFiles(String noteId) async {
    var maps = await (await getDatabase())
        .query(audioFileTable, where: 'noteId = ?', whereArgs: [noteId]);
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    maps.sort((s1, s2) => (s1['idx'] as int) - (s2['idx'] as int));
    return maps.map((s) => AudioFile.fromJson(s)).toList();
  }

  Future<List<AudioFile>> getAudioIdeas({bool descending = true}) async {
    var maps =
        await (await getDatabase()).query(audioFileTable, where: 'noteId IS NULL');
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    final files = maps.map((s) => AudioFile.fromJson(s)).toList();
    files.sort((a, b) => descending
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return files;
  }

  Future<Note?> getNoteById(String id) async {
    final maps =
        await (await getDatabase()).query(noteTable, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return getNote(Map<String, dynamic>.from(maps.first));
  }

  Future<Note> getNote(Map<String, dynamic> data) async {
    final noteId = data['id'] as String;
    final note = Note.fromJson(data, noteId);
    note.sections = await getSections(noteId);
    note.audioFiles = await getAudioFiles(noteId);
    return note;
  }

  Future<List<Note>> getNotes() async {
    final maps = await (await getDatabase()).query(noteTable);
    final notes = <Note>[];
    for (final map in maps) {
      notes.add(await getNote(Map<String, dynamic>.from(map)));
    }
    return notes;
  }

  Future<List<NoteCollection>> getCollections() async {
    final maps = await (await getDatabase()).query(collectionTable);
    final collections = <NoteCollection>[];
    for (final map in maps) {
      final collection = NoteCollection.fromJson(Map<String, dynamic>.from(map));
      collection.notes = await getNotesByCollectionId(collection.id);
      collections.add(collection);
    }
    return collections;
  }

  Future<void> syncCollection(NoteCollection collection) async {
    final db = await getDatabase();
    collection.lastModified = DateTime.now();

    final data = collection.toJson()..remove('notes');
    await db.insert(collectionTable, data,
        conflictAlgorithm: ConflictAlgorithm.replace);

    final existingNoteIds = await _getNoteIdsByCollectionId(collection.id, db);
    for (final note in collection.notes) {
      if (!existingNoteIds.contains(note.id)) {
        await db.insert(
          collectionMappingTable,
          {'noteId': note.id, 'collectionId': collection.id},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        existingNoteIds.remove(note.id);
      }
    }

    for (final noteId in existingNoteIds) {
      await db.delete(collectionMappingTable,
          where: 'collectionId = ? AND noteId = ?',
          whereArgs: [collection.id, noteId]);
    }

    _collectionController.sink.add(await getCollections());
  }

  Future<int> getNumCollectionsByNoteId(String noteId) async {
    final maps = await (await getDatabase()).query(collectionMappingTable,
        where: 'noteId = ?', whereArgs: [noteId]);
    return maps.length;
  }

  Future<List<Note>> getNotesByCollectionId(String collectionId) async {
    final maps = await (await getDatabase()).query(collectionMappingTable,
        where: 'collectionId = ?', whereArgs: [collectionId]);
    final notes = <Note>[];
    for (final map in maps) {
      final noteId = map['noteId'] as String?;
      if (noteId == null) continue;
      final note = await getNoteById(noteId);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  Future<List<String>> _getNoteIdsByCollectionId(
      String collectionId, Database db) async {
    final maps = await db.query(collectionMappingTable,
        where: 'collectionId = ?', whereArgs: [collectionId]);
    return maps
        .map((row) => row['noteId'])
        .whereType<String>()
        .toList(growable: true);
  }

  Future<bool> _deleteAudioFile(AudioFile audioFile) async {
    final db = await getDatabase();
    await db.delete(audioFileTable, where: 'id = ?', whereArgs: [audioFile.id]);
    if (audioFile.file.existsSync()) {
      await audioFile.file.delete();
    }
    return !audioFile.file.existsSync();
  }

  Future<bool> deleteAudioIdea(AudioFile audioFile) => _deleteAudioFile(audioFile);

  Future<void> deleteNote(Note note) async {
    final db = await getDatabase();
    await db.delete(noteTable, where: 'id = ?', whereArgs: [note.id]);
    await db.delete(collectionMappingTable, where: 'noteId = ?', whereArgs: [note.id]);

    for (final f in note.audioFiles) {
      await _deleteAudioFile(f);
    }
    _controller.sink.add(await getNotes());
  }

  Future<void> deleteCollection(NoteCollection collection) async {
    final db = await getDatabase();
    await db.delete(collectionTable, where: 'id = ?', whereArgs: [collection.id]);
    await db.delete(collectionMappingTable,
        where: 'collectionId = ?', whereArgs: [collection.id]);
    _collectionController.sink.add(await getCollections());
  }

  Future<int> _updateTable(String table, Map<String, dynamic> data,
      {String where = 'id = ?'}) async {
    final db = await getDatabase();
    return db.update(table, data, where: where, whereArgs: [data['id']]);
  }

  Future<void> discardNote(Note note, {bool removeFromCollection = false}) async {
    note.discarded = true;
    await _updateNote(note);
    if (removeFromCollection) {
      final db = await getDatabase();
      await db.delete(collectionMappingTable, where: 'noteId = ?', whereArgs: [note.id]);
    }
  }

  Future<void> _updateNote(Note note) async {
    note.lastModified = DateTime.now();
    final data = note.toJson()..remove('sections')..remove('audioFiles');
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
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getBool('started');
    return !(started ?? false);
  }

  Future<void> setInitialStartDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('started', true);
  }

  Future<List<Note>> getActiveNotes() async {
    return (await getNotes()).where((n) => !n.discarded).toList();
  }

  Future<List<Note>> getDiscardedNotes() async {
    return (await getNotes()).where((n) => n.discarded).toList();
  }

  Future<bool> syncSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  Future<Settings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings');
    if (data == null || data.isEmpty) {
      return Settings(
          theme: SettingsTheme.dark,
          view: EditorView.single,
          audioFormat: AudioFormat.wav);
    }
    return Settings.fromJson(jsonDecode(data));
  }
}
