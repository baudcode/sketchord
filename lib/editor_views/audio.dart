import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../dialogs/audio_action_dialog.dart';
import '../editor_store.dart';
import '../model.dart';
import '../recorder_store.dart';
import '../utils.dart';

class AudioFileListItem extends StatelessWidget {
  final VoidCallback? onLongPress;
  final VoidCallback? onPressed;
  final AudioFile file;

  const AudioFileListItem(this.file, {this.onLongPress, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    Widget trailing = Text(file.durationString);
    if (file.loopRange != null) {
      trailing = Text('${file.loopString} / ${file.durationString}');
    }
    return ListTile(
      onLongPress: onLongPress,
      trailing: trailing,
      subtitle: Text(file.createdAt.toIso8601String()),
      dense: true,
      visualDensity: VisualDensity.comfortable,
      contentPadding: const EdgeInsets.all(2),
      leading: IconButton(icon: const Icon(Icons.play_arrow), onPressed: onPressed),
      title: Text(file.name),
    );
  }
}

class AudioFileView extends StatelessWidget {
  final AudioFile file;
  final int index;
  final GlobalKey<ScaffoldState> globalKey;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onShare;

  const AudioFileView({
    required this.file,
    required this.index,
    required this.onDelete,
    required this.onShare,
    required this.onMove,
    required this.globalKey,
    super.key,
  });

  Future<void> _onAudioFileLongPress(BuildContext context, AudioFile file) async {
    final controller = TextEditingController(text: file.name);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            controller: controller,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () {
                file.name = controller.value.text;
                changeAudioFile(file);
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
    final view = AudioFileListItem(
      file,
      onLongPress: () => _onAudioFileLongPress(context, file),
      onPressed: () {
        if (File(file.path).existsSync()) {
          startPlaybackAction(file);
        } else {
          showSnack(globalKey.currentState, 'This file was removed!');
        }
      },
    );

    return Dismissible(
      key: ValueKey(file.id),
      child: view,
      onDismissed: (d) {
        if (d == DismissDirection.endToStart) {
          onDelete();
        }
      },
      confirmDismiss: (d) async {
        if (d == DismissDirection.endToStart) return true;
        showAudioActionDialog(
          context,
          [
            AudioActionEnum.share,
            AudioActionEnum.move,
          ],
          (action) {
            Navigator.of(context).pop();
            if (action.id == 0) {
              onShare();
            } else if (action.id == 1) {
              onMove();
            }
          },
        );
        return false;
      },
      direction: DismissDirection.horizontal,
      background: Card(
        child: Container(
          color: Colors.greenAccent,
          padding: const EdgeInsets.all(10),
          child: const Row(children: <Widget>[Icon(Icons.share)]),
        ),
      ),
      secondaryBackground: Card(
        child: Container(
          color: Colors.redAccent,
          padding: const EdgeInsets.all(10),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[Icon(Icons.delete)],
          ),
        ),
      ),
    );
  }
}

void playInDialog(BuildContext context, AudioFile f) {
  Duration position = Duration.zero;
  Duration duration = f.duration;
  RecorderState state = RecorderState.playing;
  final player = AudioPlayer();

  Future.delayed(const Duration(milliseconds: 100), () {
    player.play(DeviceFileSource(f.path));
  });

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        void onPlay() async {
          await player.resume();
          setState(() => state = RecorderState.playing);
        }

        void onPause() async {
          await player.pause();
          setState(() => state = RecorderState.pausing);
        }

        void onSeek(Duration d) async => player.seek(d);

        void onStop() async {
          await player.stop();
          if (context.mounted) Navigator.of(context).pop();
        }

        player.onPositionChanged.listen((event) {
          if (event.inMilliseconds < duration.inMilliseconds) {
            setState(() => position = event);
          }
        });
        player.onDurationChanged.listen((event) {
          if (event.inMilliseconds != duration.inMilliseconds) {
            setState(() => duration = event);
          }
        });
        player.onPlayerComplete.listen((_) {
          setState(() => state = RecorderState.stop);
        });

        return AlertDialog(
          title: Text(f.name, textScaler: const TextScaler.linear(0.8)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0.0,
                max: (duration.inMilliseconds / 1000).toDouble(),
                value: (position.inMilliseconds / 1000).toDouble().clamp(
                    0.0, (duration.inMilliseconds / 1000).toDouble()),
                onChanged: (value) {
                  onSeek(Duration(milliseconds: (value * 1000).floor()));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(state == RecorderState.playing
                        ? Icons.pause
                        : Icons.play_arrow),
                    onPressed:
                        state == RecorderState.playing ? onPause : onPlay,
                  ),
                  IconButton(icon: const Icon(Icons.stop), onPressed: onStop),
                ],
              ),
            ],
          ),
          contentPadding: const EdgeInsets.all(8),
          titlePadding: const EdgeInsets.all(16),
        );
      });
    },
  );
}
