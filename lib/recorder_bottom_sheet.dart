import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/looper.dart';
import 'recorder_store.dart';

class BottomInfo extends StatefulWidget {
  final Color color;
  final double pad;
  final double height;

  BottomInfo(this.color, {this.pad = 4, this.height = 50, Key key})
      : super(key: key);

  @override
  _BottomInfoState createState() => _BottomInfoState();
}

class _BottomInfoState extends State<BottomInfo>
    with StoreWatcherMixin<BottomInfo> {
  RecorderBottomSheetStore recorderStore;
  PlayerPositionStore playerPositionStore;
  RecorderPositionStore recorderPositionStore;

  @override
  void initState() {
    super.initState();
    recorderStore = listenToStore(recorderBottomSheetStoreToken);
    playerPositionStore = listenToStore(playerPositionStoreToken);
    recorderPositionStore = listenToStore(recorderPositionStoreToken);
  }

  _onButtonPress() {
    stopAction();
  }

  @override
  Widget build(BuildContext context) {
    Duration elapsed;
    Duration length;

    if (recorderStore.state == RecorderState.PAUSING ||
        recorderStore.state == RecorderState.PLAYING) {
      elapsed = playerPositionStore.position;
      if (recorderStore.currentLength != null) {
        length = recorderStore.currentLength;
      }
    } else if (recorderStore.state == RecorderState.RECORDING) {
      elapsed = recorderPositionStore.position;
    }

    String _elapsed = "";

    if (elapsed != null) {
      _elapsed = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    }

    String timeString = _elapsed;

    if (length != null) {
      timeString += " / " + length.inSeconds.toString();
    }
    timeString += " s";

    IconData icon = Icons.stop;

    String state = (RecorderState.RECORDING == recorderStore.state)
        ? "Recording"
        : (recorderStore.state == RecorderState.PAUSING)
            ? "Pausing"
            : "Playing";

    double pad = widget.pad;
    List<Widget> children = [
      Padding(
          child: IconButton(icon: Icon(icon), onPressed: _onButtonPress),
          padding: EdgeInsets.only(left: pad)),
    ];

    var timeWidget = Padding(
        child: Text(timeString),
        padding: EdgeInsets.only(left: pad, right: pad));

    if ((RecorderState.RECORDING == recorderStore.state)) {
      children.add(Expanded(child: Text(state)));
      children.add(
          Padding(child: timeWidget, padding: EdgeInsets.only(right: pad)));
    } else {
      children.add(
          Padding(child: timeWidget, padding: EdgeInsets.only(right: pad)));

      /*
      if (length != null) {
        children.add(Expanded(flex: 1, child: _getSlider()));
      } else {
       */

      if (recorderStore.state == RecorderState.PAUSING) {
        children.add(Padding(
            padding: EdgeInsets.only(right: pad),
            child: IconButton(
                icon: Icon(Icons.play_arrow),
                onPressed: () => resumeAction())));
      } else {
        children.add(Padding(
            padding: EdgeInsets.only(right: pad),
            child: IconButton(
                icon: Icon(Icons.pause), onPressed: () => pauseAction())));
      }
    }

    return Container(
        color: widget.color,
        height: widget.height,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: children));
  }
}

class PlayerSlider extends StatefulWidget {
  PlayerSlider({Key key}) : super(key: key);

  @override
  _PlayerSliderState createState() => _PlayerSliderState();
}

class _PlayerSliderState extends State<PlayerSlider>
    with StoreWatcherMixin<PlayerSlider> {
  RecorderBottomSheetStore store;
  PlayerPositionStore playerPositionStore;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
    playerPositionStore = listenToStore(playerPositionStoreToken);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 50,
        child: Column(children: [
          Expanded(
              child: Slider(
            inactiveColor: Colors.amber,
            min: 0.0,
            max: store.currentLength == null
                ? 0.0
                : store.currentLength.inSeconds.toDouble(),
            value: playerPositionStore.position.inSeconds.toDouble(),
            onChanged: (value) {
              skipTo(Duration(milliseconds: value.toInt()));
            },
            label: "Playing",
          ))
        ]));
  }
}

class RecorderBottomSheet extends StatefulWidget {
  RecorderBottomSheet({Key key}) : super(key: key);

  @override
  _RecorderBottomSheetState createState() => _RecorderBottomSheetState();
}

class _RecorderBottomSheetState extends State<RecorderBottomSheet>
    with StoreWatcherMixin<RecorderBottomSheet> {
  RecorderBottomSheetStore store;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
    print("INIT STATE....");
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (store.state == RecorderState.STOP)
      return Container(height: 0, width: 0);

    var showLooper = ((store.state == RecorderState.PLAYING ||
        store.state == RecorderState.PAUSING));
    Color color;

    if (store.state == RecorderState.PLAYING ||
        store.state == RecorderState.PAUSING) {
      color = Theme.of(context).primaryColor;
    } else if (store.state == RecorderState.RECORDING) {
      color = Colors.redAccent;
    }

    double width = MediaQuery.of(context).size.width;

    Looper looper = Looper(color);
    BottomInfo info = BottomInfo(color);

    if (showLooper) {
      return Container(
          height: 250,
          width: width,
          color: color,
          child: Column(children: [
            SizedBox(height: 20),
            looper,
            SizedBox(height: 30),
            Text("Player:"),
            PlayerSlider(),
            Expanded(child: Container()),
            info
          ]));
    } else {
      return info;
    }
  }
}
