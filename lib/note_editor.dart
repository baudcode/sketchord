import 'package:audioplayers/audioplayers.dart';
import 'package:clipboard_manager/clipboard_manager.dart';
import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart' show StoreWatcherMixin;
import 'package:sound/dialogs/add_to_collection_dialog.dart';
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

class NoteEditor extends StatelessWidget {
  final Note note;
  final EditorView view;

  NoteEditor(this.note, {this.view});

  @override
  Widget build(BuildContext context) {
    if (view != null) return NoteEditorContent(note, view);

    return FutureBuilder(
        builder: (BuildContext context, AsyncSnapshot<Settings> snap) {
          if (snap.hasData) {
            EditorView v =
                (snap.data == null) ? EditorView.tabs : snap.data.editorView;
            return NoteEditorContent(note, v);
          } else {
            return CircularProgressIndicator();
          }
        },
        future: LocalStorage().getSettings());
  }
}

class NoteEditorContent extends StatefulWidget {
  final Note note;
  final EditorView view;

  NoteEditorContent(this.note, this.view);

  @override
  State<StatefulWidget> createState() {
    return NoteEditorState();
  }
}

enum TabType { structure, info, audio }

class NoteEditorState extends State<NoteEditorContent>
    with StoreWatcherMixin<NoteEditorContent>, WidgetsBindingObserver {
  RecorderBottomSheetStore recorderStore;
  NoteEditorStore store;
  GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  List<String> popupMenuActions = ["share", "copy", "add"];
  List<String> popupMenuActionsLong = ["Share", "Copy", "Add To Set"];
  bool get useTabs => widget.view == EditorView.tabs;
  final Key bottomSheetKey = Key('bottomSheet');
  Map<Section, GlobalKey> dismissables = {};
  AdditionalInfoItem focusedAdditionalInfoItem;
  List<String> additionalItemSuggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    recordingFinished.clearListeners();
    //store.dispose();
    //recorderStore.dispose();
    super.dispose();
  }

  _onFloatingActionButtonPress() {
    if (recorderStore.state == RecorderState.RECORDING) {
      stopAction(true);
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
          print("hardly deleting audio file now");
          hardDeleteAudioFile(file);
        }
      },
      mainButton: TextButton(
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
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
      case "add":
        showAddToCollectionDialog(context, store.note);
        break;
      default:
        break;
    }
  }

  _buildTabView(List<Widget> items) {
    return Container(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) => items[index],
          itemCount: items.length,
        ));
  }

  _onAdditionalInfoValueChange(AdditionalInfoItem item, String value) {
    _onAdditionalInfoFocusChange(item);
    _onSuggestionTap(value);
  }

  _onAdditionalInfoFocusChange(AdditionalInfoItem item) async {
    var suggestions = await _getInfoSuggestions(item);
    setState(() {
      additionalItemSuggestions = suggestions;
      focusedAdditionalInfoItem = item;
    });
  }

  Future<List<String>> _getInfoSuggestions(AdditionalInfoItem item) async {
    if (item == null) return [];

    Iterable<Note> notes = (await LocalStorage().getActiveNotes())
        .where((element) => element.id != store.note.id);

    String search = getAddtionalInfoItemFromNote(store.note, item);

    if (search != null) search = search.toLowerCase();

    switch (item) {
      case AdditionalInfoItem.key:
        return itemsByFrequency(notes
            .map((note) => note.key)
            .where((element) =>
                element != null &&
                element.trim().length != 0 &&
                (search == null || element.toLowerCase().contains(search)))
            .toList());
      case AdditionalInfoItem.tuning:
        return itemsByFrequency(notes
            .map((note) => note.tuning)
            .where((element) =>
                element != null &&
                element.trim().length != 0 &&
                (search == null || element.toLowerCase().contains(search)))
            .toList());
      case AdditionalInfoItem.capo:
        return itemsByFrequency(notes
            .map((note) => note.capo)
            .where((element) =>
                element != null &&
                element.trim().length != 0 &&
                (search == null || element.toLowerCase().contains(search)))
            .toList());
      case AdditionalInfoItem.label:
        return itemsByFrequency(notes
            .map((note) => note.label)
            .where((element) =>
                element != null &&
                element.trim().length != 0 &&
                (search == null || element.toLowerCase().contains(search)))
            .toList());
      case AdditionalInfoItem.artist:
        return itemsByFrequency(notes
            .map((note) => note.artist)
            .where((element) =>
                element != null &&
                element.trim().length != 0 &&
                (search == null || element.toLowerCase().contains(search)))
            .toList());
      default:
        return [];
    }
  }

  _onSuggestionTap(String text) {
    switch (focusedAdditionalInfoItem) {
      case AdditionalInfoItem.key:
        changeKey(text);
        break;
      case AdditionalInfoItem.tuning:
        changeTuning(text);
        break;
      case AdditionalInfoItem.capo:
        changeCapo(text);
        break;
      case AdditionalInfoItem.label:
        changeLabel(text);
        break;
      case AdditionalInfoItem.artist:
        changeArtist(text);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // map widgets to tabs
    Map<TabType, List<Widget>> items = {};

    items[TabType.audio] = [];
    items[TabType.structure] = [];
    items[TabType.info] = [];

    items[TabType.structure].add(NoteEditorTitle(
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

      items[TabType.structure].add(SectionListItem(
          globalKey: dismissables[store.note.sections[i]],
          section: store.note.sections[i],
          moveDown: showMoveDown,
          moveUp: showMoveUp));
    }
    // add section item
    items[TabType.structure].add(AddSectionItem());

    // all additional info
    items[TabType.info].add(NoteEditorAdditionalInfo(store.note,
        onChange: (data) =>
            _onAdditionalInfoValueChange(data.item1, data.item2),
        onFocusChange: _onAdditionalInfoFocusChange));

    // audio files as stack
    if (store.note.audioFiles.length > 0 && !useTabs)
      items[TabType.audio].add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));

    store.note.audioFiles.asMap().forEach((int index, AudioFile f) {
      items[TabType.audio].add(AudioFileView(
          file: f,
          index: index,
          onDuplicate: () async {
            AudioFile copy = await FileManager().copyToNew(f);
            addAudioFile(copy);
          },
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
                ignoreNoteId: store.note.id,
                newButtonText: "Copy as NEW");
          },
          onShare: () => shareFile(f.path),
          globalKey: _globalKey));
    });

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
          int index = popupMenuActions.indexOf(action);

          return PopupMenuItem(
              value: action, child: Text(popupMenuActionsLong[index]));
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

    List<String> categories = ["Structure", "Info", "Audio"];

    List<Widget> stackChildren = [];

    // add container to prevent from seeing all content
    if (showSheet && useTabs) {
      TabType.values.forEach((tt) {
        items[tt].add(Container(height: recorderStore.minimized ? 70 : 300));
      });
    }

    if (!useTabs) {
      if (showSheet) {
        items[TabType.audio]
            .add(Container(height: recorderStore.minimized ? 70 : 300));
      }

      stackChildren.add(_buildTabView(items[TabType.structure]
        ..addAll(items[TabType.info])
        ..addAll(items[TabType.audio])));
    }

    final keyboardOpen = WidgetsBinding.instance.window.viewInsets.bottom > 0;

    Widget suggestionSheet = PreferredSize(
        preferredSize: Size.fromHeight(20),
        child: Container(
          padding: EdgeInsets.only(left: 8),
          child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              children: additionalItemSuggestions
                  .map((o) => GestureDetector(
                      onTap: () => _onSuggestionTap(o),
                      child: Chip(label: Text(o))))
                  .toList()),
        ));

    Scaffold scaffold = Scaffold(
        key: _globalKey,
        appBar: AppBar(
          //backgroundColor: store.note.color,
          actions: actions,
          bottom: useTabs
              ? new TabBar(
                  isScrollable: true,
                  tabs: List<Widget>.generate(categories.length, (int index) {
                    return new Tab(text: categories[index]);
                  }))
              : null,
        ),
        bottomSheet: showSheet
            ? RecorderBottomSheet(key: bottomSheetKey)
            : (keyboardOpen && focusedAdditionalInfoItem != null)
                ? suggestionSheet
                : null,
        body: useTabs
            ? TabBarView(
                children: List<Widget>.generate(categories.length, (int index) {
                if (index == 0) {
                  return _buildTabView(items[TabType.structure]);
                } else if (index == 1) {
                  return _buildTabView(items[TabType.info]);
                } else {
                  return _buildTabView(items[TabType.audio]);
                }
              }))
            : Container(child: Stack(children: stackChildren)));

    // will pop score
    return WillPopScope(
        onWillPop: () async {
          stopAction(true);
          return true;
        },
        child: DefaultTabController(length: 3, child: scaffold));
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
