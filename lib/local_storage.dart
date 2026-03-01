import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'model.dart';

final String noteTable = 'notes';
final String sectionTable = 'sections';
final String audioFileTable = 'audiofiles';
final String collectionTable = 'collections';
final String collectionMappingTable = 'collectionmapping';
final String syncQueueTable = 'sync_queue';
final String syncConflictTable = 'sync_conflicts';
final String syncVersionTable = 'sync_versions';

class LocalStorage {
  LocalStorage._internal();
  static final LocalStorage _singleton = LocalStorage._internal();

  final StreamController<List<Note>> _controller =
      StreamController<List<Note>>.broadcast();
  final StreamController<List<NoteCollection>> _collectionController =
      StreamController<List<NoteCollection>>.broadcast();
  final StreamController<SyncStatusSummary> _syncStatusController =
      StreamController<SyncStatusSummary>.broadcast();

  StreamController<List<Note>> get controller => _controller;
  StreamController<List<NoteCollection>> get collectionController =>
      _collectionController;

  Stream<List<Note>> get stream => _controller.stream.asBroadcastStream();
  Stream<List<NoteCollection>> get collectionStream =>
      _collectionController.stream.asBroadcastStream();
  Stream<SyncStatusSummary> get syncStatusStream =>
      _syncStatusController.stream.asBroadcastStream();

  factory LocalStorage() => _singleton;

  Future<void> deleteFile(File f) => f.delete();

