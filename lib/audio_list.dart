import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/audio_list_store.dart';
import 'package:sound/dialogs/audio_action_dialog.dart';
import 'package:sound/dialogs/import_dialog.dart';
import 'package:sound/dialogs/permissions_dialog.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/file_manager.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/main.dart';
import 'package:sound/model.dart';
import 'package:sound/note_views/seach.dart';
import 'package:sound/recorder_bottom_sheet.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/share.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';

class AudioList extends StatefulWidget {
  final Function onMenuPressed;
  AudioList(this.onMenuPressed);

  @override
  State<StatefulWidget> createState() {
    return AudioListState();
  }
}

class AudioListState extends State<AudioList>
    with StoreWatcherMixin<AudioList> {
  GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  AudioListStore store;
  RecorderBottomSheetStore recorderStore;
  List<ActionSubscription> subs = [];
  TextEditingController _searchController;
  FocusNode searchFocusNode;

  @override
  void initState() {
    print("INIT STATE");

    super.initState();

    searchFocusNode = new FocusNode();
    store = listenToStore(audioListToken, handleStoreChange);
    recorderStore =
        listenToStore(recorderBottomSheetStoreToken, handleStoreChange);

    _searchController = TextEditingController.fromValue(TextEditingValue.empty);

    initListeners();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("CHANGE>>>>>>>");
  }

  void handleStoreChange(Store store) {
    recordingFinished.clearListeners();
    audioRecordingPermissionDenied.clearListeners();
    initListeners();
    setState(() {}); // TO NOT REMOVE!!!!
  }

  void initListeners() {
    // recordingFinished.clearListeners();
    recordingFinished.listen((f) async {
      print("recording finished ${f.path} with duration ${f.duration}");

      final player = AudioPlayer();
      await player.setUrl(f.path);

      return Future.delayed(
        const Duration(milliseconds: 200),
        () async {
          f.duration = Duration(milliseconds: await player.getDuration());
          addAudioIdea(f);
        },
      );
    });

    // audioRecordingPermissionDenied.clearListeners();
    audioRecordingPermissionDenied.listen((_) {
      showHasNoPermissionsDialog(context);
    });

    toggleAudioIdeasSearch.listen((_) {
      if (store.isSearching) {
        Future.delayed(Duration(milliseconds: 100), () {
          print("REQUESTING FOCUS");
          FocusScope.of(context).requestFocus(searchFocusNode);
        });
      }
    });
  }

  @override
  void dispose() {
    print("DISPOSE");
    recordingFinished.clearListeners();
    audioRecordingPermissionDenied.clearListeners();
    // recorderStore.dispose();
    // store.dispose();

    // for (var sub in subs) {
    //   sub.cancel();
    // }
    //store.dispose();
    //recorderStore.dispose();
    super.dispose();
  }

  _onMenu() {
    if (recorderStore.state == RecorderState.RECORDING) {
      showSnackByContext(_globalKey.currentContext,
          "You cannot open the menu while you are still recording",
          backgroundColor: Theme.of(_globalKey.currentContext).errorColor);
      return;
    } else {
      stopAction();
    }

    widget.onMenuPressed();
  }

  showRecordingButton() {
    return (recorderStore.state == RecorderState.RECORDING) ||
        (recorderStore.state == RecorderState.STOP);
  }

  _onDelete(AudioFile f) {
    deleteAudioIdea(f);
  }

  _onMove(AudioFile f) {
    showMoveToNoteDialog(context, () {
      Navigator.of(context).pop();
    }, f);
  }

  _onShare(AudioFile f) {
    shareFile(f.path);
  }

  _onToggleStarred(AudioFile f) {
    toggleStarredAudioIdea(f);
  }

  _onRename(AudioFile f, String name) {
    renameAudioIdea(Tuple2(f, name));
  }

  _makeAudioFile(AudioFile f) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: AudioFileView(
            index: -1,
            globalKey: _globalKey,
            file: f,
            onDelete: () => _onDelete(f),
            onDuplicate: null,
            onToggleStarred: () => _onToggleStarred(f),
            onRename: (name) => _onRename(f, name),
            onMove: () => _onMove(f),
            onShare: () => _onShare(f)));
  }

  _searchView() {
    return SearchTextView(
        toggleIsSearching: ({searching}) {
          if (!store.isSearching) {
            toggleAudioIdeasSearch();
          }
        },
        onChanged: (s) {
          setSearchAudioIdeas(s);
          setState(() {});
        },
        text: (store.isSearching) ? "Search..." : "Idea",
        focusNode: searchFocusNode,
        enabled: store.isSearching,
        controller: _searchController);
  }

  _makeAudioFileViewList(List<AudioFile> files) {
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      return _makeAudioFile(files[index]);
    }, childCount: files.length));
  }

  _silver(List<AudioFile> files) {
    bool isAnyAudioFileStarred() {
      return files.any((element) => element.starred);
    }

    List<Widget> noteList = [];

    if (isAnyAudioFileStarred()) {
      List<AudioFile> items = files.where((n) => !n.starred).toList();
      List<AudioFile> starrtedItems = files.where((n) => n.starred).toList();

      noteList = [
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16, top: 16),
              child: Row(children: [
                Text("Starred", style: Theme.of(context).textTheme.caption),
                Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 0),
                    child: Icon(Icons.star, size: 16))
              ]))
        ])),
        _makeAudioFileViewList(starrtedItems),
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text("Other", style: Theme.of(context).textTheme.caption))
        ])),
        _makeAudioFileViewList(items),
      ];
    } else {
      noteList = [
        _makeAudioFileViewList(files),
      ];
    }

    SliverAppBar appBar = _sliverAppBar();

    return CustomScrollView(
      slivers: [appBar]..addAll(noteList),
    );
  }

  _sliverAppBar() {
    return SliverAppBar(
      titleSpacing: 5.0,
      title: Padding(
          child: Center(child: _searchView()),
          padding: EdgeInsets.only(left: 5)),
      leading: IconButton(
          icon: store.isSearching ? Icon(Icons.clear) : Icon(Icons.menu),
          onPressed: store.isSearching
              ? () {
                  setSearchAudioIdeas("");
                  toggleAudioIdeasSearch();
                }
              : _onMenu),
      actions: store.isSearching
          ? []
          : [
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  toggleAudioIdeasSearch();
                },
              )
            ],
      floating: false,
      pinned: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print("WILL POP");
        return true;
      },
      child: ScaffoldMessenger(
          child: Scaffold(
              key: _globalKey,
              bottomSheet: showRecordingButton()
                  ? null
                  : RecorderBottomSheet(
                      key: Key("idea-bottom-sheet"),
                      showTitle: true,
                      showRepeat: true,
                    ),
              floatingActionButton: showRecordingButton()
                  ? FloatingActionButton(
                      child: (recorderStore.state == RecorderState.RECORDING)
                          ? Icon(Icons.stop)
                          : Icon(Icons.mic),
                      backgroundColor:
                          (recorderStore.state == RecorderState.RECORDING)
                              ? Theme.of(context).accentColor
                              : null,
                      onPressed: () {
                        if (recorderStore.state == RecorderState.STOP) {
                          startRecordingAction();
                        } else if (recorderStore.state ==
                            RecorderState.RECORDING) {
                          stopAction();
                        }
                      })
                  : null,
              body: FutureBuilder<List<AudioFile>>(
                  initialData: [],
                  future: LocalStorage().getAudioIdeas(),
                  builder: (context, AsyncSnapshot<List<AudioFile>> snap) {
                    List<AudioFile> files = snap.data;

                    if (store.isSearching && store.search.trim() != "") {
                      var search = store.search.toLowerCase();
                      files = files
                          .where((element) => jsonEncode(element.toJson())
                              .toLowerCase()
                              .contains(search))
                          .toList();
                    }
                    setQueue(files);

                    print("RERENDER");
                    return _silver(files);
                  }))),
    );
  }
}
