import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';

typedef FutureNoteCallback = Future<Note> Function();
typedef FutureNoteImportCallback = Future<Note> Function(Note);
typedef FutureAudioIdeaImportCallback = Future<void> Function();

showImportDialog(BuildContext context, String title, FutureNoteCallback onNew,
    FutureNoteImportCallback onImport,
    {String newButtonText = 'Import as NEW',
    String importButtonText = "Import",
    String importIdeasButtonText = 'Import as Idea',
    FutureAudioIdeaImportCallback? onImportAudioIdeas,
    bool openNote = true,
    bool syncNote = true}) async {
  List<Note> notes = await LocalStorage().getActiveNotes();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      Note? selected;

      _open(Note note) {
        if (openNote) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => NoteEditor(note)));
        }
      }

      _import() async {
        // sync and pop current dialog
        if (selected == null) return;
        Note note = await onImport(selected!);
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

      _onImportIdeas() async {
        if (onImportAudioIdeas == null) return;
        await onImportAudioIdeas();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(title),
          content: Builder(builder: (context) {
            double width = MediaQuery.of(context).size.width;
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                      child: ElevatedButton(
                          child: Text(newButtonText), onPressed: _onNew)),
                  if (onImportAudioIdeas != null) ...[
                    const SizedBox(height: 10),
                    Flexible(
                        child: ElevatedButton(
                            onPressed: _onImportIdeas,
                            child: Text(importIdeasButtonText))),
                  ],
                  SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(child: Text("-- or select a note --"))
                  ]),
                  SizedBox(height: 15),
                  Row(mainAxisSize: MainAxisSize.max, children: [
                    DropdownButton<Note>(
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
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            TextButton(
              child: Text(importButtonText),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
