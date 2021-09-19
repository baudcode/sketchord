import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/menu.dart';
import 'package:sound/model.dart';
import 'settings_store.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/sentry.dart';

Future<void> main() async {
  if (kReleaseMode) {
    print("Running release mode");
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://1b2a119a53224f48966b710bc30123be@o1005300.ingest.sentry.io/5966036';
      },
      // Init your App.
      appRunner: () => runApp(App()),
    );
  } else {
    print("Running debug mode");
    runApp(App());
  }
}

// ffe57c73
Color mainColor = Colors.red.shade300;
Color appBarColor = Colors.grey[900];
Color secondaryColor = Colors.grey[900];

class App extends StatefulWidget {
  // This widget is the root of your application.

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
      if (s != null) {
        updateSettings(s);
      } else {
        updateSettings(Settings.defaults());
      }
    });

    // _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
    //     .listen((List<SharedMediaFile> value) {
    //   setState(() {
    //     print("shared media: $value");
    //     _sharedFiles = value;
    //     print("Shared:" + (_sharedarkdFiles?.map((f) => f.path)?.join(",") ?? ""));
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
    final ThemeData dark = ThemeData.dark().copyWith(
        indicatorColor: mainColor,
        primaryColor: Colors.white,
        accentColor: mainColor,
        buttonColor: mainColor,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.light().copyWith(
            primary: mainColor,
            secondary: Colors.white,
            background: Colors.white,
            surface: Colors.white),
        textSelectionTheme: ThemeData.dark().textSelectionTheme.copyWith(
            selectionColor: mainColor,
            cursorColor: mainColor,
            selectionHandleColor: mainColor),
        highlightColor: Colors.black54,
        cardColor: Colors.grey.shade800,
        selectedRowColor: mainColor,
        appBarTheme: ThemeData.dark().appBarTheme.copyWith(
            brightness: Brightness.dark,
            color: appBarColor,
            textTheme: ThemeData.dark().textTheme
            //titleTextStyle: ThemeData.dark()
            //    .appBarTheme
            //    .titleTextStyle
            //    .copyWith(fontSize: 16)),
            ),
        buttonTheme:
            ThemeData.dark().buttonTheme.copyWith(buttonColor: mainColor),
        chipTheme: ThemeData.dark().chipTheme.copyWith(
            selectedColor: mainColor,
            secondaryLabelStyle: ThemeData.light()
                .chipTheme
                .labelStyle
                .copyWith(color: Colors.white)),
        sliderTheme: ThemeData.dark().sliderTheme.copyWith(
            trackHeight: 5,
            showValueIndicator: ShowValueIndicator.always,
            activeTrackColor: mainColor,
            valueIndicatorColor: mainColor,
            activeTickMarkColor: mainColor,
            thumbColor: mainColor,
            valueIndicatorTextStyle:
                ThemeData.dark().primaryTextTheme.bodyText1,

            //overlayColor: mainColor
            inactiveTrackColor: Colors.white),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
            foregroundColor: appBarColor,
            backgroundColor: ThemeData.dark().appBarTheme.backgroundColor));

    //   foregroundColor: Theme.of(context).appBarTheme.backgroundColor,
    // backgroundColor: Theme.of(context).appBarTheme.textTheme.button.color,
    final ThemeData light = ThemeData.light().copyWith(
        primaryColor: Colors.white,
        textSelectionTheme: ThemeData().textSelectionTheme.copyWith(
            selectionColor: mainColor,
            cursorColor: mainColor,
            selectionHandleColor: mainColor),
        cardColor: Colors.grey.shade200,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light().copyWith(
            primary: mainColor,
            secondary: Colors.black54,
            background: Colors.black54,
            surface: Colors.black54),
        appBarTheme: ThemeData.light().appBarTheme.copyWith(
            brightness: Brightness.dark,
            color: appBarColor,
            textTheme: ThemeData.light().accentTextTheme),
        chipTheme: ThemeData.light().chipTheme.copyWith(
            selectedColor: mainColor,
            secondaryLabelStyle: ThemeData.light()
                .chipTheme
                .labelStyle
                .copyWith(color: Colors.white)),
        indicatorColor: mainColor,
        accentColor: mainColor,
        highlightColor: mainColor,
        buttonTheme:
            ThemeData.dark().buttonTheme.copyWith(buttonColor: mainColor),
        sliderTheme: ThemeData.light().sliderTheme.copyWith(
            trackHeight: 4,
            thumbColor: mainColor,
            showValueIndicator: ShowValueIndicator.always,
            valueIndicatorTextStyle:
                ThemeData.light().primaryTextTheme.bodyText1,
            //overlayColor: mainColor,
            valueIndicatorColor: mainColor,
            activeTickMarkColor: mainColor,
            activeTrackColor: mainColor, // inactive loop area
            inactiveTrackColor: appBarColor),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
          backgroundColor: appBarColor,
        ));

    return MaterialApp(
        //debugShowCheckedModeBanner: false,
        title: 'SketChord',
        theme: store.theme == SettingsTheme.dark ? dark : light,
        home: Menu());
  }
}
