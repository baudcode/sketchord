import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
  List<Note> notes = await LocalStorage().getNotes();

  Note empty = Note.empty();
  empty.title = "NEW";

  notes.insert(0, empty);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      Note selected = empty;

      _import() async {
        selected.audioFiles.addAll(files);
        LocalStorage().syncNote(selected);
        print("${selected.id} ${selected.title}");
        Navigator.of(context).pop();
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text("Import ${files.length} audio files"),
          content:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Padding(
              child: Text("Note:"),
              padding: EdgeInsets.only(right: 8, top: 8),
            ),
            new DropdownButton<Note>(
                value: selected,
                items: notes
                    .map((e) => DropdownMenuItem<Note>(
                        child: Text("${notes.indexOf(e)}: ${e.title}"),
                        value: e))
                    .toList(),
                onChanged: (v) => setState(() => selected = v)),
          ]),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Import"),
              onPressed: _import,
            ),
          ],
        );
      });
    },
  );
}
