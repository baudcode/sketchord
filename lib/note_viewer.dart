import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/editor_views/additional_info.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/editor_views/section.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_bottom_sheet.dart';
import 'package:sound/recorder_store.dart';

class NoteCollectionViewer extends StatelessWidget {
  final NoteCollection collection;

  NoteCollectionViewer(this.collection, {Key key});

  @override
  Widget build(BuildContext context) {
    return NotesViewer(
        collection.notes.where((note) => !note.discarded).toList(),
        showAdditionalInformation: false,
        showTitle: true,
        showZoomPlayback: true,
        showAudioFiles: false);
  }
}

class NoteViewerContent extends StatelessWidget {
  final Note note;
  final bool showTitle,
      showAdditionalInformation,
      showAudioFiles,
      showSheet,
      sheetMinimized;
  final double textScaleFactor;
  final ScrollController controller;

  const NoteViewerContent(this.note, this.sheetMinimized,
      {this.controller,
      this.textScaleFactor = 1.0,
      this.showAdditionalInformation = true,
      this.showTitle = true,
      this.showAudioFiles = false,
      this.showSheet = false,
      Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    if (showTitle) {
      items.add(NoteEditorTitle(
        title: note.title,
        allowEdit: false,
        onChange: (_) {},
      ));
    }

    for (Section section in note.sections) {
      items.add(SectionView(
          section: section,
          textScaleFactor: textScaleFactor,
          richChords: true));
    }

    if (showAdditionalInformation) {
      items.add(NoteEditorAdditionalInfo(
        note,
        allowEdit: false,
      ));
    }

    if (showAudioFiles) {
      items.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));

      items.addAll(note.audioFiles.map<Widget>((e) {
        return AudioFileListItem(e, onPressed: () {
          playInDialog(context, e);
        });
      }));
    }

    if (showSheet) {
      items.add(Container(height: sheetMinimized ? 70 : 300));
    }

    return Container(
      child: Stack(children: [
        Container(
            padding: EdgeInsets.all(16),
            child: ListView.builder(
              controller: controller,
              itemBuilder: (context, index) => items[index],
              itemCount: items.length,
            )),
      ]),
    );
  }
}

class NoteViewer extends StatelessWidget {
  final Note note;
  final List<Widget> actions;
  final bool showAudioFiles,
      showAdditionalInformation,
      showTitle,
      showZoomPlayback,
      showSheet;

  NoteViewer(this.note,
      {this.actions,
      this.showZoomPlayback = true,
      this.showAudioFiles = true,
      this.showTitle = true,
      this.showSheet = false,
      this.showAdditionalInformation = true,
      Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotesViewer(
      [this.note],
      actions: actions,
      showZoomPlayback: showZoomPlayback,
      showTitle: showTitle,
      showSheet: showSheet,
      showAdditionalInformation: showAdditionalInformation,
    );
  }
}

class NotesViewer extends StatefulWidget {
  final List<Note> notes;
  final List<Widget> actions;

  final bool showAudioFiles,
      showAdditionalInformation,
      showTitle,
      showZoomPlayback,
      showSheet;

  NotesViewer(this.notes,
      {this.actions,
      this.showZoomPlayback = true,
      this.showAudioFiles = false,
      this.showTitle = true,
      this.showSheet = false,
      this.showAdditionalInformation = true,
      Key key})
      : super(key: key);

  @override
  _NoteViewerState createState() => _NoteViewerState();
}

class _NoteViewerState extends State<NotesViewer>
    with StoreWatcherMixin<NotesViewer>, TickerProviderStateMixin {
  ScrollController _scollController;
  AnimationController _animationController;

  Animation<double> _sizeController;

  double textScaleFactor = 1.0;
  bool isPlaying = false;
  double offset = 1.0;
  RecorderBottomSheetStore recorderStore;
  int page = 0;
  PageController pageController;

  Note get note => widget.notes[page];

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: page);
    _scollController = ScrollController(debugLabel: "contentController");

    _animationController = AnimationController(
        value: 1.0, vsync: this, duration: Duration(milliseconds: 500));

    _sizeController =
        Tween<double>(begin: 0.8, end: 1.0).animate(_animationController);

    recorderStore = listenToStore(recorderBottomSheetStoreToken);
    print("note viewer minimize state: ${recorderStore.minimized}");

