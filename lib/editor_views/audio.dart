import 'dart:io';

import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/share.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';

class AudioFileView extends StatelessWidget {
  final AudioFile file;
  final int index;
  final GlobalKey globalKey;
  final Function onDelete;
  const AudioFileView(this.file, this.index, this.onDelete, this.globalKey,
      {Key key})
      : super(key: key);

  _onAudioFileLongPress(BuildContext context, AudioFile file) {
    var controller =
        TextEditingController.fromValue(TextEditingValue(text: file.name));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Rename"),
          content: new TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            onSubmitted: (s) => print("submit $s"),
            controller: controller,
          ),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Apply"),
              onPressed: () {
                file.name = controller.value.text;
                changeAudioFile(file);
                print("Setting name of audio file to ${file.name}");
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget subTitle;

    if (file.downloadURL != null)
      subTitle = Text("synced " + file.createdAt.toIso8601String());
    else
      subTitle = Text(file.createdAt.toIso8601String());

    Widget trailing = Text(file.durationString);
    if (file.loopRange != null)
      trailing = Text("${file.loopString} / ${file.durationString}");

    var view = ListTile(
      onLongPress: () => _onAudioFileLongPress(context, file),
      trailing: trailing,
      subtitle: subTitle,
      dense: true,
      visualDensity: VisualDensity.comfortable,
      contentPadding: EdgeInsets.all(2),
      leading: IconButton(
          icon: Icon(Icons.play_arrow),
          onPressed: () {
            print("trying to play ${file.path}");
            if (File(file.path).existsSync()) {
              startPlaybackAction(file);
            } else {
              showSnack(globalKey.currentState, "This files was removed!");
            }
          }),
      title: Text(file.name),
    );

    return Dismissible(
      child: view,
      onDismissed: (d) {
        if (d == DismissDirection.endToStart) {
          onDelete();
        } else {}
      },
      confirmDismiss: (d) async {
        if (d == DismissDirection.endToStart) {
          return true;
        } else {
          shareFile(file.path);
          return false;
        }
      },
      direction: DismissDirection.horizontal,
      key: GlobalKey(),
      background: Card(
          child: Container(
              color: Colors.greenAccent,
              child: Row(children: <Widget>[Icon(Icons.share)]),
              padding: EdgeInsets.all(10))),
      secondaryBackground: Card(
          child: Container(
              color: Colors.redAccent,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }
}
