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
  final Function onMinimize;

  Looper(this.color, this.onMinimize, {Key key}) : super(key: key);

  @override
  _LooperState createState() => _LooperState();
}

class _LooperState extends State<Looper> with StoreWatcherMixin<Looper> {
  RangeValues range;
  RecorderBottomSheetStore store;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
    range = store.loopRange;
  }

  @override
  void dispose() {
    super.dispose();
  }

  _changeRangeValues(RangeValues values) {
    print("CHANGE.....");
    AudioFile newFile = store.currentAudioFile;
    newFile.loopRange = values;
    changeAudioFile(newFile);

    setLoopRange(values);

    if (values == null) {
      setState(() {
        range = null;
      });
    }
  }

  _view() {
    var defaultRange =
        RangeValues(0.0, store.currentLength.inMilliseconds.toDouble() / 1000);

    var lowerValue = range == null ? defaultRange.start : range.start;
    var upperValue = range == null ? defaultRange.end : range.end;
    return Container(
      color: widget.color,
      height: 100,
      child: Column(children: [
        Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: widget.onMinimize,
                    icon: Icon(Icons.arrow_downward),
                  )),
              Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: TextButton(
                      child: Text("Reset Loop"),
                      onPressed: (range != null)
                          ? () => _changeRangeValues(null)
                          : null))
            ]),
        Text(
          "Looper:",
        ),
        SizedBox(height: 20),
        Expanded(
            child: frs.RangeSlider(
          min: 0,
          onChangeEnd: (double endLowerValue, double endUpperValue) {
            _changeRangeValues(RangeValues(endLowerValue, endUpperValue));
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
