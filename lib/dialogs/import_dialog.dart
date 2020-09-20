import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';

typedef FutureNoteCallback = Future<Note> Function();
typedef FutureNoteImportCallback = Future<void> Function(Note);

showImportDialog(BuildContext context, String title, FutureNoteCallback onNew,
    FutureNoteImportCallback onImport) async {
  List<Note> notes = await LocalStorage().getActiveNotes();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      Note selected;

      _open(Note note) {
        Navigator.push(context,
            new MaterialPageRoute(builder: (context) => NoteEditor(note)));
      }

      _import() async {
        // sync and pop current dialog
        await onImport(selected);
        Navigator.of(context).pop();
        _open(selected);
      }

      _onNew() async {
        Note newNote = await onNew();
        LocalStorage().syncNote(newNote);
        Navigator.of(context).pop();
        _open(newNote);
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text(title),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                    child: RaisedButton(
                        child: Text('Import as NEW'), onPressed: _onNew)),
                SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(child: Text("-- or select a note --"))
                ]),
                SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        child: Text("Note:"),
                        padding: EdgeInsets.only(right: 8, top: 8),
                      ),
                      new DropdownButton<Note>(
                          value: selected,
                          items: notes
                              .map((e) => DropdownMenuItem<Note>(
                                  child:
                                      Text("${notes.indexOf(e)}: ${e.title}"),
                                  value: e))
                              .toList(),
                          onChanged: (v) => setState(() => selected = v)),
                    ])
              ]),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Import"),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
