import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/looper.dart';
import 'package:sound/utils.dart';
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
    stopAction(true);
  }

  @override
  Widget build(BuildContext context) {
    Duration elapsed;
    Duration length;

    String _elapsed = "";

    if (recorderStore.state == RecorderState.PAUSING ||
        recorderStore.state == RecorderState.PLAYING) {
      elapsed = playerPositionStore.position;
      _elapsed = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
      if (recorderStore.currentLength != null) {
        length = recorderStore.currentLength;
      }
    } else if (recorderStore.state == RecorderState.RECORDING) {
      elapsed = recorderPositionStore.position;
      _elapsed = elapsed.inSeconds.toString();
    }

    String timeString = _elapsed;

    if (length != null) {
      timeString += " / " + (length.inMilliseconds / 1000).toStringAsFixed(1);
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
        // decoration: BoxDecoration(
        //     color: widget.color,
        //     borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Theme.of(context).appBarTheme.color,
        //         spreadRadius: 2,
        //         blurRadius: 10,
        //       ),
        //     ]),
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
            min: 0.0,
            max: store.currentLength == null
                ? 0.0
                : (store.currentLength.inMilliseconds / 1000).toDouble(),
            value:
                (playerPositionStore.position.inMilliseconds / 1000).toDouble(),
            onChanged: (value) {
              print("on changed to $value");
              skipTo(Duration(milliseconds: (value * 1000).floor()));
            },
            //activeColor: Colors.yellow,
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
    with
        StoreWatcherMixin<RecorderBottomSheet>,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  RecorderBottomSheetStore store;
  double height;

  final double maxMinimizeHeight = 200;
  final double bottomHeight = 60;
  AnimationController _controller;

  Animation<Offset> _slideAnimation;
  Animation<double> _scaleAnimation, _sheetScaleAnimation;

  bool forward = false;
  ActionSubscription sub;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);

    WidgetsBinding.instance.addObserver(this);
    final keyboardOpen = WidgetsBinding.instance.window.viewInsets.bottom > 0;
    forward = keyboardOpen || store.minimized;

    height = maxMinimizeHeight;
    _controller = AnimationController(
        value: (forward) ? 1.0 : 0.0, // TODO check this
        vsync: this,
        duration: Duration(milliseconds: 500));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0), end: Offset(0, 1.5))
        .animate(_controller);

    _sheetScaleAnimation =
        Tween<double>(begin: 1.0, end: -1.0).animate(_controller);

    _controller.addStatusListener((status) {
      print(status);
      if (status == AnimationStatus.forward) {
        setState(() {
          forward = true;
        });
      } else if (status == AnimationStatus.reverse) {
        setState(() {
          forward = false;
        });
      } else if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setMinimized(forward);
      }
    });
    print("init recorder bottom sheet state");

    // Future.delayed(Duration(milliseconds: 100), () {
    //   if (store.minimized) {
    //     _controller.forward();
    //   } else {
    //     _controller.reverse();
    //   }
    // });

    sub = setMinimized.listen((m) {
      if (forward != m) {
        if (forward) {
          _controller.reverse();
        } else {
          _controller.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    sub.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    print("bottomInsets: $bottomInset");

    if (bottomInset > 0.0 && !store.minimized) {
      _controller.forward();
    }
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
      color = Theme.of(context).bottomAppBarColor;
    } else if (store.state == RecorderState.RECORDING) {
      color = Theme.of(context).accentColor;
    }

    double width = MediaQuery.of(context).size.width;

    Looper looper = Looper(color, () {
      _controller?.forward();
    });
    BottomInfo info = BottomInfo(color);

    if (showLooper) {
      return GestureDetector(
        onPanUpdate: (details) {
          if (details.delta.dy < -5 && forward && store.minimized) {
            print("reverse ${details.delta.dy}");
            _controller.reverse();
          } else if (details.delta.dy > 5 && !forward && !store.minimized) {
            _controller.forward();
          }
        },
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizeTransition(
                  axis: Axis.vertical,
                  sizeFactor: _sheetScaleAnimation,
                  child: Container(
                    // decoration: BoxDecoration(
                    //     color: Theme.of(context).bottomAppBarColor,
                    //     borderRadius: BorderRadius.all(Radius.circular(15)),
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: Theme.of(context).appBarTheme.color,
                    //         spreadRadius: 2,
                    //         blurRadius: 10,
                    //       ),
                    //     ]),
                    color: Theme.of(context).bottomAppBarColor,
                    height: bottomHeight + maxMinimizeHeight,
                    width: width,
                    child: Column(children: [
                      SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                              child: Column(children: [
                            SizedBox(height: 10),
                            looper,
                            SizedBox(height: 50),
                            Text("Player:"),
                            PlayerSlider(),
                          ]))),
                      //Expanded(child: Container()),
                    ]),
                  )),
              store.minimized
                  ? GestureDetector(
                      onTap: () => _controller.reverse(),
                      child: Container(
                        height: 20,
                        width: width,
                        alignment: Alignment.topCenter,
                        color: Theme.of(context).bottomAppBarColor,
                        child: IconButton(
                            icon: Icon(Icons.arrow_upward, size: 16)),
                      ))
                  : Container(),
              info
            ]),
      );
    } else {
      return info;
    }
  }
}
