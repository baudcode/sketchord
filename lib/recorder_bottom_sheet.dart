import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/looper.dart';
import 'package:sound/utils.dart';
import 'recorder_store.dart';

class SkipIcon extends StatelessWidget {
  final int number;
  final bool direction;
  final Function onPressed;

  SkipIcon({this.number, this.direction, this.onPressed});

  @override
  Widget build(BuildContext context) {
    var text = new RichText(
      text: new TextSpan(
        // Note: Styles for TextSpans must be explicitly defined.
        // Child text spans will inherit styles from parent
        style: new TextStyle(
          fontSize: 15.0,
          color: Colors.black,
        ),
        children: <TextSpan>[
          new TextSpan(
              text: (direction) ? '+' : "-",
              style: new TextStyle(fontWeight: FontWeight.bold)),
          new TextSpan(text: number.toString()),
        ],
      ),
    );

    return TextButton(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon((direction) ? Icons.add : Icons.remove,
              size: 15,
              color: Theme.of(context).primaryTextTheme.subtitle2.color),
          SizedBox(width: 5), // give the width that you desire
          Text(
            number.toString(),
            style: Theme.of(context).primaryTextTheme.subtitle2,
          )
        ],
      ),
      onPressed: onPressed,
    );

    return TextButton.icon(
        icon: Icon((direction) ? Icons.add : Icons.remove,
            size: 15, color: Colors.black),
        label: Text(
          number.toString(),
          style:
              Theme.of(context).textTheme.button.copyWith(color: Colors.black),
        ),
        onPressed: onPressed);
    //   return TextButton(onPressed: onPressed, child: text);
  }

  // TextButton(
  //     onPressed: onPressed,
  //     child: Stack(
  //       children: <Widget>[
  //         new IconButton(
  //           icon: new Icon(
  //             (direction) ? Icons.add : Icons.remove,
  //             size: 15,
  //           ),
  //           onPressed: () {},
  //         ),
  //         // new Positioned(
  //         //     top 5.5,
  //         //     right: 5.0,
  //         //     child: new Center(
  //         //       child: new Text(
  //         //         this.number.toString(),
  //         //         style:
  //         //             new TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500),
  //         //       ),
  //         // )),

  //         new Positioned(
  //             top: 15.0,
  //             right: 0,
  //             child: new Center(
  //               child: new Text(
  //                 this.number.toString(),
  //                 style: new TextStyle(
  //                     fontSize: 15.0, fontWeight: FontWeight.w500),
  //               ),
  //             )),
  //       ],
  //     )),
  //     ],
  //   ));
  // }
}

class Skipper extends StatefulWidget {
  final Color color;
  Skipper(this.color, {Key key}) : super(key: key);

  @override
  _SkipperState createState() => _SkipperState();
}

class _SkipperState extends State<Skipper> with StoreWatcherMixin<Skipper> {
  PlayerPositionStore playerPositionStore;

  @override
  void initState() {
    super.initState();
    playerPositionStore = listenToStore(playerPositionStoreToken);
  }

