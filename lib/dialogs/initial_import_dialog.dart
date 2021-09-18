import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sound/backup.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

Future<List<Note>> getExampleNotes() async {
  String path = "assets/initial_data.json";
  String data = await rootBundle.loadString(path);
  List<dynamic> _notes = jsonDecode(data);
  return _notes.map<Note>((s) => Note.fromJson(s, s['id'])).toList();
}

showInitialImportDialog(
    BuildContext context, ValueChanged<BackupData> onDone) async {
  List<Note> exampleNotes = await getExampleNotes();
  NoteCollection exampleCollection = NoteCollection.empty();
  exampleCollection.notes = exampleNotes;
  exampleCollection.title = "Example Set";
  exampleCollection.description = "Your imported notes";
  exampleCollection.starred = true;

  showSelectNotesImportDialog(context, onDone,
      BackupData(notes: exampleNotes, collections: [exampleCollection]));
}

showSelectNotesImportDialog(
    BuildContext context, ValueChanged<BackupData> onDone, BackupData backup,
    {String title =
        "Would you like to import any of these example songs?"}) async {
  showSelectNotesDialog(context, (List<Note> selected) async {
    List<String> noteIds = selected.map((n) => n.id).toList();
    print("selected note ids: $noteIds");

    for (Note note in selected) {
      await LocalStorage().syncNote(note);
      Future.delayed(Duration(milliseconds: 50));
    }

    for (NoteCollection collection in backup.collections) {
      // remove all notes that where not imported
      collection.notes.removeWhere((note) => !noteIds.contains(note.id));
      await LocalStorage().syncCollection(collection);
      Future.delayed(Duration(milliseconds: 50));
    }

    onDone(backup);
  }, () {}, backup.notes, title: title);
}

typedef NoteListCallback = Future<void> Function(List<Note>);

showSelectNotesDialog(BuildContext context, NoteListCallback onApply,
    Function onCancel, List<Note> notes,
    {String title = "Select Notes"}) async {
  Map<Note, bool> checked = {};
  bool isImporting = false;

  for (Note note in notes) {
    checked[note] = true;
  }

  _onImport() async {
    List<Note> checkedNotes = checked.entries
        .where((element) => element.value)
        .map((v) => v.key)
        .toList();

    await onApply(checkedNotes);
    Navigator.of(context).pop();
  }

  _onCancel() {
    onCancel();
    Navigator.of(context).pop();
  }

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          var width = MediaQuery.of(context).size.width;

          return Center(
              child: AlertDialog(
                  titlePadding: EdgeInsets.all(16),
                  contentPadding: EdgeInsets.all(18),
                  title: Text(title),
                  content: isImporting
                      ? Center(child: CircularProgressIndicator())
                      : Container(
                          width: width,
                          height: 400,
                          child: ListView.builder(
                            itemBuilder: (context, index) {
                              Note note = notes[index];
                              return CheckboxListTile(
                                  activeColor: Theme.of(context).accentColor,
                                  value: checked[note],
                                  onChanged: (v) {
                                    setState(() => checked[note] = v);
                                  },
                                  title: ListTile(
                                    title: Text(note.hasEmptyTitle
                                        ? EMPTY_TEXT
                                        : note.title),
                                    subtitle: Text(
                                        note.artist == null ? "" : note.artist),
                                  ));
                            },
                            itemCount: notes.length,
                          )),
                  actions: isImporting
                      ? []
                      : [
                          TextButton(
                            child: Text("Cancel"),
                            onPressed: _onCancel,
                          ),
                          ElevatedButton(
                              child: Text("Import"),
                              onPressed: () {
                                setState(() => isImporting = true);
                                _onImport();
                              }),
                        ]));
        });
      });
}
