import 'package:sound/backup.dart';
import 'package:uuid/uuid.dart';

import 'model.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

Future<File> moveFile(File sourceFile, String newPath) async {
  print("Move file from ${sourceFile.path} to $newPath");
  try {
    /// prefer using rename as it is probably faster
    /// if same directory path
    return await sourceFile.rename(newPath);
  } catch (e) {
    /// if rename fails, copy the source file and then delete it
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
    return newFile;
  }
}

Future<File> copyFile(File sourceFile, String newPath) async {
  print("Copy file from ${sourceFile.path} to $newPath");

  final newFile = await sourceFile.copy(newPath);
  return newFile;
}

class FileManager {
  static final FileManager instance = new FileManager._internal();

  factory FileManager() {
    return instance;
  }

  FileManager._internal() {}
  void delete(AudioFile f) async {
    try {
      File(f.path).deleteSync();
    } catch (e) {
      print("cannot delete ${f.path} locally");
    }
  }

  Future<AudioFile> copy(AudioFile f, String newPath, {String id}) async {
    File fileCopy = await copyFile(File(f.path), newPath);
    print("copy audio file ${f.name}");
    return _new(f, fileCopy, id);
  }

  AudioFile _new(AudioFile f, File newFile, String id) {
    return AudioFile(
        createdAt: f.createdAt,
        duration: f.duration,
        id: id == null ? Uuid().v4() : id,
        lastModified: DateTime.now(),
        loopRange: f.loopRange,
        name: f.name,
        path: newFile.path);
  }

  Future<AudioFile> copyToNew(AudioFile f, {String id}) async {
    Directory filesDir = await Backup().getFilesDir();
    String ext = p.extension(f.path);
    String newPath = p.join(filesDir.path,
        "${serializeDateTime(DateTime.now())} - ${Uuid().v4()}$ext");
    return copy(f, newPath, id: id);
  }

  Future<AudioFile> move(AudioFile f, String newPath, {String id}) async {
    File fileMove = await moveFile(File(f.path), newPath);
    return _new(f, fileMove, id);
  }
}
