import 'model.dart';
import 'dart:io';

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
}
