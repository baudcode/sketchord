import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';
import 'package:sound/note_list.dart';
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

  _selectionAppBar() {
    return AppBar(
      leading: IconButton(icon: Icon(Icons.clear), onPressed: _clearSelection),
      title: Text(selectedNotes.length.toString()),
      actions: <Widget>[
        IconButton(icon: Icon(Icons.restore), onPressed: _restoreSelectedNotes),
      ],
    );
  }

  _appBar() {
    return AppBar(
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

    onTap(Note note) {
      if (isAnyNoteSelected) {
        _selectNote(note);
      } else {
        // Navigator.push(context,
        //     new MaterialPageRoute(builder: (context) => NoteEditor(note)));
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
