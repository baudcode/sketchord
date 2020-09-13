import 'dart:async';

import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/menu.dart';
import 'package:sound/model.dart';
import 'settings_store.dart';

void main() {
  runApp(App());
}

// ffe57c73
Color mainColor = Colors.red.shade300;

class App extends StatefulWidget {
  // This widget is the root of your application.

  final ThemeData dark = ThemeData.dark().copyWith(
      indicatorColor: mainColor,
      accentColor: mainColor,
      buttonColor: mainColor,
      sliderTheme: ThemeData.dark().sliderTheme.copyWith(
          trackHeight: 5,
          activeTickMarkColor: Colors.green,
          showValueIndicator: ShowValueIndicator.always,
          valueIndicatorTextStyle: ThemeData.dark().primaryTextTheme.bodyText1,

          //overlayColor: mainColor,
          inactiveTrackColor: Colors.redAccent),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(backgroundColor: mainColor));
  final ThemeData light = ThemeData.light().copyWith(
      indicatorColor: mainColor,
      accentColor: mainColor,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(backgroundColor: mainColor));

  @override
  State<StatefulWidget> createState() {
    return AppState();
  }
}

class AppState extends State<App> with StoreWatcherMixin<App> {
  SettingsStore store;

  @override
  void initState() {
    super.initState();
    store = listenToStore(settingsToken);

    // initialize app with loaded settings
    LocalStorage().getSettings().then((s) {
      updateSettings(s);
    });

    // _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
    //     .listen((List<SharedMediaFile> value) {
    //   setState(() {
    //     print("shared media: $value");
    //     _sharedFiles = value;
    //     print("Shared:" + (_sharedFiles?.map((f) => f.path)?.join(",") ?? ""));
    //   });
    // }, onError: (err) {
    //   print("getIntentDataStream error: $err");
    // });

    // // For sharing or opening urls/text coming from outside the app while the app is in the memory
    // _intentDataStreamSubscription =
    //     ReceiveSharingIntent.getTextStream().listen((String value) {
    //   setState(() {
    //     print("Shared text: $value");
    //   });
    // }, onError: (err) {
    //   print("getLinkStream error: $err");
    // });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        //debugShowCheckedModeBanner: false,
        title: 'Sound',
        theme: store.theme == SettingsTheme.dark ? widget.dark : widget.light,
        home: Menu());
  }
}
