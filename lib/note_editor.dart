import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart' show StoreWatcherMixin;
import 'package:flutter_share/flutter_share.dart';
import 'package:sound/editor_views/additional_info.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/editor_views/section.dart';
import 'package:sound/share.dart';
import 'editor_store.dart';
import 'model.dart';
import 'package:tuple/tuple.dart';
import 'dart:ui';
//import 'recorder.dart';
//import 'file_manager.dart';
// import 'recorder_bottom_sheet_store2.dart';
//import 'package:progress_indicators/progress_indicators.dart';
import "recorder_bottom_sheet.dart";
import "recorder_store.dart";

import 'utils.dart';

// TODO: Add an animation like this: https://i.pinimg.com/originals/6b/a1/74/6ba174bf48e9b6dc8d8bd19d13c9caa9.gif

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

  Map<Section, GlobalKey> dismissables = {};

  @override
  void initState() {
    super.initState();
    recorderStore = listenToStore(recorderBottomSheetStoreToken);
    store = listenToStore(noteEditorStoreToken);
    store.setNote(widget.note);
    print("INIT EDITOR");

    recordingFinished.clearListeners();
    recordingFinished.listen((f) {
      print("recording finished ${f.path}");
      addAudioFile(f);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  _onFloatingActionButtonPress() {
    if (recorderStore.state == RecorderState.RECORDING) {
      stopAction();
    } else {
      startRecordingAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    items.add(NoteEditorTitle(title: store.note.title));

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

    items.add(AddSectionItem());
    items.add(NoteEditorAdditionalInfo(store.note));

    if (store.note.audioFiles.length > 0)
      items.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));

    for (AudioFile f in store.note.audioFiles) {
      items.add(AudioFileView(file: f, globalKey: _globalKey));
    }

    List<Widget> stackChildren = [];

    stackChildren.add(Container(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) => items[index],
          itemCount: items.length,
        )));

    bool showSheet = recorderStore.state == RecorderState.PAUSING ||
        recorderStore.state == RecorderState.PLAYING ||
        recorderStore.state == RecorderState.RECORDING;

    return WillPopScope(
        onWillPop: () async {
          stopAction();
          return true;
        },
        child: Scaffold(
            key: _globalKey,
            appBar: AppBar(),
            floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
            floatingActionButton: FloatingActionButton(
              onPressed: _onFloatingActionButtonPress,
              child: Icon(((recorderStore.state == RecorderState.RECORDING))
                  ? Icons.mic_none
                  : Icons.mic),
              backgroundColor: ((recorderStore.state == RecorderState.RECORDING)
                  ? Colors.redAccent
                  : Theme.of(context).accentColor),
            ),
            bottomSheet:
                showSheet ? RecorderBottomSheet(key: Key("bottomSheet")) : null,
            body: Stack(children: stackChildren)));
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
