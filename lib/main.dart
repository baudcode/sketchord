import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'settings_store.dart';
import "home.dart";

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  // This widget is the root of your application.
  ThemeData dark = ThemeData.dark().copyWith(
      indicatorColor: Colors.blue,
      accentColor: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(backgroundColor: Colors.blue));
  ThemeData light = ThemeData.light().copyWith(
      indicatorColor: Colors.blue,
      accentColor: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(backgroundColor: Colors.blue));

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
        home: Home());
  }
}