  skip(int seconds) {
    Duration current = playerPositionStore.position;
    Duration skipToPos = current + Duration(seconds: seconds);
    if (skipToPos.isNegative) {
      skipToPos = Duration(seconds: 0);
    }
    skipTo(skipToPos);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build

    var children = [
      SkipIcon(
          number: 30,
          direction: true,
          onPressed: () {
            skip(30);
          }),
      SkipIcon(
          number: 10,
          direction: true,
          onPressed: () {
            skip(10);
          }),
      SkipIcon(
          number: 10,
          direction: false,
          onPressed: () {
            skip(-10);
          }),
      SkipIcon(
          number: 30,
          direction: false,
          onPressed: () {
            skip(-30);
          })
    ];

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
        child: Row(
            children: children,
            mainAxisAlignment: MainAxisAlignment.spaceAround));
  }
}

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

    if (recorderStore.loopRange != null) {
      timeString += " / ${recorderStore.loopRange.end.toStringAsFixed(1)}";
    } else if (length != null) {
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
          Text("Player:"),
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
  final bool showTitle;
  final bool showSkipper;

  RecorderBottomSheet(
      {this.showTitle = false, this.showSkipper = true, Key key})
      : super(key: key);

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

  bool minimized = true;
  ActionSubscription sub;

  @override
  void initState() {
    super.initState();
    store = listenToStore(recorderBottomSheetStoreToken);

    WidgetsBinding.instance.addObserver(this);
    final keyboardOpen = WidgetsBinding.instance.window.viewInsets.bottom > 0;

    height = maxMinimizeHeight;

    _controller = AnimationController(
        value: 0.0, // TODO check this
        vsync: this,
        duration: Duration(milliseconds: 500));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0), end: Offset(0, 1.5))
        .animate(_controller);

    _sheetScaleAnimation =
        Tween<double>(begin: 1.0, end: -1.0).animate(_controller);

    sub = stopAction.listen((force) {
      if (!minimized && (!store.isLooping || force)) {
        animateForward();
      }
    });
  }

  @override
  void dispose() {
    if (sub != null) {
      sub.cancel();
    }

    if (_controller != null) {
      _controller.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void animateForward() {
    setState(() {
      minimized = true;
    });

    Navigator.of(context).pop();
  }

  void animateReverse() {
    print("reverse");

    setState(() {
      minimized = false;
    });

    showDialog(
        context: context,
        useSafeArea: true,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
              onWillPop: () async {
                animateForward();
                return true;
              },
              child: AlertDialog(
                  contentPadding: const EdgeInsets.all(0),
                  insetPadding: const EdgeInsets.all(8),
                  content: getControls(
                      minimized: false,
                      onMinimize: () {
                        animateForward();
                      })));
        });

    // Navigator.of(context)
    //     .push(MaterialPageRoute<void>(builder: (BuildContext context) {
    //   return Scaffold(
    //     appBar: AppBar(
    //         leading: IconButton(
    //             icon: Icon(Icons.fullscreen_exit_sharp),
    //             onPressed: () {
    //               animateForward();
    //               Navigator.of(context).pop();
    //             }),
    //         title: const Text("Controls")),
    //     body: Container(
    //       alignment: Alignment.bottomCenter,
    //       child: getControls(minimized: false, onExpand: () {}),
    //     ),
    //   );
    // }));
  }

  Widget getControls({bool minimized, Function onExpand, Function onMinimize}) {
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
      // on
      if (onMinimize != null) {
        onMinimize();
      }
    },
        enableMinimize: true,
        title: (widget.showTitle && store.currentAudioFile != null)
            ? store.currentAudioFile.name
            : null);

    BottomInfo info = BottomInfo(color);

    Widget controls;

    Skipper skipper;

    if (widget.showSkipper) {
      skipper = Skipper(color);
    }

    print("showLooper: $showLooper");

    if (showLooper) {
      controls = GestureDetector(
        onPanUpdate: (details) {
          if (details.delta.dy < -5 && minimized) {
            onExpand();
          } else if (details.delta.dy > 5 && !minimized) {
            onMinimize();
          }
        },
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              (!minimized)
                  ? Container(
                      color: Theme.of(context).bottomAppBarColor,
                      height: bottomHeight +
                          maxMinimizeHeight +
                          (widget.showTitle ? 30 : 0),
                      width: width,
                      child: Column(children: [
                        Container(
                            child: Column(children: [
                          SizedBox(height: 10),
                          looper,
                          SizedBox(height: 40),
                          PlayerSlider(),
                          (widget.showTitle
                              ? SizedBox(height: 30)
                              : Container())
                        ])),
                        //Expanded(child: Container()),
                      ]),
                    )
                  : Container(),
              minimized
                  ? GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 20,
                        width: width,
                        alignment: Alignment.topCenter,
                        color: Theme.of(context).bottomAppBarColor,
                        child: IconButton(
                            onPressed: onExpand,
                            icon: Icon(Icons.arrow_upward, size: 16)),
                      ))
                  : Container(),
              info,
              (skipper != null)
                  ? SizedBox(height: 10, child: Container(color: color))
                  : Container(),
              (skipper != null) ? skipper : Container()
            ]),
      );
    } else {
      controls = info;
    }

    return controls;
  }

  @override
  Widget build(BuildContext context) {
    if (!minimized) return Container();
    return getControls(minimized: true, onExpand: animateReverse);
  }
}
