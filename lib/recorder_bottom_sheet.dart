import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'recorder_store.dart';

class RecorderBottomSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return RecorderBottomSheetState();
  }
}

class RecorderBottomSheetState extends State<RecorderBottomSheet>
    with StoreWatcherMixin<RecorderBottomSheet> {
  RecorderBottomSheetStore store;
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
  }

  _onButtonPress() {
    stopAction();
  }

  @override
  Widget build(BuildContext context) {
    if (store.state == RecorderState.STOP)
      return Container(height: 0, width: 0);

    String elapsed = "";
    if (store.elapsed != null) elapsed = store.elapsed.inSeconds.toString();

    String timeString = elapsed;

    if (store.state == RecorderState.PLAYING ||
        store.state == RecorderState.PAUSING) {
      if (store.currentLength != null) {
        timeString += " / " + store.currentLength.inSeconds.toString();
      }
    }
    timeString += " s";

    Color color;
    IconData icon;

    if (store.state == RecorderState.PLAYING ||
        store.state == RecorderState.PAUSING) {
      icon = Icons.stop;
      color = Theme.of(context).primaryColor;
    } else if (store.state == RecorderState.RECORDING) {
      icon = Icons.stop;
      color = Colors.redAccent;
    }
    String state =
        (RecorderState.RECORDING == store.state) ? "Recording" : "Playing";

    double pad = 4;

    List<Widget> children = [
      Padding(
          child: IconButton(icon: Icon(icon), onPressed: _onButtonPress),
          padding: EdgeInsets.only(left: pad)),
    ];

    var timeWidget = Padding(
        child: Text(timeString),
        padding: EdgeInsets.only(left: pad, right: pad));

    if ((RecorderState.RECORDING == store.state)) {
      children.add(Expanded(child: Text(state)));
      children.add(
          Padding(child: timeWidget, padding: EdgeInsets.only(right: pad)));
    } else {
      if (store.currentLength != null && store.elapsed != null) {
        print('elapsed: ${store.elapsed.inMilliseconds.toDouble()}');
        print('max: ${store.currentLength.inMilliseconds.toDouble()}');
        children.add(Expanded(
            flex: 1,
            child: Slider(
              min: 0.0,
              max: store.currentLength.inMilliseconds.toDouble(),
              value: store.elapsed.inMilliseconds.toDouble(),
              onChanged: (value) {
                skipTo(Duration(milliseconds: value.toInt()));
              },
              label: "Playing",
            )));
      } else {
        children.add(Expanded(child: Text(state)));
      }

      if (store.state == RecorderState.PAUSING) {
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
        color: color,
        height: 50,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: children));
  }
}
