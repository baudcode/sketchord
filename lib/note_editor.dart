import 'dart:io';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:clipboard_manager/clipboard_manager.dart';
import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart' show StoreWatcherMixin;
import 'package:flutter_share/flutter_share.dart';
import 'package:sound/dialogs/color_picker_dialog.dart';
import 'package:sound/dialogs/import_dialog.dart';
import 'package:sound/editor_views/additional_info.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/editor_views/section.dart';
import 'package:sound/dialogs/export_dialog.dart';
import 'package:sound/export.dart';
import 'package:sound/file_manager.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/note_viewer.dart';
import 'package:sound/share.dart';
import 'editor_store.dart';
import 'model.dart';
import 'package:tuple/tuple.dart';
//import 'recorder.dart';
//import 'file_manager.dart';
// import 'recorder_bottom_sheet_store2.dart';
//import 'package:progress_indicators/progress_indicators.dart';
import "recorder_bottom_sheet.dart";
import "recorder_store.dart";

import 'utils.dart';

class NoteEditor extends StatefulWidget {
  final Note note;

  NoteEditor(this.note);

  @override
  State<StatefulWidget> createState() {
    return NoteEditorState();
  }
}

class NoteEditorState extends State<NoteEditor>
    with StoreWatcherMixin<NoteEditor> {
  RecorderBottomSheetStore recorderStore;
  NoteEditorStore store;
  GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  List<String> popupMenuActions = ["share", "copy"];

  Map<Section, GlobalKey> dismissables = {};

  @override
  void initState() {
    super.initState();
    recorderStore = listenToStore(recorderBottomSheetStoreToken);
    store = listenToStore(noteEditorStoreToken);
    store.setNote(widget.note);
    print("INIT EDITOR");

    recordingFinished.clearListeners();
    recordingFinished.listen((f) async {
      print("recording finished ${f.path} with duration ${f.duration}");

      final player = AudioPlayer();
      await player.setUrl(f.path);

      return Future.delayed(
        const Duration(milliseconds: 200),
        () async {
          f.duration = Duration(milliseconds: await player.getDuration());
          addAudioFile(f);
        },
      );
    });
  }

  @override
  void dispose() {
    recordingFinished.clearListeners();
    //store.dispose();
    //recorderStore.dispose();
    super.dispose();
  }

  _onFloatingActionButtonPress() {
    if (recorderStore.state == RecorderState.RECORDING) {
      stopAction();
    } else {
      startRecordingAction();
    }
  }

  _onAudioFileDelete(AudioFile file, int index) {
    Flushbar bar;

    bar = Flushbar(
      //title: "Hey Ninja",
      message: "${file.name} was deleted",
      onStatusChanged: (status) {
        // lets check whether the file was restored or not
        if (status == FlushbarStatus.DISMISSED &&
            !store.note.audioFiles.contains(file)) {
          hardDeleteAudioFile(file);
        }
      },
      mainButton: FlatButton(
          child: Text("Undo"),
          onPressed: () {
            if (!store.note.audioFiles.contains(file)) {
              restoreAudioFile(Tuple2(file, index));
            }
            bar.dismiss();
          }),
      duration: Duration(seconds: 3),
    );
    bar.show(context);

    softDeleteAudioFile(file);
  }

  _copyToClipboard(BuildContext context) {
    String text = Exporter.getText(store.note);

    ClipboardManager.copyToClipBoard(text).then((result) {
      final snackBar = SnackBar(
        content: Text('Copied to Clipboard'),
      );
      _globalKey.currentState.showSnackBar(snackBar);
    });
  }

  _runPopupAction(String action) {
    switch (action) {
      case "share":
        showExportDialog(context, store.note);
        break;
      case "star":
        toggleStarred();
        break;
      case "copy":
        _copyToClipboard(context);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    items.add(NoteEditorTitle(
      title: store.note.title,
      onChange: changeTitle,
      allowEdit: true,
    ));

    // sections
    for (var i = 0; i < store.note.sections.length; i++) {
      if (!dismissables.containsKey(store.note.sections[i]))
        dismissables[store.note.sections[i]] = GlobalKey();

      bool showMoveUp = (i != 0);
      bool showMoveDown = (i != (store.note.sections.length - 1));
      items.add(SectionListItem(
          globalKey: dismissables[store.note.sections[i]],
          section: store.note.sections[i],
          moveDown: showMoveDown,
          moveUp: showMoveUp));
    }
    // add section item
    items.add(AddSectionItem());

    // all additional info
    items.add(NoteEditorAdditionalInfo(store.note));

    // audio files as stack
    if (store.note.audioFiles.length > 0)
      items.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));

    store.note.audioFiles.asMap().forEach((int index, AudioFile f) {
      items.add(AudioFileView(
          file: f,
          index: index,
          onDelete: () => _onAudioFileDelete(f, index),
          onMove: () {
            showImportDialog(context, "Copy audio to", () async {
              // new audio file

              AudioFile copy = await FileManager().copyToNew(f);
              Future.delayed(Duration(milliseconds: 200), () {
                showSnack(_globalKey.currentState,
                    "The audio file as copiedr to a new note");
              });
              Note note = Note.empty();
              note.audioFiles.add(copy);

              // manual sync
              LocalStorage().syncNote(note);
              return note;
            }, (Note note) async {
              AudioFile copy = await FileManager().copyToNew(f);

              Future.delayed(Duration(milliseconds: 200), () {
                showSnack(_globalKey.currentState,
                    "The audio file as copied to a ${note.title}");
              });

              if (note.id == widget.note.id) {
                copy.name += " - copy";
                addAudioFile(copy);
              } else {
                // manual sync
                note.audioFiles.add(copy);
                LocalStorage().syncNote(note);
              }

              return note;
            },
                openNote: false,
                syncNote:
                    false, // do not sync note, because otherwise this component gets updated twice
                importButtonText: "Copy",
                newButtonText: "Copy as NEW");
          },
          onShare: () => shareFile(f.path),
          globalKey: _globalKey));
    });

    List<Widget> stackChildren = [];

    stackChildren.add(Container(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) => items[index],
          itemCount: items.length,
        )));

    // bottom sheets
    bool showSheet = recorderStore.state == RecorderState.PAUSING ||
        recorderStore.state == RecorderState.PLAYING ||
        recorderStore.state == RecorderState.RECORDING;

    Icon icon = Icon(
        ((recorderStore.state == RecorderState.RECORDING))
            ? Icons.mic_none
            : Icons.mic,
        color: recorderStore.state == RecorderState.RECORDING
            ? Theme.of(context).accentColor
            : null);
    PopupMenuButton popup = PopupMenuButton<String>(
      onSelected: _runPopupAction,
      itemBuilder: (context) {
        return popupMenuActions.map<PopupMenuItem<String>>((String action) {
          return PopupMenuItem(value: action, child: Text(action));
        }).toList();
      },
    );

    // actions
    List<Widget> actions = [
      // IconButton(
      //     icon: Icon(Icons.share),
      //     onPressed: () => showExportDialog(context, store.note)),
      IconButton(
          icon: Icon((store.note.starred) ? Icons.star : Icons.star_border),
          onPressed: toggleStarred),
      IconButton(icon: icon, onPressed: _onFloatingActionButtonPress),
      Stack(alignment: Alignment.center, children: [
        IconButton(
            icon: Icon(Icons.color_lens),
            onPressed: () =>
                showColorPickerDialog(context, store.note.color, changeColor)),
        Positioned(
            bottom: 17,
            right: 14,
            child: Container(
                decoration: BoxDecoration(
                    color: store.note.color,
                    borderRadius: BorderRadius.circular(10)),
                height: 10,
                width: 10)),
      ]),
      IconButton(
          icon: Icon(Icons.play_circle_filled),
          onPressed: () {
            Navigator.push(
                context,
                new MaterialPageRoute(
                    builder: (context) => NoteViewer(store.note,
                        showAdditionalInformation: false,
                        showAudioFiles: false,
                        showSheet: true,
                        showTitle: false)));
          }),
      // IconButton(
      //     icon: Icon(Icons.content_copy),
      //     onPressed: () => _copyToClipboard(context))
      popup,
    ];

    // will pop score
    return WillPopScope(
        onWillPop: () async {
          stopAction();
          return true;
        },
        child: Scaffold(
            key: _globalKey,
            appBar: AppBar(
              //backgroundColor: store.note.color,
              actions: actions,
            ),
            bottomSheet:
                showSheet ? RecorderBottomSheet(key: Key("bottomSheet")) : null,
            body: Container(child: Stack(children: stackChildren))));
  }
}

/* 
 if (store.loading) {
      stackChildren.add(BackdropFilter(
          filter: new ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: new Container(
            child: Center(child: CircularProgressIndicator()),
            decoration: new BoxDecoration(
                color:
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5)),
          )));
    }
*/
