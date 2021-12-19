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
import 'package:sound/model.dart';
import 'package:sound/recorder_bottom_sheet.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/share.dart';
import 'package:sound/utils.dart';

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

  @override
  void initState() {
    super.initState();
    store = listenToStore(audioListToken);
    recorderStore = listenToStore(recorderBottomSheetStoreToken);

    recordingFinished.clearListeners();
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

    audioRecordingPermissionDenied.listen((_) {
      showHasNoPermissionsDialog(context);
    });
  }

  @override
  void dispose() {
    recordingFinished.clearListeners();
    audioRecordingPermissionDenied.clearListeners();
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
      //Navigator.of(context).pop();
    }, f);
  }

  _onShare(AudioFile f) {
    shareFile(f.path);
  }

  _onToggleStarred(AudioFile f) {
    toggleStarredAudioIdea(f);
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
            onMove: () => _onMove(f),
            onShare: () => _onShare(f)));
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
      print("notes are starred");
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
      leading:
          IconButton(icon: Icon(Icons.menu), onPressed: widget.onMenuPressed),
      title: Center(
          child: Align(child: Text("Ideas"), alignment: Alignment.centerLeft)),
      floating: false,
      pinned: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
        child: Scaffold(
            key: _globalKey,
            bottomSheet: showRecordingButton()
                ? null
                : RecorderBottomSheet(
                    key: Key("idea-bottom-sheet"), showTitle: true),
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
                  return _silver(snap.data);
                })));
    // body: Container(
    //     padding: EdgeInsets.all(8),
    //     child: FutureBuilder<List<AudioFile>>(
    //         initialData: [],
    //         future: LocalStorage().getAudioIdeas(),
    //         builder: (context, AsyncSnapshot<List<AudioFile>> snap) {
    //           return ListView.builder(
    //               itemCount: snap.data.length,
    //               itemBuilder: (context, index) {
    //                 AudioFile f = snap.data[index];

    //                 return AudioFileView(
    //                     index: index,
    //                     globalKey: _globalKey,
    //                     file: snap.data[index],
    //                     onDelete: () => _onDelete(f),
    //                     onDuplicate: null,
    //                     onToggleStarred: () => _onToggleStarred(f),
    //                     onMove: () => _onMove(f),
    //                     onShare: () => _onShare(f));
    //               });
    //         })),
    // ));
  }
}

/* 

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
*/
