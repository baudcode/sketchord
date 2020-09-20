import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';

typedef FutureNoteCallback = Future<Note> Function();
typedef FutureNoteImportCallback = Future<Note> Function(Note);

showImportDialog(BuildContext context, String title, FutureNoteCallback onNew,
    FutureNoteImportCallback onImport,
    {String newButtonText = 'Import as NEW',
    String importButtonText = "Import",
    bool openNote = true,
    bool syncNote = true}) async {
  List<Note> notes = await LocalStorage().getActiveNotes();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      Note selected;

      _open(Note note) {
        if (openNote) {
          Navigator.push(context,
              new MaterialPageRoute(builder: (context) => NoteEditor(note)));
        }
      }

      _import() async {
        // sync and pop current dialog
        Note note = await onImport(selected);
        if (syncNote) {
          LocalStorage().syncNote(note);
        }
        Navigator.of(context).pop();
        _open(note);
      }

      _onNew() async {
        Note newNote = await onNew();
        if (syncNote) {
          LocalStorage().syncNote(newNote);
        }

        Navigator.of(context).pop();
        _open(newNote);
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text(title),
          content: Builder(builder: (context) {
            double width = MediaQuery.of(context).size.width;
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                      child: RaisedButton(
                          child: Text(newButtonText), onPressed: _onNew)),
                  SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(child: Text("-- or select a note --"))
                  ]),
                  SizedBox(height: 15),
                  Row(mainAxisSize: MainAxisSize.max, children: [
                    new DropdownButton<Note>(
                        value: selected,
                        isDense: true,
                        items: notes
                            .map((e) => DropdownMenuItem<Note>(
                                child: SizedBox(
                                    width: width - 152,
                                    child: Text(
                                        "${notes.indexOf(e)}: ${e.title}",
                                        overflow: TextOverflow.ellipsis)),
                                value: e))
                            .toList(),
                        onChanged: (v) => setState(() => selected = v)),
                  ])
                ]);
          }),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text(importButtonText),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
