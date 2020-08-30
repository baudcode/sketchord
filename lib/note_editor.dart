import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart' show StoreWatcherMixin;
import 'package:flutter_share/flutter_share.dart';
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

class Editable extends StatefulWidget {
  final String initialValue, hintText;
  final TextStyle textStyle;
  final ValueChanged<String> onChange;
  final int maxLines;
  final bool multiline;
  final String labelText;

  Editable(
      {this.initialValue,
      this.textStyle,
      this.onChange,
      this.hintText,
      this.maxLines,
      this.multiline = false,
      this.labelText});

  @override
  State<StatefulWidget> createState() {
    return EditableState();
  }
}

class EditableState extends State<Editable> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController.fromValue(
        TextEditingValue(text: widget.initialValue));
  }

  @override
  void dispose() {
    super.dispose();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        decoration: InputDecoration.collapsed(hintText: widget.hintText)
            .copyWith(labelText: widget.labelText),
        keyboardType:
            (widget.multiline) ? TextInputType.multiline : TextInputType.text,
        expands: false,
        minLines: 1,
        maxLines: 10,

        //maxLines: widget.maxLines,
        enableInteractiveSelection: true,
        onChanged: (s) {
          print("widget changed");
          widget.onChange(s);
        },
        controller: _controller,
        textInputAction:
            (widget.multiline) ? TextInputAction.newline : TextInputAction.done,
        style: widget.textStyle);
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

  _sectionListItem(
      Section section, bool moveDown, bool moveUp, GlobalKey globalKey) {
    List<Widget> trailingWidgets = [];
    if (moveDown)
      trailingWidgets.add(IconButton(
          icon: Icon(Icons.arrow_drop_down),
          onPressed: () => moveSectionDown(section)));
    if (moveUp)
      trailingWidgets.add(IconButton(
        icon: Icon(Icons.arrow_drop_up),
        onPressed: () => moveSectionUp(section),
      ));
    Widget trailing = Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: trailingWidgets
          .map<Widget>((t) => Row(children: <Widget>[t]))
          .toList(),
    );

    Card card = Card(
        child: Container(
            child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Expanded(
            child: Container(
                padding: EdgeInsets.all(10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Editable(
                              initialValue: section.title,
                              textStyle: Theme.of(context).textTheme.subtitle,
                              onChange: (s) =>
                                  changeSectionTitle(Tuple2(section, s)),
                              hintText: 'Title',
                              maxLines: 100)),
                      Wrap(children: [
                        Editable(
                            initialValue: section.content,
                            textStyle: Theme.of(context)
                                .textTheme
                                .subhead
                                .copyWith(fontSize: 13),
                            onChange: (s) => changeContent(Tuple2(section, s)),
                            hintText: 'Content',
                            maxLines: 100,
                            multiline: true)
                      ])
                    ]))),
        trailing
      ],
    )));

    return Dismissible(
      child: card,
      onDismissed: (d) {
        deleteSection(section);
        showUndoSnackbar(_globalKey.currentState, "Section", section, (_) {
          undoDeleteSection();
        });
      },
      direction: DismissDirection.startToEnd,
      key: globalKey,
      background: Card(
          child: Container(
              color: Colors.redAccent,
              child: Row(children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }

  _sectionView(Section section, bool moveDown, bool moveUp) {
    List<Widget> trailingWidgets = [];
    if (moveDown)
      trailingWidgets.add(IconButton(
          icon: Icon(Icons.arrow_drop_down),
          onPressed: () => moveSectionDown(section)));
    if (moveUp)
      trailingWidgets.add(IconButton(
        icon: Icon(Icons.arrow_drop_up),
        onPressed: () => moveSectionUp(section),
      ));
    Widget trailing = Column(
      children: trailingWidgets
          .map<Widget>((t) => Row(children: <Widget>[t]))
          .toList(),
    );

    return ListTile(
        onLongPress: () => deleteSection(section),
        contentPadding: EdgeInsets.all(10),
        title: Text(section.title),
        subtitle: Text(section.content),
        trailing: trailing);
  }

  _onAudioFileLongPress(AudioFile file) {
    var controller =
        TextEditingController.fromValue(TextEditingValue(text: file.name));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Rename"),
          content: new TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            onSubmitted: (s) => print("submit $s"),
            controller: controller,
          ),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Apply"),
              onPressed: () {
                file.name = controller.value.text;
                changeAudioFile(file);
                print("Setting name of audio file to ${file.name}");
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // use this: https://pub.flutter-io.cn/packages/audio_recorder

  _audioFileView(AudioFile file) {
    Widget subTitle;

    if (file.downloadURL != null)
      subTitle = Text("synced " + file.createdAt.toIso8601String());
    else
      subTitle = Text(file.createdAt.toIso8601String());

    var view = ListTile(
      onLongPress: () => _onAudioFileLongPress(file),
      trailing: Text(file.durationString),
      subtitle: subTitle,
      leading: IconButton(
          icon: Icon(Icons.play_arrow),
          onPressed: () {
            print("trying to play ${file.path}");
            if (File(file.path).existsSync()) {
              startPlaybackAction(file.path);
            } else {
              showSnack(_globalKey.currentState, "This files was removed!");
            }
          }),
      title: Text(file.name),
    );

    return Dismissible(
      child: view,
      onDismissed: (d) {
        if (d == DismissDirection.endToStart) {
          deleteAudioFile(file);
        } else {}
      },
      confirmDismiss: (d) async {
        if (d == DismissDirection.endToStart) {
          return true;
        } else {
          shareFile(file.path);
          return false;
        }
      },
      direction: DismissDirection.horizontal,
      key: GlobalKey(),
      background: Card(
          child: Container(
              color: Colors.greenAccent,
              child: Row(children: <Widget>[Icon(Icons.share)]),
              padding: EdgeInsets.all(10))),
      secondaryBackground: Card(
          child: Container(
              color: Colors.redAccent,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }

  _onFloatingActionButtonPress() {
    if (recorderStore.state == RecorderState.RECORDING) {
      stopAction();
    } else {
      startRecordingAction();
    }
  }

  _addSectionItem() {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Container(
            height: 40,
            decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).cardColor, width: 2)),
            child: FlatButton(
              child: Text("Add Section",
                  style: Theme.of(context).textTheme.caption),
              onPressed: () => addSection(Section(title: "", content: "")),
            )));
  }

  _edit({initial, title, hint, onChanged}) {
    return TextFormField(
        initialValue: initial,
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        onChanged: (V) => onChanged(V),
        maxLines: 1);
  }

  _additionalInfoItem() {
    return Padding(
        padding: EdgeInsets.only(left: 10, top: 10),
        child: Wrap(runSpacing: 1, children: [
          _edit(
              initial: store.note.tuning == null ? "" : store.note.tuning,
              title: "Tuning",
              hint: "f.e. Standard, Dadgad",
              onChanged: changeTuning),
          _edit(
              initial:
                  store.note.capo == null ? "" : store.note.capo.toString(),
              title: "Capo",
              hint: "f.e. 7, 5",
              onChanged: changeCapo),
          _edit(
              initial: store.note.key == null ? "" : store.note.key.toString(),
              title: "Key",
              hint: "f.e. C Major, A Minor",
              onChanged: changeKey),
          _edit(
              initial:
                  store.note.label == null ? "" : store.note.label.toString(),
              title: "Label",
              hint: "f.e. Rock, Pop...",
              onChanged: changeLabel),
        ]));
  }

  _title() {
    return ListTile(
        visualDensity: VisualDensity.comfortable,
        title: TextFormField(
            initialValue: store.note.title,
            decoration: InputDecoration(
                labelText: "Title",
                border: InputBorder.none,
                hintText: 'Enter Title'),
            onChanged: (s) => changeTitle(s),
            maxLines: 1));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    items.add(_title());

    for (var i = 0; i < store.note.sections.length; i++) {
      if (!dismissables.containsKey(store.note.sections[i]))
        dismissables[store.note.sections[i]] = GlobalKey();

      bool showMoveUp = (i != 0);
      bool showMoveDown = (i != (store.note.sections.length - 1));
      items.add(_sectionListItem(store.note.sections[i], showMoveDown,
          showMoveUp, dismissables[store.note.sections[i]]));
    }

    items.add(_addSectionItem());

    items.add(_additionalInfoItem());

    if (store.note.audioFiles.length > 0)
      items.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));
    for (AudioFile f in store.note.audioFiles) {
      items.add(_audioFileView(f));
    }

    List<Widget> stackChildren = [];

    stackChildren.add(Container(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) => items[index],
          itemCount: items.length,
        )));

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

    return Scaffold(
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
        bottomSheet: RecorderBottomSheet(),
        body: Stack(children: stackChildren));
  }
}
