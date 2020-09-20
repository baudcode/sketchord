import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sound/editor_views/section.dart';
import 'package:sound/model.dart';

class NoteViewer extends StatefulWidget {
  final Note note;
  NoteViewer({this.note, Key key}) : super(key: key);

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
  }

  @override
  void dispose() {
    // TODO: implement dispose
    setState(() {
      isPlaying = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    for (Section section in widget.note.sections) {
      items
          .add(SectionView(section: section, textScaleFactor: textScaleFactor));
    }

    List<Widget> playingActions = [
      IconButton(
          icon: Icon(Icons.stop),
          onPressed: () {
            setState(() {
              isPlaying = false;
            });
          }),
      IconButton(
          icon: Icon(Icons.fast_rewind),
          onPressed: () {
            setState(() {
              offset = 0.85 * offset;
            });
          }),
      IconButton(
          icon: Icon(Icons.fast_forward),
          onPressed: () {
            setState(() {
              offset = 1.15 * offset;
            });
          }),
    ];

    List<Widget> actions = [
      IconButton(
          icon: Icon(Icons.play_arrow),
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
          icon: Icon(Icons.zoom_in),
          onPressed: () {
            setState(() {
              textScaleFactor *= 1.05;
            });
          }),
      IconButton(
          icon: Icon(Icons.zoom_out),
          onPressed: () {
            setState(() {
              textScaleFactor *= 0.95;
            });
          })
    ];

    Widget overlay = Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).accentColor.withAlpha(100),
              blurRadius: 10.0,
            ),
          ],
          //border: Border.all(width: 1, color: Theme.of(context).accentColor)),
        ),
        child: Row(
          children: (isPlaying) ? playingActions : actions,
        ));

    return Scaffold(
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
          child: Container(child: overlay),
          top: 32,
          right: 8,
        ),
      ]),
    ));
  }
}
