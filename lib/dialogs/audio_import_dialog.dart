import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:sound/backup.dart';
import 'package:sound/dialogs/import_dialog.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:path/path.dart' as p;

showAudioImportDialog(BuildContext context, List<File> files) {
  // analyse the playability and duration of audio files

  Future<Duration> getDuration(File f) async {
    AudioPlayer _player = AudioPlayer();

    int result = await _player.play(f.path, isLocal: true, volume: 0);
    if (result != 1) return null;

    Duration duration = await _player.onDurationChanged.first;

    await _player.stop();
    await _player.dispose();

    return duration;
  }

  Future.microtask(() async {
    List<AudioFile> audioFiles = [];

    for (File f in files) {
      Duration duration = await getDuration((f));
      if (duration == null) {
        final snackBar = SnackBar(
            backgroundColor: Theme.of(context).errorColor,
            content: Text("cannot load audio ${f.path}"));
        Scaffold.of(context).showSnackBar(snackBar);
      }

      print("=> File ${f.path} is ${duration.inSeconds} seconds");
      var audioFile = AudioFile(
          lastModified: f.lastModifiedSync(),
          createdAt: DateTime.now(),
          duration: duration,
          path: f.path);
      audioFiles.add(audioFile);
    }

    // pop current dialog progress
    _showAudioImportDialog(context, audioFiles);
  });
}

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

_showAudioImportDialog(BuildContext context, List<AudioFile> files) async {
  _prepareFiles() async {
    List<AudioFile> copied = [];

    for (AudioFile f in files) {
      Directory filesDir = await Backup().getFilesDir();
      String newPath = p.join(filesDir.path, p.basename(f.path));
      File fileCopy = await moveFile(File(f.path), newPath);

      AudioFile copy = AudioFile(
          createdAt: f.createdAt,
          duration: f.duration,
          lastModified: f.lastModified,
          loopRange: f.loopRange,
          id: f.id,
          path: fileCopy.path,
          name: f.name);

      copied.add(copy);
    }
    return copied;
  }

  Future<Note> onNew() async {
    Note note = Note.empty();
    note.audioFiles = await _prepareFiles();
    return note;
  }

  onImport(Note note) async {
    note.audioFiles.addAll(await _prepareFiles());
    LocalStorage().syncNote(note);
  }

  showImportDialog(
      context, "Import ${files.length} Audio Files", onNew, onImport);
}
