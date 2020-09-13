import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:sound/dialogs/import_dialog.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

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
  Note onNew() {
    Note note = Note.empty();
    note.audioFiles = files;
    return note;
  }

  onImport(Note note) {
    note.audioFiles.addAll(files);
    LocalStorage().syncNote(note);
  }

  showImportDialog(
      context, "Import ${files.length} Audio Files", onNew, onImport);
}
