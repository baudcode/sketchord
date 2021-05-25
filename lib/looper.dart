import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/utils.dart';
import 'range_slider.dart' as frs;

class Looper extends StatefulWidget {
  final Color color;
  Looper(this.color, {Key key}) : super(key: key);

  @override
  _LooperState createState() => _LooperState();
}

class _LooperState extends State<Looper> with StoreWatcherMixin<Looper> {
  RangeValues range;
  RecorderBottomSheetStore store;
  ActionSubscription stopSubscription;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
    range = store.loopRange;

    stopSubscription = stopAction.listen((event) {
      setState(() {
        range = null;
      });
    });
  }

  @override
  void dispose() {
    stopSubscription.cancel();
    super.dispose();
  }

  _onSaveLoop() {
    Flushbar(
      //title: "Hey Ninja",
      message: "Saved ${range.start} to ${range.end}",
      duration: Duration(seconds: 2),
    )..show(context);

    AudioFile newFile = store.currentAudioFile;
    newFile.loopRange = range;
    changeAudioFile(newFile);
  }

  _view() {
    var defaultRange =
        RangeValues(0.0, store.currentLength.inSeconds.toDouble());

    var lowerValue = range == null ? defaultRange.start : range.start;
    var upperValue = range == null ? defaultRange.end : range.end;
    return Container(
      color: widget.color,
      height: 100,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Padding(
              padding: EdgeInsets.only(right: 8),
              child: FlatButton(
                  visualDensity: VisualDensity.compact,
                  child: Text("Save Loop"),
                  onPressed: (range == null) ? null : _onSaveLoop))
        ]),
        Text(
          "Looper:",
        ),
        SizedBox(height: 20),
        Expanded(
            child: frs.RangeSlider(
          min: 0,
          onChangeEnd: (double endLowerValue, double endUpperValue) {
            setLoopRange(RangeValues(endLowerValue, endUpperValue));
          },
          max: (store.currentLength.inMilliseconds / 1000.0).toDouble(),
          showValueIndicator: true,
          lowerValue: lowerValue,
          upperValue: upperValue,
          onChanged: (double newLowerValue, double newUpperValue) {
            setState(() {
              print("change looper.....");
              range = RangeValues(newLowerValue, newUpperValue);
            });
          },
        ))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if ((store.state == RecorderState.PLAYING ||
            store.state == RecorderState.PAUSING) &&
        store.currentLength != null) {
      return _view();
    } else {
      return Container();
    }
  }
}

/** 
frs.RangeSlider(
          key: GlobalKey(),
          onChanged: (RangeValues newRange) {
            print("changed to $newRange");
            setState(() => range = newRange);
          },
          min: 0,
          divisions: 100,
          max: store.currentLength.inSeconds.toDouble(),
          values: range == null ? defaultRange : range,
        )
 **/
