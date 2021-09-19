import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import "model.dart";
import 'package:path/path.dart' as p;

const NOTES_FILENAME = "notes.json";
const COLLECTIONS_FILENAME = "collections.json";
const AUDIOFILES_FILENAME = "audioFiles.json";

class ImportException implements Exception {
  String errMsg() => 'cannot import file';
}

class BackupData {
  final List<Note> notes;
  final List<NoteCollection> collections;

  BackupData({this.notes, this.collections});
}

class Backup {
  Future<bool> getPermissions() async {
    return await Permission.storage.request().isGranted;
  }

  Future<Directory> getCacheDir() async {
    Directory root = (await getApplicationDocumentsDirectory()).parent;
    return Directory(p.join(root.path, 'cache'));
  }

  Future<Directory> getFilesDir() async {
    Directory root = (await getApplicationDocumentsDirectory()).parent;
    print("ROOT: ${root.path}");

    return Directory(p.join(root.path, 'files'));
  }

  Future<BackupData> import() async {
    File f = await FilePicker.getFile(
      type: FileType.any,
      // allowedExtensions: ['zip', 'json'],
    );
    if (f.path.endsWith(".json")) {
      Note note = readNote(f.path);
      return BackupData(notes: [note], collections: []);
    } else if (f.path.endsWith(".zip")) {
      return await _readZip(f.path);
    }

    return BackupData(notes: [], collections: []);
  }

  String decodeZipContent(ArchiveFile f) {
    Uint8List l = f.content;
    return new String.fromCharCodes(l);
  }

  Future<BackupData> _readZip(String path) async {
    List<Note> notes = [];
    List<NoteCollection> collections = [];

    try {
      final bytes = File(path).readAsBytesSync();

      // Decode the Zip file
      final archive = ZipDecoder().decodeBytes(bytes);
      for (ArchiveFile f in archive) {
        print(f.name);
      }
      final noteListFile = archive.files
          .firstWhere((a) => a.name == NOTES_FILENAME, orElse: () => null);

      if (noteListFile == null) {
        print("cannot find note list");
        throw new ImportException();
      }
      final noteIds = jsonDecode(decodeZipContent(noteListFile));
      print("zip contains $noteIds");

      for (String noteId in noteIds) {
        var noteFile = archive.files
            .firstWhere((a) => a.name == "$noteId.json", orElse: () => null);

        if (noteFile == null) {
          print("cannot find note with id $noteId");
          throw new ImportException();
        }
        var noteMap = jsonDecode(decodeZipContent(noteFile));
        Note note = Note.fromJson(noteMap, noteMap['id']);
        notes.add(note);
      }

      final collectionsListFile = archive.files.firstWhere(
          (a) => a.name == COLLECTIONS_FILENAME,
          orElse: () => null);

      if (collectionsListFile == null) {
        print("cannot find collections list");
      } else {
        final collectionIds = jsonDecode(decodeZipContent(collectionsListFile));

        for (String collectionId in collectionIds) {
          var collectionFile = archive.files.firstWhere(
              (a) => a.name == "$collectionId.json",
              orElse: () => null);

          if (collectionFile == null) {
            print("cannot find note with id $collectionId");
          } else {
            var collectionMap = jsonDecode(decodeZipContent(collectionFile));
            NoteCollection c = NoteCollection.fromJson(collectionMap);
            collections.add(c);
          }
        }
      }

      final audioFilesFile = archive.files
          .firstWhere((a) => a.name == AUDIOFILES_FILENAME, orElse: () => null);

      if (audioFilesFile == null) {
        print("cannot find audiofiles json");
      } else {
        print("restoring audio files");
        Map<String, dynamic> audioFilesMap =
            jsonDecode(decodeZipContent(audioFilesFile));
        audioFilesMap.forEach((internalName, path) {
          final file = archive.files
              .firstWhere((a) => a.name == internalName, orElse: () => null);
          if (File(path).existsSync() || file == null) {
            print(
                "Error: cannot find audio file / already exists $internalName that maps to $path");
          } else {
            try {
              print(
                  "restoring audio file from ${file.nameOfLinkedFile} to $path");
              final data = file.content as List<int>;

              File(path)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } catch (e) {
              print("cannot restore file $internalName to $path");
            }
          }
        });
      }
    } catch (e) {
      print("unknwon error occurred $e");
      throw new ImportException();
    }

    return BackupData(notes: notes, collections: collections);
  }

  Note readNote(String path) {
    String data = File(path).readAsStringSync();
    try {
      var jsonData = jsonDecode(data);
      return Note.fromJson(jsonData, jsonData['id']);
    } catch (e) {
      return null;
    }
  }

  Future<String> exportNote(Note note) async {
    Directory tempDir = await getFilesDir();

    var notePath = p.join(tempDir.path, "${note.title}.json");
    File(notePath).writeAsStringSync(jsonEncode(note.toJson()));
    return notePath;
  }

  Future<Note> importNote() async {
    File f = await FilePicker.getFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    return readNote(f.path);
  }

  Future<String> exportZip(List<Note> notes,
      {List<NoteCollection> collections, String filename}) async {
    // Zip a directory to out.zip using the zipDirectory convenience method
    // Directory tempDir = await getExternalStorageDirectory();

    // cache directory which is located at /storage/emulated/0/Android/data/com.myapp.de/cache/
    //Directory tempDir = (await getExternalCacheDirectories())[0];

    Directory tempDir = await getFilesDir();
    String path;

    if (filename == null) {
      path = p.join(tempDir.path,
          "sound_notes_backup_${DateTime.now().toIso8601String()}.zip");
    } else {
      path = p.join(tempDir.path, filename);
    }

    print("saving to $path");
    var encoder = ZipFileEncoder();

    // create file
    try {
      encoder.create(path);
    } on FileSystemException catch (e) {
      print("cannot create zip at location $path ${e.message}");
      return null;
    }

    Map<String, String> audioFilesMap = {};
    // write notes
    for (Note note in notes) {
      var filename = "${note.id}.json";
      var notePath = p.join(tempDir.path, filename);
      File(notePath).writeAsStringSync(jsonEncode(note.toJson()));

      encoder.addFile(File(notePath), filename);

      for (AudioFile f in note.audioFiles) {
        File file = File(f.path);
        String internalName = filename + Uuid().v4() + ".wav";

        if (file.existsSync()) {
          audioFilesMap[internalName] = f.path;
          encoder.addFile(file, internalName);
        }
      }
    }

    // write note filenames
    var notesPath = p.join(tempDir.path, NOTES_FILENAME);
    File(notesPath)
        .writeAsStringSync(jsonEncode(notes.map((n) => n.id).toList()));
    encoder.addFile(File(notesPath), NOTES_FILENAME);

    // collections

    if (collections != null) {
      for (NoteCollection c in collections) {
        var filename = "${c.id}.json";
        var collectionPath = p.join(tempDir.path, filename);
        File(collectionPath).writeAsStringSync(jsonEncode(c.toJson()));

        encoder.addFile(File(collectionPath), filename);
      }

      // write sets
      var setsPath = p.join(tempDir.path, COLLECTIONS_FILENAME);
      File(setsPath)
          .writeAsStringSync(jsonEncode(collections.map((n) => n.id).toList()));
      encoder.addFile(File(setsPath), COLLECTIONS_FILENAME);
    }

    var audioFilesPath = p.join(tempDir.path, AUDIOFILES_FILENAME);
    File(audioFilesPath).writeAsStringSync(jsonEncode(audioFilesMap));
    encoder.addFile(File(audioFilesPath), AUDIOFILES_FILENAME);

    // close
    encoder.close();
    return path;
  }
}
