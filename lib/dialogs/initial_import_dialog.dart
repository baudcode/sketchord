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

showInitialImportDialog(BuildContext context, Function onDone) async {
  List<Note> exampleNotes = await getExampleNotes();
  Map<Note, bool> checked = {};
  bool isImporting = false;

  for (Note note in exampleNotes) {
    checked[note] = true;
  }

  _onImport() async {
    List<Note> checkedNotes = checked.entries
        .where((element) => element.value)
        .map((v) => v.key)
        .toList();
    for (Note note in checkedNotes) {
      await LocalStorage().syncNote(note);
      Future.delayed(Duration(milliseconds: 50));
    }
    onDone();
    Navigator.of(context).pop();
  }

  _onCancel() {
    onDone();
    Navigator.of(context).pop();
  }

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
              titlePadding: EdgeInsets.all(16),
              contentPadding: EdgeInsets.all(18),
              title:
                  Text("Would you like to import any of these example songs?"),
              content: isImporting
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemBuilder: (context, index) {
                        Note note = exampleNotes[index];
                        return CheckboxListTile(
                            activeColor: Theme.of(context).accentColor,
                            value: checked[note],
                            onChanged: (v) {
                              setState(() => checked[note] = v);
                            },
                            title: Text(note.title));
                      },
                      itemCount: exampleNotes.length,
                    ),
              actions: isImporting
                  ? []
                  : [
                      FlatButton(
                        child: Text("Cancel"),
                        onPressed: _onCancel,
                      ),
                      FlatButton(
                          child: Text("Import"),
                          onPressed: () {
                            setState(() => isImporting = true);
                            _onImport();
                          }),
                    ]);
        });
      });
}