    textScaleFactor = note.zoom;
    offset = note.scrollOffset == null ? 1.0 : note.scrollOffset;
  }

  @override
  void dispose() {
    _animationController.dispose();
    // setState(() {
    //   isPlaying = false;
    // });
    super.dispose();
  }

  _updateZoom() async {
    note.zoom = textScaleFactor;
    await LocalStorage().syncNoteAttr(note, "zoom");
  }

  _updateScrollOffset() async {
    note.scrollOffset = offset;
    await LocalStorage().syncNoteAttr(note, "scrollOffset");
  }

  _getNoteViewerContent(Note note) {
    return NoteViewerContent(
      note,
      recorderStore.minimized,
      controller: _scollController,
      textScaleFactor: textScaleFactor,
      showAdditionalInformation: widget.showAdditionalInformation,
      showAudioFiles: widget.showAudioFiles,
      showSheet: widget.showSheet,
      showTitle: widget.showTitle,
    );
  }

  _onPageChange(_page) {
    print("onPageChange $_page");
    _animationController.reverse();

    setState(() {
      offset = widget.notes[_page].scrollOffset;
      textScaleFactor = widget.notes[_page].zoom;
      page = _page;
    });
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> playingActions = [
      IconButton(
          icon: Icon(Icons.stop),
          onPressed: () {
            setState(() {
              isPlaying = false;
            });
          }),
      Container(width: 48, height: 48),
      IconButton(
          icon: Icon(Icons.fast_rewind),
          onPressed: () {
            setState(() {
              offset = 0.9 * offset;
            });
            _updateScrollOffset();
          }),
      IconButton(
          icon: Icon(Icons.fast_forward),
          onPressed: () {
            setState(() {
              offset = 1.1 * offset;
            });
            _updateScrollOffset();
          }),
    ];

    List<Widget> actions = [];

    if (widget.showZoomPlayback && !isPlaying) {
      actions.addAll([
        IconButton(
            icon: Icon(Icons.play_arrow),
            color: Theme.of(context).appBarTheme.textTheme.button.color,
            onPressed: () {
              if (!isPlaying) {
                setState(() {
                  isPlaying = true;
                });
                Future.microtask(() async {
                  bool atEdge = false;
                  while (!atEdge && isPlaying) {
                    try {
                      await _scollController.animateTo(
                          _scollController.offset + offset,
                          duration: Duration(milliseconds: 50),
                          curve: Curves.ease);
                      atEdge = _scollController.position.atEdge;
                    } catch (e) {}
                  }
                  setState(() {
                    isPlaying = false;
                  });
                });
              }
            }),
        IconButton(
            color: Theme.of(context).appBarTheme.textTheme.button.color,
            icon: Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                textScaleFactor *= 1.05;
              });
              _updateZoom();
            }),
        IconButton(
            color: Theme.of(context).appBarTheme.textTheme.button.color,
            icon: Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                textScaleFactor *= 0.95;
              });
              _updateZoom();
            }),
        IconButton(
          color: Theme.of(context).appBarTheme.textTheme.button.color,
          icon: Icon(Icons.settings_backup_restore_outlined),
          onPressed: () {
            setState(() {
              textScaleFactor = 1.0;
              offset = 1.0;
            });
            _updateZoom();
            _updateScrollOffset();
          },
        )
      ]);
    } else if (isPlaying) {
      actions.addAll(playingActions);
    }
    // Widget overlay = Container(
    //     decoration: BoxDecoration(
    //       shape: BoxShape.rectangle,

    //       //border: Border.all(width: 1, color: Theme.of(context).accentColor)),
    //     ),
    //     child: Row(
    //       children: (isPlaying) ? playingActions : actions,
    //     ));

    // add audio files

    if (widget.actions != null) {
      actions.addAll(widget.actions);
    }

    Widget body, indicator;

    if (widget.notes.length > 1) {
      body = Container(
          child: PageView(
              controller: pageController,
              onPageChanged: _onPageChange,
              physics: (isPlaying) ? NeverScrollableScrollPhysics() : null,
              children: widget.notes
                  .map<Widget>((Note n) => _getNoteViewerContent(n))
                  .toList()));

      double prefferedHeight = 24;
      double noteIndicatorHeight = prefferedHeight - 8;
      double noteIndicatorPadding = 4;
      double noteIndicatorOffsetRight = 80;

      double noteIndicatorWidth = (MediaQuery.of(context).size.width -
              noteIndicatorPadding * widget.notes.length -
              noteIndicatorOffsetRight) /
          widget.notes.length;
      Color indicatorColor = Theme.of(context).scaffoldBackgroundColor;
      Color highlightColor = Theme.of(context).accentColor;

      _buildIndicator(int index) {
        return GestureDetector(
          onTap: () {
            if (!isPlaying) {
              pageController.jumpToPage(index);
            }
          },
          child: Container(
            decoration: BoxDecoration(
                color: (index == page) ? highlightColor : indicatorColor,
                borderRadius: BorderRadius.circular(5)),
            padding: null,
            width: noteIndicatorWidth,
            height: noteIndicatorHeight,
          ),
        );
      }

      indicator = PreferredSize(
        preferredSize: Size.fromHeight(prefferedHeight),
        child: Container(
          child: Row(
            children: widget.notes
                .asMap()
                .map<int, Widget>(
                  (int index, Note _note) => MapEntry(
                      index,
                      Padding(
                        padding: EdgeInsets.only(
                          left: noteIndicatorPadding,
                          bottom: noteIndicatorPadding,
                        ),
                        child: Transform.scale(
                          scale: (index == page) ? _sizeController.value : 0.8,
                          child: _buildIndicator(index),
                        ),
                      )),
                )
                .values
                .toList()
                  ..add(Expanded(
                      child: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 8, bottom: 8),
                          child: Text("${page + 1}/${widget.notes.length}",
                              style: Theme.of(context)
                                  .appBarTheme
                                  .textTheme
                                  .button)))),
          ),
        ),
      );
    } else {
      body = _getNoteViewerContent(note);
    }

    return Scaffold(
        appBar: AppBar(actions: actions, bottom: indicator),
        bottomSheet: widget.showSheet
            ? RecorderBottomSheet(key: Key("bottomSheetViewer"))
            : null,
        body: body);
  }
}
