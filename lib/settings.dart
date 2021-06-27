import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';
import 'package:sound/dialogs/initial_import_dialog.dart';
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
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

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

  GlobalKey<ScaffoldState> _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    store = listenToStore(settingsToken);
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
        ElevatedButton(
          child: Text(_themeAsString()),
          onPressed: toggleTheme,
        ),
      ],
    ));
  }

  _audioFormatAsString() {
    return store.audioFormat == AudioFormat.AAC ? "AAC" : "WAV";
  }

  _toggleAudioFormat() {
    AudioFormat newAudioFormat;
    if (store.audioFormat == AudioFormat.AAC) {
      newAudioFormat = AudioFormat.WAV;
    } else {
      newAudioFormat = AudioFormat.AAC;
    }
    setDefaultAudioFormat(newAudioFormat);
  }

  _audioFormatItem() {
    return _wrapItem(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: Text("AudioFormat: ")),
        ElevatedButton(
            child: Text(_audioFormatAsString()), onPressed: _toggleAudioFormat),
      ],
    ));
  }

  _editorViewAsString() {
    if (store.editorView == EditorView.onePage) {
      return "One Page";
    } else if (store.editorView == EditorView.tabs) {
      return "Tabs";
    } else
      return "";
  }

  _toggleEditorView() {
    if (store.editorView == EditorView.onePage) {
      setDefaultEditorView(EditorView.tabs);
    } else {
      setDefaultEditorView(EditorView.onePage);
    }
  }

  _editorViewItem() {
    return _wrapItem(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: Text("EditorView: ")),
        ElevatedButton(
            child: Text(_editorViewAsString()), onPressed: _toggleEditorView),
      ],
    ));
  }

  _setName() {
    return _wrapItem(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Name:"),
          Text(
            "Used for copyright in exported files",
            textScaleFactor: 0.4,
          )
        ])),
        ElevatedButton(
            child: Text(store.name == null ? "Edit" : store.name),
            onPressed: _showEditNameDialog),
      ],
    ));
  }

  _showEditNameDialog() {
    print(store.name);
    TextEditingController _controller = TextEditingController.fromValue(
        TextEditingValue(text: (store.name == null ? "Edit" : store.name)));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Set Name"),
          content: new TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            onSubmitted: (s) => print("submit $s"),
            controller: _controller,
          ),
          actions: <Widget>[
            new TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new ElevatedButton(
              child: new Text("Apply"),
              onPressed: () {
                setName(_controller.value.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  _onBackup() async {
    String path = await Backup().exportZip(
        await LocalStorage().getNotes(), await LocalStorage().getCollections());
    showSnack(_globalKey.currentState, "Exported zip to $path");
    String filename = p.basename(path);

    final params = SaveFileDialogParams(sourceFilePath: path);
    final filePath = await FlutterFileDialog.saveFile(params: params);
    print(filePath);

    // await FlutterShare.shareFile(
    //     title: filename, text: 'Share backup zip', filePath: path);
  }

  _onImport() async {
    try {
      BackupData backup = await Backup().import();
      var noteMapping = {};
      for (Note note in backup.notes) {
        var newId = Uuid().v4();
        noteMapping[note.id] = newId;
        // update id
        note.id = newId;
        //await LocalStorage().syncNote(note);
      }

      for (NoteCollection c in backup.collections) {
        c.notes = c.notes.map((Note n) {
          n.id = noteMapping[n.id];
          return n;
        }).toList();
      }

      showSelectNotesImportDialog(context, (BackupData data) {
        showSnack(_globalKey.currentState,
            "Successfully restored ${data.notes.length} notes");
      }, backup, title: "Which songs would you like to restore?");
    } on ImportException {
      showSnack(_globalKey.currentState, "Error while importing zip");
    }
  }

  _list() {
    var items = [
      _setName(),
      _themeItem(),
      _audioFormatItem(),
      _editorViewItem(),
      SizedBox(height: 10),
      ElevatedButton(child: Text("Backup"), onPressed: _onBackup),
      SizedBox(height: 10),
      ElevatedButton(child: Text("Restore"), onPressed: _onImport),
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
            title: Text("Settings"),
            leading: IconButton(
                icon: Icon(Icons.menu), onPressed: widget.onMenuPressed)),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        body: Stack(children: stackChildren));
  }
}
