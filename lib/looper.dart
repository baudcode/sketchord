import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'range_slider.dart' as frs;

class Looper extends StatefulWidget {
  final Color color;
  final Function onMinimize;
  final bool enableMinimize;
  final bool showTitle;
  final bool enableRepeat;

  Looper(this.color, this.onMinimize,
      {this.enableMinimize = true,
      this.showTitle = false,
      Key key,
      this.enableRepeat = false})
      : super(key: key);

  @override
  _LooperState createState() => _LooperState();
}

class _LooperState extends State<Looper> with StoreWatcherMixin<Looper> {
  RangeValues range;

  RecorderBottomSheetStore store;
  ActionSubscription audioFileChange;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);
    range = store.loopRange;

    audioFileChange = startPlaybackAction.listen((AudioFile f) {
      print("playback action is started!");
      setState(() {
        range = f.loopRange;
      });
    });
  }

  @override
  void dispose() {
    audioFileChange.cancel();
    super.dispose();
  }

  _changeRangeValues(RangeValues values) {
    print("CHANGE.....");
    //AudioFile newFile = store.currentAudioFile;
    //newFile.loopRange = values;
    //changeAudioFile(newFile);

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
    var rangeMax = (store.currentLength.inMilliseconds / 1000.0).toDouble();
    print("upperValue: $upperValue");
    print("lowerValue: $lowerValue");
    print('max: $rangeMax');
    print("currentLength: ${store.currentLength}");
    var title = (store.currentAudioFile != null && widget.showTitle)
        ? store.currentAudioFile.name
        : null;

    return Container(
      color: widget.color,
      height: title != null ? 150 : 120,
      child: Column(children: [
        Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              widget.enableMinimize
                  ? Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: IconButton(
                        onPressed: widget.onMinimize,
                        icon: Icon(Icons.close),
                      ))
                  : Container(),
              Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      (widget.enableRepeat)
                          ? IconButton(
                              icon: Icon(
                                (store.repeat == Repeat.one)
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                color: (store.repeat == Repeat.all ||
                                        store.repeat == Repeat.one)
                                    ? Theme.of(context).accentColor
                                    : null,
                              ),
                              onPressed: () {
                                if (store.repeat == Repeat.all)
                                  setRepeat(Repeat.one);
                                else if (store.repeat == Repeat.one) {
                                  setRepeat(Repeat.off);
                                } else {
                                  setRepeat(Repeat.all);
                                }
                              },
                            )
                          : Container(),
                      TextButton(
                          child: Text("Reset"),
                          onPressed: (range != null)
                              ? () => _changeRangeValues(null)
                              : null),
                    ],
                  ))
            ]),
        title != null
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.headline6,
                ))
            : Container(),
        title != null ? SizedBox(height: 29) : SizedBox(height: 19),
        Container(
            height: 50,
            child: Column(children: [
              Text(
                "Looper:",
              ),
              Expanded(
                  child: frs.RangeSlider(
                min: 0,
                onChangeEnd: (double endLowerValue, double endUpperValue) {
                  _changeRangeValues(RangeValues(endLowerValue, endUpperValue));
                },
                max: (rangeMax > upperValue) ? rangeMax : upperValue,
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
            ]))
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
