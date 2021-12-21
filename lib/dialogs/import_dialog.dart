import 'package:flutter/material.dart';
import 'package:sound/audio_list.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/menu_store.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';
import 'package:sound/note_search_view.dart';

typedef FutureNoteCallback = Future<Note> Function();
typedef FutureAudioIdeasImportCallback = Future<List<AudioFile>> Function();
typedef FutureNoteImportCallback = Future<Note> Function(Note);

enum ImportMode { asNew, search, idea }

showImportDialog(BuildContext context, String title, FutureNoteCallback onNew,
    FutureNoteImportCallback onImport,
    {String newButtonText = 'Import as NEW',
    String importButtonText = "Import",
    String ignoreNoteId,
    bool openNote = true,
    bool syncNote = true,
    FutureAudioIdeasImportCallback onImportAudioIdeas}) async {
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

      _importAsNew() async {
        Note newNote = await onNew();
        if (syncNote) {
          LocalStorage().syncNote(newNote);
        }

        Navigator.of(context).pop();
        _open(newNote);
      }

      _importSelected() async {
        // sync and pop current dialog
        Note note = await onImport(selected);
        if (syncNote) {
          LocalStorage().syncNote(note);
        }
        Navigator.of(context).pop();
        _open(note);
      }

      _importAsIdea() async {
        List<AudioFile> ideas = await onImportAudioIdeas();
        for (AudioFile f in ideas) {
          await LocalStorage().addAudioIdea(f);
        }
        setMenuItem(MenuItem.AUDIO);

        Navigator.pop(context);
      }

      _import() async {
        if (mode == ImportMode.asNew) {
          await _importAsNew();
        } else if (mode == ImportMode.search && selected != null) {
          print("import selected...");
          await _importSelected();
        } else if (mode == ImportMode.idea) {
          _importAsIdea();
        } else {
          print("cannot import");
        }
      }

      _onNew(setState) {
        setState(() {
          selected = null;
          mode = ImportMode.asNew;
        });
      }

      _onIdea(setState) {
        setState(() {
          selected = null;
          mode = ImportMode.idea;
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
                          Text("New Note", textScaleFactor: 0.7)
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
                      (onImportAudioIdeas != null)
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: Icon(
                                      Icons.lightbulb,
                                      size: 30,
                                      color: (mode == ImportMode.idea)
                                          ? Theme.of(context).accentColor
                                          : null,
                                    ),
                                    onPressed: () => _onIdea(setState)),
                                Text("As Ideas", textScaleFactor: 0.7)
                              ],
                            )
                          : Container(),
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
                child: new Text(importButtonText), onPressed: _import),
          ],
        );
      });
    },
  );
}
