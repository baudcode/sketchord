import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<List<Note>> getExampleNotes() async {
  String path = "assets/initial_data.json";
  String data = await rootBundle.loadString(path);
  List<dynamic> _notes = jsonDecode(data);
  return _notes.map<Note>((s) => Note.fromJson(s, s['id'])).toList();
}

showInitialImportDialog(
    BuildContext context, ValueChanged<List<Note>> onDone) async {
  List<Note> exampleNotes = await getExampleNotes();
  showSelectNotesImportDialog(context, onDone, exampleNotes);
}

showSelectNotesImportDialog(
    BuildContext context, ValueChanged<List<Note>> onDone, List<Note> notes,
    {String title =
        "Would you like to import any of these example songs?"}) async {
  showSelectNotesDialog(context, (List<Note> selected) async {
    for (Note note in selected) {
      await LocalStorage().syncNote(note);
      Future.delayed(Duration(milliseconds: 50));
    }
    NoteSet noteset = NoteSet.empty();
    noteset.notes = selected;
    noteset.name = 'All';
    await LocalStorage().syncSet(noteset);

    onDone(selected);
  }, onDone, notes, title: title);
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
          return Center(
              child: AlertDialog(
                  titlePadding: EdgeInsets.all(16),
                  contentPadding: EdgeInsets.all(18),
                  title: Text(title),
                  content: isImporting
                      ? Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemBuilder: (context, index) {
                            Note note = notes[index];
                            return CheckboxListTile(
                                activeColor: Theme.of(context).accentColor,
                                value: checked[note],
                                onChanged: (v) {
                                  setState(() => checked[note] = v);
                                },
                                title: ListTile(
                                  title: Text(note.title),
                                  subtitle: Text(note.artist),
                                ));
                          },
                          itemCount: notes.length,
                        ),
                  actions: isImporting
                      ? []
                      : [
                          TextButton(
                            child: Text("Cancel"),
                            onPressed: _onCancel,
                          ),
                          TextButton(
                              child: Text("Import"),
                              onPressed: () {
                                setState(() => isImporting = true);
                                _onImport();
                              }),
                        ]));
        });
      });
}