  Future<Database> getDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'sketchord.db'),
      version: 3,
      onCreate: (db, version) async => createDatabase(db),
      onUpgrade: (db, oldVersion, newVersion) async => _ensureSchema(db),
      onOpen: (db) async => _ensureSchema(db),
    );
  }

  Future<void> createDatabase(Database db) async {
    await db.execute('''CREATE TABLE $noteTable(
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
      );''');
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
    await db.execute('''CREATE TABLE $syncQueueTable(
        id TEXT PRIMARY KEY,
        entityType TEXT,
        entityId TEXT,
        operation TEXT,
        payload TEXT,
        baseVersion INTEGER,
        createdAt TEXT,
        status TEXT,
        retryCount INTEGER,
        lastError TEXT
      );''');
    await db.execute('''CREATE TABLE $syncConflictTable(
        id TEXT PRIMARY KEY,
        entityType TEXT,
        entityId TEXT,
        operation TEXT,
        reason TEXT,
        localPayload TEXT,
        remotePayload TEXT,
        createdAt TEXT,
        resolvedAt TEXT
      );''');
    await db.execute('''CREATE TABLE $syncVersionTable(
        entityType TEXT,
        entityId TEXT,
        serverVersion INTEGER,
        PRIMARY KEY(entityType, entityId)
      );''');
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $collectionTable(id TEXT PRIMARY KEY, title TEXT, description TEXT, createdAt TEXT, lastModified TEXT, starred INTEGER);',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $collectionMappingTable(noteId TEXT, collectionId TEXT);',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $syncQueueTable(id TEXT PRIMARY KEY, entityType TEXT, entityId TEXT, operation TEXT, payload TEXT, baseVersion INTEGER, createdAt TEXT, status TEXT, retryCount INTEGER, lastError TEXT);',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $syncConflictTable(id TEXT PRIMARY KEY, entityType TEXT, entityId TEXT, operation TEXT, reason TEXT, localPayload TEXT, remotePayload TEXT, createdAt TEXT, resolvedAt TEXT);',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $syncVersionTable(entityType TEXT, entityId TEXT, serverVersion INTEGER, PRIMARY KEY(entityType, entityId));',
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

  Future<int> _getEntityBaseVersion(
    Database db,
    SyncEntityType entityType,
    String entityId,
  ) async {
    final rows = await db.query(
      syncVersionTable,
      where: 'entityType = ? AND entityId = ?',
      whereArgs: [entityType.name, entityId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['serverVersion'] as num?)?.toInt() ?? 0;
  }

  Future<void> setEntityServerVersion({
    required SyncEntityType entityType,
    required String entityId,
    required int serverVersion,
  }) async {
    final db = await getDatabase();
    await db.insert(
        syncVersionTable,
        {
          'entityType': entityType.name,
          'entityId': entityId,
          'serverVersion': serverVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> enqueueSyncChange({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await getDatabase();
    final now = serializeDateTime(DateTime.now());
    final baseVersion = await _getEntityBaseVersion(db, entityType, entityId);
    final existingQueuedUpserts = await db.query(
      syncQueueTable,
      where: 'entityType = ? AND entityId = ? AND status = ? AND operation = ?',
      whereArgs: [
        entityType.name,
        entityId,
        SyncQueueStatus.queued.name,
        SyncOperationType.upsert.name,
      ],
      orderBy: 'createdAt ASC',
    );

    // Coalesce rapid repeated edits of the same entity into one queued upsert.
    if (operation == SyncOperationType.upsert &&
        existingQueuedUpserts.isNotEmpty) {
      final primary = Map<String, dynamic>.from(existingQueuedUpserts.first);
      final primaryId = primary['id'] as String;
      await db.update(
        syncQueueTable,
        {
          'payload': jsonEncode(payload),
          'createdAt': now,
          'lastError': null,
        },
        where: 'id = ?',
        whereArgs: [primaryId],
      );
      for (int i = 1; i < existingQueuedUpserts.length; i++) {
        final row = Map<String, dynamic>.from(existingQueuedUpserts[i]);
        await db
            .delete(syncQueueTable, where: 'id = ?', whereArgs: [row['id']]);
      }
      await _notifySyncStatusChanged();
      return;
    }

    // A delete supersedes queued upserts for the same entity.
    if (operation == SyncOperationType.delete ||
        operation == SyncOperationType.tombstone) {
      for (final row in existingQueuedUpserts) {
        await db
            .delete(syncQueueTable, where: 'id = ?', whereArgs: [row['id']]);
      }
    }

    await db.insert(
      syncQueueTable,
      {
        'id': const Uuid().v4(),
        'entityType': entityType.name,
        'entityId': entityId,
        'operation': operation.name,
        'payload': jsonEncode(payload),
        'baseVersion': baseVersion,
        'createdAt': now,
        'status': SyncQueueStatus.queued.name,
        'retryCount': 0,
        'lastError': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifySyncStatusChanged();
  }

  Future<void> markQueueItemSynced(
    String queueId, {
    int? newServerVersion,
    SyncEntityType? entityType,
    String? entityId,
  }) async {
    final db = await getDatabase();
    await db.delete(syncQueueTable, where: 'id = ?', whereArgs: [queueId]);
    if (newServerVersion != null && entityType != null && entityId != null) {
      await setEntityServerVersion(
        entityType: entityType,
        entityId: entityId,
        serverVersion: newServerVersion,
      );
    }
    await _notifySyncStatusChanged();
  }

  Future<void> markQueueItemRejected({
    required String queueId,
    required String reason,
    Map<String, dynamic>? remotePayload,
  }) async {
    final db = await getDatabase();
    final rows = await db.query(
      syncQueueTable,
      where: 'id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final item = SyncQueueItem.fromJson(Map<String, dynamic>.from(rows.first));
    await db.update(
      syncQueueTable,
      {
        'status': SyncQueueStatus.rejected.name,
        'retryCount': item.retryCount + 1,
        'lastError': reason,
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
    await db.insert(
        syncConflictTable,
        {
          'id': const Uuid().v4(),
          'entityType': item.entityType.name,
          'entityId': item.entityId,
          'operation': item.operation.name,
          'reason': reason,
          'localPayload': item.payload,
          'remotePayload':
              remotePayload == null ? null : jsonEncode(remotePayload),
          'createdAt': serializeDateTime(DateTime.now()),
          'resolvedAt': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _notifySyncStatusChanged();
  }

  Future<List<SyncQueueItem>> getQueuedSyncChanges() async {
    final db = await getDatabase();
    final rows = await db.query(
      syncQueueTable,
      where: 'status = ?',
      whereArgs: [SyncQueueStatus.queued.name],
      orderBy: 'createdAt ASC',
    );
    return rows
        .map((row) => SyncQueueItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<SyncConflict>> getSyncConflicts({
    bool unresolvedOnly = true,
  }) async {
    final db = await getDatabase();
    final rows = await db.query(
      syncConflictTable,
      where: unresolvedOnly ? 'resolvedAt IS NULL' : null,
      orderBy: 'createdAt DESC',
    );
    return rows
        .map((row) => SyncConflict.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> resolveSyncConflict(String conflictId) async {
    final db = await getDatabase();
    await db.update(
      syncConflictTable,
      {'resolvedAt': serializeDateTime(DateTime.now())},
      where: 'id = ?',
      whereArgs: [conflictId],
    );
    await _notifySyncStatusChanged();
  }

  Future<int> resolveAllSyncConflicts() async {
    final db = await getDatabase();
    final count = await db.update(
      syncConflictTable,
      {'resolvedAt': serializeDateTime(DateTime.now())},
      where: 'resolvedAt IS NULL',
    );
    await _notifySyncStatusChanged();
    return count;
  }

  Future<SyncStatusSummary> getSyncStatusSummary() async {
    final db = await getDatabase();
    final queued = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $syncQueueTable WHERE status = ?',
        [SyncQueueStatus.queued.name],
      ),
    );
    final conflicts = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $syncConflictTable WHERE resolvedAt IS NULL',
      ),
    );
    return SyncStatusSummary(
      queuedChanges: queued ?? 0,
      unresolvedConflicts: conflicts ?? 0,
    );
  }

  Future<void> _notifySyncStatusChanged() async {
    if (_syncStatusController.isClosed) return;
    final summary = await getSyncStatusSummary();
    _syncStatusController.sink.add(summary);
  }

  Future<int> syncNote(
    Note note, {
    bool enqueueChange = true,
    bool touchLastModified = true,
  }) async {
    final db = await getDatabase();

    await db.delete(sectionTable, where: 'noteId = ?', whereArgs: [note.id]);
    for (int i = 0; i < note.sections.length; i++) {
      final sectionData = note.sections[i].toJson();
      sectionData['idx'] = i;
      sectionData['noteId'] = note.id;
      await db.insert(
        sectionTable,
        sectionData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await db.delete(audioFileTable, where: 'noteId = ?', whereArgs: [note.id]);
    for (int i = 0; i < note.audioFiles.length; i++) {
      final audioFileData = note.audioFiles[i].toJson();
      audioFileData['idx'] = i;
      audioFileData['noteId'] = note.id;
      await db.insert(
        audioFileTable,
        audioFileData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (touchLastModified) {
      note.lastModified = DateTime.now();
    }
    final data = note.toJson()
      ..remove('sections')
      ..remove('audioFiles');
    final row = await db.insert(
      noteTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.note,
        entityId: note.id,
        operation: SyncOperationType.upsert,
        payload: note.toJson(),
      );
    }

    _controller.sink.add(await getNotes());
    return row;
  }

  Future<int> addAudioIdea(
    AudioFile f, {
    bool enqueueChange = true,
  }) async {
    final db = await getDatabase();
    final data = f.toJson();
    data.remove('noteId');
    data.remove('idx');
    final row = await db.insert(
      audioFileTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.audioIdea,
        entityId: f.id,
        operation: SyncOperationType.upsert,
        payload: f.toJson(),
      );
    }
    return row;
  }

  Future<int> syncAudioFile(
    AudioFile f, {
    bool enqueueChange = true,
  }) async {
    final db = await getDatabase();
    int row = await db.update(
      audioFileTable,
      f.toJson(),
      where: 'id = ?',
      whereArgs: [f.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (row == 0) {
      row = await db.insert(
        audioFileTable,
        f.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.audioFile,
        entityId: f.id,
        operation: SyncOperationType.upsert,
        payload: f.toJson(),
      );
    }
    return row;
  }

  Future<List<Section>> getSections(String noteId) async {
    var maps = await (await getDatabase()).query(
      sectionTable,
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    maps.sort((s1, s2) => (s1['idx'] as int) - (s2['idx'] as int));
    return maps.map((s) => Section.fromJson(s)).toList();
  }

  Future<List<AudioFile>> getAudioFiles(String noteId) async {
    var maps = await (await getDatabase()).query(
      audioFileTable,
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    maps.sort((s1, s2) => (s1['idx'] as int) - (s2['idx'] as int));
    return maps.map((s) => AudioFile.fromJson(s)).toList();
  }

  Future<List<AudioFile>> getAudioIdeas({bool descending = true}) async {
    var maps = await (await getDatabase()).query(
      audioFileTable,
      where: 'noteId IS NULL',
    );
    maps = maps.map((m) => Map<String, dynamic>.from(m)).toList();
    final files = maps.map((s) => AudioFile.fromJson(s)).toList();
    files.sort(
      (a, b) => descending
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return files;
  }

  Future<Note?> getNoteById(String id) async {
    final maps = await (await getDatabase()).query(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );
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
      final collection = NoteCollection.fromJson(
        Map<String, dynamic>.from(map),
      );
      collection.notes = await getNotesByCollectionId(collection.id);
      collections.add(collection);
    }
    return collections;
  }

  Future<void> syncCollection(
    NoteCollection collection, {
    bool enqueueChange = true,
    bool touchLastModified = true,
  }) async {
    final db = await getDatabase();
    if (touchLastModified) {
      collection.lastModified = DateTime.now();
    }

    final data = collection.toJson()..remove('notes');
    await db.insert(
      collectionTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final existingNoteIds = await _getNoteIdsByCollectionId(collection.id, db);
    for (final note in collection.notes) {
      if (!existingNoteIds.contains(note.id)) {
        await db.insert(
            collectionMappingTable,
            {
              'noteId': note.id,
              'collectionId': collection.id,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        existingNoteIds.remove(note.id);
      }
    }

    for (final noteId in existingNoteIds) {
      await db.delete(
        collectionMappingTable,
        where: 'collectionId = ? AND noteId = ?',
        whereArgs: [collection.id, noteId],
      );
    }

    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.collection,
        entityId: collection.id,
        operation: SyncOperationType.upsert,
        payload: collection.toJson(),
      );
    }

    _collectionController.sink.add(await getCollections());
  }

  Future<int> getNumCollectionsByNoteId(String noteId) async {
    final maps = await (await getDatabase()).query(
      collectionMappingTable,
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
    return maps.length;
  }

  Future<List<Note>> getNotesByCollectionId(String collectionId) async {
    final maps = await (await getDatabase()).query(
      collectionMappingTable,
      where: 'collectionId = ?',
      whereArgs: [collectionId],
    );
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
    String collectionId,
    Database db,
  ) async {
    final maps = await db.query(
      collectionMappingTable,
      where: 'collectionId = ?',
      whereArgs: [collectionId],
    );
    return maps
        .map((row) => row['noteId'])
        .whereType<String>()
        .toList(growable: true);
  }

  Future<bool> _deleteAudioFile(
    AudioFile audioFile, {
    bool enqueueChange = true,
  }) async {
    final db = await getDatabase();
    await db.delete(audioFileTable, where: 'id = ?', whereArgs: [audioFile.id]);
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.audioIdea,
        entityId: audioFile.id,
        operation: SyncOperationType.delete,
        payload: {'id': audioFile.id},
      );
    }
    if (audioFile.file.existsSync()) {
      await audioFile.file.delete();
    }
    return !audioFile.file.existsSync();
  }

  Future<bool> deleteAudioIdea(
    AudioFile audioFile, {
    bool enqueueChange = true,
  }) =>
      _deleteAudioFile(audioFile, enqueueChange: enqueueChange);

  Future<void> deleteNote(
    Note note, {
    bool enqueueChange = true,
  }) async {
    final db = await getDatabase();
    await db.delete(noteTable, where: 'id = ?', whereArgs: [note.id]);
    await db.delete(
      collectionMappingTable,
      where: 'noteId = ?',
      whereArgs: [note.id],
    );

    for (final f in note.audioFiles) {
      await _deleteAudioFile(f, enqueueChange: false);
    }
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.note,
        entityId: note.id,
        operation: SyncOperationType.delete,
        payload: {'id': note.id},
      );
    }
    _controller.sink.add(await getNotes());
  }

  Future<void> deleteCollection(
    NoteCollection collection, {
    bool enqueueChange = true,
  }) async {
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
    if (enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.collection,
        entityId: collection.id,
        operation: SyncOperationType.delete,
        payload: {'id': collection.id},
      );
    }
    _collectionController.sink.add(await getCollections());
  }

  Future<int> _updateTable(
    String table,
    Map<String, dynamic> data, {
    String where = 'id = ?',
  }) async {
    final db = await getDatabase();
    return db.update(table, data, where: where, whereArgs: [data['id']]);
  }

  Future<void> discardNote(
    Note note, {
    bool removeFromCollection = false,
  }) async {
    note.discarded = true;
    await _updateNote(note);
    if (removeFromCollection) {
      final db = await getDatabase();
      await db.delete(
        collectionMappingTable,
        where: 'noteId = ?',
        whereArgs: [note.id],
      );
    }
  }

  Future<void> _updateNote(Note note) async {
    note.lastModified = DateTime.now();
    final data = note.toJson()
      ..remove('sections')
      ..remove('audioFiles');
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

  Future<bool> syncSettings(
    Settings settings, {
    bool enqueueChange = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final synced = await prefs.setString(
      'settings',
      jsonEncode(settings.toJson()),
    );
    if (synced && enqueueChange) {
      await enqueueSyncChange(
        entityType: SyncEntityType.settings,
        entityId: 'settings',
        operation: SyncOperationType.upsert,
        payload: settings.toJson(),
      );
    }
    return synced;
  }

  Future<String> getSyncBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('syncBackendUrl') ?? 'http://192.168.178.52:8009';
  }

  Future<void> setSyncBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('syncBackendUrl', url);
  }

  Future<bool> getSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('syncEnabled') ?? true;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('syncEnabled', enabled);
  }

  Future<int> getSyncPullCursor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('syncPullCursor') ?? 0;
  }

  Future<void> setSyncPullCursor(int seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('syncPullCursor', seq);
  }

  Future<void> applyRemoteChange({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, dynamic> payload,
    required int serverVersion,
  }) async {
    if (entityType == SyncEntityType.note) {
      if (operation == SyncOperationType.delete ||
          operation == SyncOperationType.tombstone) {
        final note = await getNoteById(entityId);
        if (note != null) {
          await deleteNote(note, enqueueChange: false);
        }
      } else {
        final note = Note.fromJson(payload, entityId);
        await syncNote(note, enqueueChange: false, touchLastModified: false);
      }
      await setEntityServerVersion(
        entityType: entityType,
        entityId: entityId,
        serverVersion: serverVersion,
      );
      return;
    }

    if (entityType == SyncEntityType.collection) {
      if (operation == SyncOperationType.delete ||
          operation == SyncOperationType.tombstone) {
        NoteCollection? collection;
        for (final c in await getCollections()) {
          if (c.id == entityId) {
            collection = c;
            break;
          }
        }
        if (collection != null) {
          await deleteCollection(collection, enqueueChange: false);
        }
      } else {
        final collection = NoteCollection.fromJson(payload);
        await syncCollection(
          collection,
          enqueueChange: false,
          touchLastModified: false,
        );
      }
      await setEntityServerVersion(
        entityType: entityType,
        entityId: entityId,
        serverVersion: serverVersion,
      );
      return;
    }

    if (entityType == SyncEntityType.settings &&
        operation == SyncOperationType.upsert) {
      final settings = Settings.fromJson(payload);
      await syncSettings(settings, enqueueChange: false);
      await setEntityServerVersion(
        entityType: entityType,
        entityId: entityId,
        serverVersion: serverVersion,
      );
      return;
    }

    if (entityType == SyncEntityType.audioIdea ||
        entityType == SyncEntityType.audioFile) {
      if (operation == SyncOperationType.delete ||
          operation == SyncOperationType.tombstone) {
        final db = await getDatabase();
        await db.delete(audioFileTable, where: 'id = ?', whereArgs: [entityId]);
      } else {
        final f = AudioFile.fromJson(payload);
        final updated = await syncAudioFile(f, enqueueChange: false);
        if (updated == 0) {
          await addAudioIdea(f, enqueueChange: false);
        }
      }
      await setEntityServerVersion(
        entityType: entityType,
        entityId: entityId,
        serverVersion: serverVersion,
      );
      return;
    }
  }

  Future<Settings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings');
    if (data == null || data.isEmpty) {
      return Settings(
        theme: SettingsTheme.dark,
        view: EditorView.single,
        audioFormat: AudioFormat.wav,
      );
    }
    return Settings.fromJson(jsonDecode(data));
  }
}
