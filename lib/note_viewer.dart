import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sound/editor_views/additional_info.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/editor_views/section.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

class NoteViewer extends StatefulWidget {
  final Note note;
  final List<Widget> actions;
  final bool showAudioFiles,
      showAdditionalInformation,
      showTitle,
      showZoomPlayback;

  NoteViewer(this.note,
      {this.actions,
      this.showZoomPlayback = true,
      this.showAudioFiles = true,
      this.showTitle = true,
      this.showAdditionalInformation = true,
      Key key})
      : super(key: key);

  @override
  _NoteViewerState createState() => _NoteViewerState();
}

class _NoteViewerState extends State<NoteViewer> {
  ScrollController _controller;
  bool showButtons = true;
  double textScaleFactor = 1.0;
  bool isPlaying = false;
  double offset = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()
      ..addListener(() {
        bool upDirection =
            _controller.position.userScrollDirection == ScrollDirection.forward;
      });

    textScaleFactor = widget.note.zoom;
    offset = widget.note.scrollOffset;
  }

  @override
  void dispose() {
    setState(() {
      isPlaying = false;
    });
    super.dispose();
  }

  _updateZoom() async {
    Note note = widget.note;
    note.zoom = textScaleFactor;
    await LocalStorage().syncNoteAttr(note, "zoom");
  }

  _updateScrollOffset() async {
    Note note = widget.note;
    note.scrollOffset = offset;
    await LocalStorage().syncNoteAttr(note, "scrollOffset");
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    if (widget.showTitle) {
      items.add(NoteEditorTitle(widget.note.title, allowEdit: false));
    }

    for (Section section in widget.note.sections) {
      items
          .add(SectionView(section: section, textScaleFactor: textScaleFactor));
    }

    List<Widget> playingActions = [
      IconButton(
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.stop),
          onPressed: () {
            setState(() {
              isPlaying = false;
            });
          }),
      IconButton(
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.fast_rewind),
          onPressed: () {
            setState(() {
              offset = 0.85 * offset;
            });
            _updateScrollOffset();
          }),
      IconButton(
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.fast_forward),
          onPressed: () {
            setState(() {
              offset = 1.15 * offset;
            });
            _updateScrollOffset();
          }),
    ];

    List<Widget> actions = [
      IconButton(
          icon: Icon(Icons.play_arrow),
          color: Theme.of(context).accentColor,
          onPressed: () {
            if (!isPlaying) {
              setState(() {
                isPlaying = true;
              });
              Future.microtask(() async {
                bool atEdge = false;
                while (!atEdge && isPlaying) {
                  await _controller.animateTo(_controller.offset + offset,
                      duration: Duration(milliseconds: 50), curve: Curves.ease);
                  atEdge = _controller.position.atEdge;
                }
                setState(() {
                  isPlaying = false;
                });
              });
            }
          }),
      IconButton(
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.zoom_in),
          onPressed: () {
            setState(() {
              textScaleFactor *= 1.05;
            });
            _updateZoom();
          }),
      IconButton(
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.zoom_out),
          onPressed: () {
            setState(() {
              textScaleFactor *= 0.95;
            });
            _updateZoom();
          })
    ];

    Widget overlay = Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,

          //border: Border.all(width: 1, color: Theme.of(context).accentColor)),
        ),
        child: Row(
          children: (isPlaying) ? playingActions : actions,
        ));

    if (widget.showAdditionalInformation) {
      items.add(NoteEditorAdditionalInfo(
        widget.note,
        allowEdit: false,
      ));
    }

    // add audio files
    if (widget.showAudioFiles) {
      items.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Audio Files',
            style: Theme.of(context).textTheme.subtitle1,
          )));

      items.addAll(widget.note.audioFiles.map<Widget>((e) {
        return AudioFileListItem(e, onPressed: () {
          playInDialog(context, e);
        });
      }));
    }

    return Scaffold(
        appBar: widget.actions == null
            ? null
            : AppBar(
                actions: widget.actions,
              ),
        body: Container(
          //color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(children: [
            Container(
                padding: EdgeInsets.all(16),
                child: ListView.builder(
                  controller: _controller,
                  itemBuilder: (context, index) => items[index],
                  itemCount: items.length,
                )),
            Positioned(
              child: widget.showZoomPlayback ? overlay : Container(),
              top: 32,
              right: 8,
            ),
          ]),
        ));
  }
}
