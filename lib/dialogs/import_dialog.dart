import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';
import 'package:sound/note_search_view.dart';

typedef FutureNoteCallback = Future<Note> Function();
typedef FutureNoteImportCallback = Future<Note> Function(Note);

enum ImportMode { asNew, search }

showImportDialog(BuildContext context, String title, FutureNoteCallback onNew,
    FutureNoteImportCallback onImport,
    {String newButtonText = 'Import as NEW',
    String importButtonText = "Import",
    String ignoreNoteId,
    bool openNote = true,
    bool syncNote = true}) async {
  List<Note> notes = await LocalStorage().getActiveNotes();
  if (ignoreNoteId != null)
    notes = notes.where((element) => element.id != ignoreNoteId).toList();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      Note selected;
      ImportMode mode;

      _open(Note note) async {
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

      _importAsNew() async {
        Note newNote = await onNew();
        if (syncNote) {
          LocalStorage().syncNote(newNote);
        }

        Navigator.of(context).pop();
        _open(newNote);
      }

      _onNew(setState) {
        setState(() {
          selected = null;
          mode = ImportMode.asNew;
        });
      }

      _onSearch(setState) {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => NoteSearchViewLoader(
                      single: true,
                      collection: NoteCollection.empty(),
                      onAddNotes: (List<Note> notes) async {
                        setState(() {
                          selected = notes[0];
                          mode = ImportMode.search;
                        });
                      },
                    )));
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text(title),
          content: Builder(builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: Icon(
                                Icons.new_label,
                                size: 30,
                                color: (mode == ImportMode.asNew)
                                    ? Theme.of(context).accentColor
                                    : null,
                              ),
                              onPressed: () => _onNew(setState)),
                          Text("As New", textScaleFactor: 0.7)
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: Icon(
                                Icons.search,
                                size: 30,
                                color: (mode == ImportMode.search)
                                    ? Theme.of(context).accentColor
                                    : null,
                              ),
                              onPressed: () => _onSearch(setState)),
                          Text("Search", textScaleFactor: 0.7)
                        ],
                      ),
                    ]),
                (selected != null)
                    ? Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Text(selected.title.trim() == ""
                            ? EMPTY_TEXT
                            : selected.title))
                    : Container()
              ],
            );
          }),
          actions: <Widget>[
            new TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new ElevatedButton(
              child: new Text(importButtonText),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
