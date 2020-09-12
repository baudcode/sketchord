import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'package:sound/menu.dart';
import 'settings_store.dart';

void main() {
  runApp(App());
}

// ffe57c73
Color mainColor = Colors.red.shade300;

class App extends StatefulWidget {
  // This widget is the root of your application.

  ThemeData dark = ThemeData.dark().copyWith(
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
  ThemeData light = ThemeData.light().copyWith(
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sound',
        theme: store.theme == SettingsTheme.dark ? widget.dark : widget.light,
        home: Menu());
  }
}
