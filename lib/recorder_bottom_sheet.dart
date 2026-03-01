import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'looper.dart';
import 'recorder_store.dart';

class BottomInfo extends StatelessWidget {
  final Color color;
  final double pad;
  final double height;

  const BottomInfo(this.color, {this.pad = 4, this.height = 50, super.key});

  @override
  Widget build(BuildContext context) {
    final recorderStore = context.watch<RecorderBottomSheetStore>();
    final playerPositionStore = context.watch<PlayerPositionStore>();
    final recorderPositionStore = context.watch<RecorderPositionStore>();

    Duration elapsed = Duration.zero;
    Duration? length;

    if (recorderStore.state == RecorderState.pausing ||
        recorderStore.state == RecorderState.playing) {
      elapsed = playerPositionStore.position;
      length = recorderStore.currentLength;
    } else if (recorderStore.state == RecorderState.recording) {
      elapsed = recorderPositionStore.position;
    }

    String timeString = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    if (length != null) {
      timeString += ' / ${(length.inMilliseconds / 1000).toStringAsFixed(1)}';
    }
    timeString += ' s';

    final children = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: pad),
        child: IconButton(icon: const Icon(Icons.stop), onPressed: () => stopAction()),
      ),
    ];

    final timeWidget = Padding(
      padding: EdgeInsets.only(left: pad, right: pad),
      child: Text(timeString),
    );

    if (recorderStore.state == RecorderState.recording) {
      children.add(const Expanded(child: Text('Recording')));
      children.add(Padding(
        padding: EdgeInsets.only(right: pad),
        child: timeWidget,
      ));
    } else {
      children.add(Padding(
        padding: EdgeInsets.only(right: pad),
        child: timeWidget,
      ));

      if (recorderStore.state == RecorderState.pausing) {
        children.add(Padding(
          padding: EdgeInsets.only(right: pad),
          child: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => resumeAction(),
          ),
        ));
      } else {
        children.add(Padding(
          padding: EdgeInsets.only(right: pad),
          child: IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => pauseAction(),
          ),
        ));
      }
    }

    return Container(
      color: color,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      ),
    );
  }
}

class PlayerSlider extends StatelessWidget {
  const PlayerSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecorderBottomSheetStore>();
    final playerPositionStore = context.watch<PlayerPositionStore>();

    final max = store.currentLength == null
        ? 0.0
        : (store.currentLength!.inMilliseconds / 1000).toDouble();
    final value = (playerPositionStore.position.inMilliseconds / 1000).toDouble();

    return SizedBox(
      height: 50,
      child: Slider(
        min: 0.0,
        max: max,
        value: value.clamp(0.0, max == 0.0 ? 0.0 : max),
        onChanged: (raw) {
          skipTo(Duration(milliseconds: (raw * 1000).floor()));
        },
      ),
    );
  }
}

class RecorderBottomSheet extends StatelessWidget {
  const RecorderBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecorderBottomSheetStore>();

    if (store.state == RecorderState.stop) {
      return const SizedBox.shrink();
    }

    final showLooper = store.state == RecorderState.playing ||
        store.state == RecorderState.pausing;
    final color = showLooper
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).primaryColor;
    final width = MediaQuery.of(context).size.width;

    if (showLooper) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.black,
              spreadRadius: 1,
              blurRadius: 15,
            ),
          ],
        ),
        height: 300,
        width: width,
        child: Column(children: [
          const SizedBox(height: 10),
          Looper(color),
          const SizedBox(height: 50),
          const Text('Player:'),
          const PlayerSlider(),
          const Expanded(child: SizedBox()),
          BottomInfo(color),
        ]),
      );
    }

    return BottomInfo(color);
  }
}
