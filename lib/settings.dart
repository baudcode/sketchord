import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/utils.dart';
import 'package:uuid/uuid.dart';
import 'settings_store.dart';
import "backup.dart";
import 'db.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:path/path.dart' as p;

class Settings extends StatefulWidget {
  final Function onMenuPressed;
  Settings(this.onMenuPressed);

  @override
  State<StatefulWidget> createState() {
    return SettingsState();
  }
}

class SettingsState extends State<Settings> with StoreWatcherMixin<Settings> {
  SettingsStore store;
  RecorderBottomSheetStore recorderStore;

  GlobalKey<ScaffoldState> _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    store = listenToStore(settingsToken);
    recorderStore = listenToStore(recorderBottomSheetStoreToken);
  }

  _themeAsString() {
    if (store.theme == SettingsTheme.dark) {
      return "Dark";
    } else {
      return "Light";
    }
  }

  _wrapItem(item) {
    return Padding(
        padding: EdgeInsets.only(left: 48, bottom: 8, top: 8, right: 48),
        child: item);
  }

  _themeItem() {
    return _wrapItem(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: Text("Theme: ")),
        RaisedButton(
          child: Text(_themeAsString()),
          onPressed: toggleTheme,
        ),
      ],
    ));
  }

  _audioFormatAsString() {
    return recorderStore.audioFormat == AudioFormat.AAC ? "AAC" : "WAV";
  }

  _audioFormatItem() {
    return _wrapItem(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: Text("AudioFormat: ")),
        RaisedButton(
          child: Text(_audioFormatAsString()),
          onPressed: toggleAudioFormat,
        ),
      ],
    ));
  }

  _onExport() async {
    String path = await Backup().exportZip(await LocalStorage().getNotes());
    showSnack(_globalKey.currentState, "Exported zip to $path");
    String filename = p.basename(path);
    await FlutterShare.shareFile(
        title: filename, text: 'Share backup zip', filePath: path);
  }

  _onImport() async {
    try {
      List<Note> notes = await Backup().import();
      for (Note note in notes) {
        // update id
        note.id = Uuid().v4();
        await LocalStorage().syncNote(note);
      }
      showSnack(_globalKey.currentState,
          "Successfully imported ${notes.length} notes");
    } on ImportException {
      showSnack(_globalKey.currentState, "Error while importing zip");
    }
  }

  _list() {
    var items = [
      _themeItem(),
      _audioFormatItem(),
      SizedBox(height: 10),
      RaisedButton(child: Text("Export"), onPressed: _onExport),
      SizedBox(height: 10),
      RaisedButton(child: Text("Import"), onPressed: _onImport),
      SizedBox(height: 10),
    ];

    return ListView.builder(
        padding: EdgeInsets.all(10),
        itemBuilder: (context, index) {
          return items[index];
        },
        itemCount: items.length);
  }

  @override
  Widget build(BuildContext context) {
    // items.add(_title());
    List<Widget> stackChildren = [];

    stackChildren.add(Container(padding: EdgeInsets.all(16), child: _list()));

    return Scaffold(
        key: _globalKey,
        appBar: AppBar(
            leading: IconButton(
                icon: Icon(Icons.menu), onPressed: widget.onMenuPressed)),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        body: Stack(children: stackChildren));
  }
}
