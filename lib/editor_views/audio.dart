import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:sound/dialogs/audio_action_dialog.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/share.dart';
import 'package:sound/utils.dart';

class AudioFileListItem extends StatelessWidget {
  final Function onLongPress, onPressed;
  final AudioFile file;

  AudioFileListItem(this.file, {this.onLongPress, this.onPressed});

  @override
  Widget build(BuildContext context) {
    Widget subTitle = Text(file.createdAt.toIso8601String());
    Widget trailing = Text(file.durationString);

    if (file.loopRange != null)
      trailing = Text("${file.loopString} / ${file.durationString}");

    return ListTile(
      onLongPress: onLongPress,
      trailing: trailing,
      subtitle: subTitle,
      dense: true,
      visualDensity: VisualDensity.comfortable,
      contentPadding: EdgeInsets.all(2),
      leading: IconButton(
          icon: Icon(Icons.play_arrow),
          onPressed: onPressed,
          color: Theme.of(context).iconTheme.color),
      title: Text(file.name),
    );
  }
}

class AudioFileView extends StatelessWidget {
  final AudioFile file;
  final int index;
  final GlobalKey globalKey;
  final Function onDelete, onMove, onShare, onDuplicate, onToggleStarred;

  const AudioFileView(
      {@required this.file,
      @required this.index,
      @required this.onDelete,
      @required this.onDuplicate,
      @required this.onShare,
      @required this.onMove,
      @required this.globalKey,
      this.onToggleStarred,
      Key key})
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
            new TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new ElevatedButton(
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
    var view = AudioFileListItem(file,
        onLongPress: () => _onAudioFileLongPress(context, file),
        onPressed: () {
          print("trying to play ${file.path}");
          if (File(file.path).existsSync()) {
            startPlaybackAction(file);
          } else {
            showSnack(globalKey.currentState, "This files was removed!");
          }
        });

    return Dismissible(
      child: view,
      onDismissed: (d) {
        if (d == DismissDirection.startToEnd) {
          onDelete();
        } else {}
      },
      confirmDismiss: (d) async {
        if (d == DismissDirection.startToEnd) {
          return true;
        } else {
          var id2action = {
            AudioActionEnum.share.index: onShare,
            AudioActionEnum.move.index: onMove,
            AudioActionEnum.duplicate.index: onDuplicate,
            AudioActionEnum.star.index: onToggleStarred,
            AudioActionEnum.unstar.index: onToggleStarred,
          };

          var order = <AudioActionEnum>[];

          if (onShare != null) {
            order.add(AudioActionEnum.share);
          }

          if (onMove != null) {
            order.add(AudioActionEnum.move);
          }

          if (onDuplicate != null) {
            order.add(AudioActionEnum.duplicate);
          }

          if (onToggleStarred != null) {
            if (file.starred) {
              order.add(AudioActionEnum.unstar);
            } else {
              order.add(AudioActionEnum.star);
            }
          }

          showAudioActionDialog(context, order, (action) {
            Navigator.of(context).pop();
            if (id2action.containsKey(action.id)) {
              if (id2action[action.id] != null) {
                id2action[action.id]();
              }
            }
          });
          // shareFile(file.path);
          return false;
        }
      },
      direction: DismissDirection.horizontal,
      key: GlobalKey(),
      secondaryBackground: Card(
          margin: EdgeInsets.all(0),
          child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Icon(Icons.share),
                    Container(width: 8),
                    Icon(Icons.move_to_inbox),
                    Container(width: 8),
                    Icon(Icons.copy),
                  ]),
              padding: EdgeInsets.all(10))),
      background: Card(
          child: Container(
              color: Theme.of(context).accentColor,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }
}

playInDialog(BuildContext context, AudioFile f) {
  Duration position = Duration(seconds: 0);
  Duration duration = f.duration;

  RecorderState state = RecorderState.PLAYING;
  AudioPlayer player = AudioPlayer();

  Future.delayed(Duration(milliseconds: 100), () => player.play(f.path));

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          void onPlay() async {
            await player.resume();
            setState(() => state = RecorderState.PLAYING);
          }

          void onPause() async {
            await player.pause();
            setState(() => state = RecorderState.PAUSING);
          }

          void onSeek(Duration duration) async {
            await player.seek(duration);
          }

          void onStop() async {
            await player.stop();
            Navigator.of(context).pop();
          }

          player.onAudioPositionChanged.listen((event) {
            if (event.inMilliseconds < f.duration.inMilliseconds) {
              setState(() => position = event);
            }
          });

          player.onDurationChanged.listen((event) {
            print("duration chaned: ${event}");
            if (event != null &&
                event.inMilliseconds != duration.inMilliseconds) {
              setState(() {
                duration = event;
              });
            }
          });

          player.onPlayerCompletion.listen((event) {
            setState(() {
              state = RecorderState.STOP;
            });
            onPlay();
          });
          return AlertDialog(
            title: Text(f.name, textScaleFactor: 0.8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    height: 50,
                    child: Expanded(
                        child: Slider(
                      min: 0.0,
                      max: (duration.inMilliseconds / 1000).toDouble(),
                      value: (position.inMilliseconds / 1000).toDouble(),
                      onChanged: (value) {
                        print("on changed to $value");
                        onSeek(Duration(milliseconds: (value * 1000).floor()));
                      },
                      //activeColor: Colors.yellow,
                    ))), // slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                        icon: Icon(state == RecorderState.PLAYING
                            ? Icons.pause
                            : Icons.play_arrow),
                        onPressed:
                            state == RecorderState.PLAYING ? onPause : onPlay),
                    IconButton(icon: Icon(Icons.stop), onPressed: onStop),
                  ],
                ) // controls
              ],
            ),
            contentPadding: EdgeInsets.all(8),
            titlePadding: EdgeInsets.all(16),
          );
        });
      });
}
