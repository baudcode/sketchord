import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:sound/backup.dart';
import 'package:sound/dialogs/import_dialog.dart';
import 'package:sound/file_manager.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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

_showAudioImportDialog(BuildContext context, List<AudioFile> files) async {
  _prepareFiles() async {
    List<AudioFile> copied = [];

    for (AudioFile f in files) {
      Directory filesDir = await Backup().getFilesDir();
      String ext = p.extension(f.path);
      String newBase = Uuid().v4() + ext;
      String newPath = p.join(filesDir.path, newBase);
      AudioFile move = await FileManager().copy(f, newPath, id: f.id);
      move.name = p.basename(f.path);
      copied.add(move);
    }
    return copied;
  }

  Future<Note> onNew() async {
    Note note = Note.empty();
    note.audioFiles = await _prepareFiles();
    return note;
  }

  Future<Note> onImport(Note note) async {
    note.audioFiles.addAll(await _prepareFiles());
    return note;
  }

  Future<List<AudioFile>> onImportAudioIdeas() async {
    return await _prepareFiles();
  }

  showImportDialog(
      context, "Import ${files.length} Audio Files", onNew, onImport,
      onImportAudioIdeas: onImportAudioIdeas);
}
