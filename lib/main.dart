import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/menu.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/storage.dart';
import 'package:sound/sync_debug_store.dart';
import 'package:sound/sync_engine.dart';
import 'package:sound/sync_status_store.dart';
import 'settings_store.dart';

void main() {
  runApp(App());
}

// ffe57c73
Color mainColor = Colors.red.shade300;
Color appBarColor = Colors.grey.shade900;

class App extends StatefulWidget {
  App({super.key});

  // This widget is the root of your application.
  final ThemeData dark = ThemeData.dark().copyWith(
    primaryColor: mainColor,
    textSelectionTheme: ThemeData().textSelectionTheme.copyWith(
          selectionColor: mainColor,
          cursorColor: mainColor,
          selectionHandleColor: mainColor,
        ),
    highlightColor: Colors.black54,
    cardColor: Colors.grey.shade800,
    appBarTheme: ThemeData.dark().appBarTheme.copyWith(
          backgroundColor: appBarColor,
          titleTextStyle: ThemeData.dark().textTheme.titleLarge,
        ),
    buttonTheme: ThemeData.dark().buttonTheme.copyWith(buttonColor: mainColor),
    chipTheme: ThemeData.dark().chipTheme.copyWith(selectedColor: mainColor),
    sliderTheme: ThemeData.dark().sliderTheme.copyWith(
          trackHeight: 5,
          showValueIndicator: ShowValueIndicator.onDrag,
          activeTrackColor: mainColor,
          valueIndicatorColor: mainColor,
          activeTickMarkColor: mainColor,
          thumbColor: mainColor,
          valueIndicatorTextStyle: ThemeData.dark().textTheme.bodyMedium,

          //overlayColor: mainColor
          inactiveTrackColor: Colors.white,
        ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: mainColor,
    ),
    tabBarTheme: TabBarThemeData(indicatorColor: mainColor),
  );

  final ThemeData light = ThemeData.light().copyWith(
    primaryColor: mainColor,
    textSelectionTheme: ThemeData().textSelectionTheme.copyWith(
          selectionColor: mainColor,
          cursorColor: mainColor,
          selectionHandleColor: mainColor,
        ),
    cardColor: Colors.grey.shade200,
    appBarTheme: ThemeData.light().appBarTheme.copyWith(
          backgroundColor: appBarColor,
          titleTextStyle: ThemeData.light().textTheme.titleLarge,
        ),
    chipTheme: ThemeData.light().chipTheme.copyWith(selectedColor: mainColor),
    highlightColor: mainColor,
    sliderTheme: ThemeData.light().sliderTheme.copyWith(
          trackHeight: 4,
          thumbColor: mainColor,
          showValueIndicator: ShowValueIndicator.onDrag,
          valueIndicatorTextStyle: ThemeData.light().textTheme.bodyMedium,
          //overlayColor: mainColor,
          valueIndicatorColor: mainColor,
          activeTickMarkColor: mainColor,
          activeTrackColor: mainColor, // inactive loop area
          inactiveTrackColor: appBarColor,
        ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: mainColor,
    ),
    tabBarTheme: TabBarThemeData(indicatorColor: mainColor),
  );

  @override
  State<StatefulWidget> createState() => AppState();
}

class AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    // initialize app with loaded settings
    LocalStorage().getSettings().then((s) {
      updateSettings(s);
    });
    syncStatusStore.start();
    syncEngine.start();

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
  void dispose() {
    syncEngine.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settingsStore),
        ChangeNotifierProvider<StaticStorage>.value(value: storageStore),
        ChangeNotifierProvider<NoteEditorStore>.value(value: noteEditorStore),
        ChangeNotifierProvider<RecorderBottomSheetStore>.value(
          value: recorderBottomSheetStore,
        ),
        ChangeNotifierProvider<PlayerPositionStore>.value(
          value: playerPositionStore,
        ),
        ChangeNotifierProvider<RecorderPositionStore>.value(
          value: recorderPositionStore,
        ),
        ChangeNotifierProvider<SyncStatusStore>.value(value: syncStatusStore),
        ChangeNotifierProvider<SyncDebugStore>.value(value: syncDebugStore),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, store, _) => MaterialApp(
          title: 'SketChord',
          theme: store.theme == SettingsTheme.dark ? widget.dark : widget.light,
          home: Menu(),
        ),
      ),
    );
  }
}
