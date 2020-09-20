import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_list.dart';
import 'package:sound/note_viewer.dart';
import 'package:sound/storage.dart';

class Trash extends StatefulWidget {
  final Function onMenuPressed;

  Trash(this.onMenuPressed, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TrashState();
  }
}

class _TrashState extends State<Trash> {
  final GlobalKey _globalKey = GlobalKey();

  List<Note> selectedNotes = [];

  bool isSelected(Note note) => selectedNotes.contains(note);
  bool get isAnyNoteSelected => selectedNotes.length > 0;

  List<Note> notes = [];

  List<String> popupMenuActions = ["delete"];
  List<String> longPopupMenuNames = ["Delete irrevocably"];

  @override
  void initState() {
    super.initState();

    LocalStorage().getDiscardedNotes().then((value) => setState(() {
          notes = value;
        }));
  }

  _clearSelection() {
    setState(() {
      selectedNotes.clear();
    });
  }

  _restoreSelectedNotes() {
    restoreNotes(selectedNotes);
    setState(() {
      notes.removeWhere((n) => isSelected(n));
      selectedNotes = [];
    });
  }

  _runPopupAction(String action) {
    print("action: $action");
    if (action == "delete") {
      for (Note note in selectedNotes) {
        LocalStorage().deleteNote(note);
      }
      setState(() {
        notes.removeWhere((n) => isSelected(n));
      });
    } else if (action == 'delete_all') {
      for (Note note in notes) {
        LocalStorage().deleteNote(note);
      }
      setState(() {
        notes = [];
      });
    }
  }

  _selectionAppBar() {
    return AppBar(
      leading: IconButton(icon: Icon(Icons.clear), onPressed: _clearSelection),
      title: Text(selectedNotes.length.toString()),
      actions: <Widget>[
        IconButton(icon: Icon(Icons.restore), onPressed: _restoreSelectedNotes),
        PopupMenuButton<String>(
          onSelected: _runPopupAction,
          itemBuilder: (context) {
            return popupMenuActions.map<PopupMenuItem<String>>((String action) {
              return PopupMenuItem(
                  value: action,
                  child: Text(
                      longPopupMenuNames[popupMenuActions.indexOf(action)]));
            }).toList();
          },
        )
      ],
    );
  }

  _appBar() {
    return AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: _runPopupAction,
            itemBuilder: (context) {
              return [
                PopupMenuItem(value: "delete_all", child: Text("Empty trash"))
              ];
            },
          )
        ],
        title: Text("Trash"),
        leading: IconButton(
            icon: Icon(Icons.menu), onPressed: widget.onMenuPressed));
  }

  _selectNote(Note note) {
    if (!isSelected(note)) {
      setState(() {
        selectedNotes.add(note);
      });
    } else {
      setState(() {
        selectedNotes.remove(note);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // items.add(_title());
    List<NoteListItemModel> items = notes
        .map((n) => NoteListItemModel(note: n, isSelected: isSelected(n)))
        .toList();

    _restore(Note note) {
      restoreNotes([note]);

      setState(() {
        notes.removeWhere((n) => n.id == note.id);
      });

      Navigator.of(context).pop();
    }

    _deleteForever(Note note) {
      LocalStorage().deleteNote(note);

      setState(() {
        notes.removeWhere((n) => n.id == note.id);
      });
      Navigator.of(context).pop();
    }

    onTap(Note note) {
      if (isAnyNoteSelected) {
        _selectNote(note);
      } else {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => NoteViewer(
                      note,
                      actions: [
                        IconButton(
                            icon: Icon(Icons.restore),
                            onPressed: () => _restore(note)),
                        IconButton(
                          icon: Icon(Icons.delete_forever),
                          onPressed: () => _deleteForever(note),
                        )
                      ],
                      showZoomPlayback: false,
                    )));
      }
    }

    onLongPress(Note note) {
      _selectNote(note);
    }

    return Scaffold(
        key: _globalKey,
        appBar: isAnyNoteSelected ? _selectionAppBar() : _appBar(),
        body: Container(
          child: NoteList(false, false, items, onTap, onLongPress),
        ));
  }
}
