import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import "model.dart";
import 'package:path/path.dart' as p;

const NOTES_FILENAME = "notes.json";

class ImportException implements Exception {
  String errMsg() => 'cannot import file';
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

  Future<List<Note>> importZip() async {
    File f = await FilePicker.getFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return await readZip(f.path);
  }

  String decodeZipContent(ArchiveFile f) {
    Uint8List l = f.content;
    return new String.fromCharCodes(l);
  }

  Future<List<Note>> readZip(String path) async {
    List<Note> notes = [];
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
    } catch (e) {
      print("unknwon error occurred $e");
      throw new ImportException();
    }

    return notes;
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

  Future<String> exportZip(List<Note> notes) async {
    // Zip a directory to out.zip using the zipDirectory convenience method
    // Directory tempDir = await getExternalStorageDirectory();

    // cache directory which is located at /storage/emulated/0/Android/data/com.myapp.de/cache/
    //Directory tempDir = (await getExternalCacheDirectories())[0];
    Directory tempDir = await getFilesDir();
    print("saving into directory ${tempDir.path}");

    String path = p.join(tempDir.path,
        "sound_notes_backup_${DateTime.now().toIso8601String()}.zip");

    print("saving to $path");
    var encoder = ZipFileEncoder();

    try {
      encoder.create(path);
    } on FileSystemException catch (e) {
      print("cannot create zip at location $path ${e.message}");
      return null;
    }

    for (Note note in notes) {
      var filename = "${note.id}.json";
      var notePath = p.join(tempDir.path, filename);
      File(notePath).writeAsStringSync(jsonEncode(note.toJson()));

      encoder.addFile(File(notePath), filename);
    }

    var notesPath = p.join(tempDir.path, NOTES_FILENAME);
    File(notesPath)
        .writeAsStringSync(jsonEncode(notes.map((n) => n.id).toList()));
    encoder.addFile(File(notesPath), NOTES_FILENAME);
    encoder.close();
    return path;
  }
}
