import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';

class ParsedNote {
  final String title;
  final List<Section> sections;

  ParsedNote({this.title, this.sections});
}

ParsedNote parseText(String text) {
  List<String> splits = text.split('\n');
  print("splits: ${splits.length}");
  List<List<String>> parts = [];

  List<String> part = [];

  for (String s in splits) {
    if (s == null) continue;

    s = s.trim();

    bool isEmpty = s == "";
    bool isSectionTitle = s.startsWith("[");
    //print("$s, $isEmpty, $isSectionTitle");
    // do not add empty parts
    if (isEmpty) {
      print("$s => isEmpty, ${part.length}");
      if (part.length == 0)
        continue;
      else {
        print(part);
        parts.add(part);
        part = [];
      }
    } else if (isSectionTitle) {
      print("SectionTitle: $s");
      // add current part if section
      if (part.length > 0) {
        parts.add(part);
        part = [];
      }
      part.add(s);
    } else {
      part.add(s);
    }
  }
  // add if any string is left
  if (part.length > 0) parts.add(part);

  // return empty if no part was found
  if (parts.length == 0) return null;

  int start = 0;
  List<Section> sections = [];
  String title;

  // skip the start, cause it was the title
  if (parts[0].length == 1) {
    title = parts[0][0];
    start += 1;
  }

  for (var i = start; i < parts.length; i++) {
    var cur = parts[i];
    String title = "";

    if (cur[0].startsWith("[")) {
      // is section with custom title
      title = cur[0].trim().replaceAll("[", "").replaceAll("]", "");
      if (cur.length > 1) {
        cur = cur.sublist(1);
      } else {
        cur = [];
      }
    }
    String content = cur.join('\n');
    sections.add(Section(title: title, content: content));
  }
  return ParsedNote(sections: sections, title: title);
}

showInvalidTextSnack(BuildContext context) {
  var snackbar = SnackBar(
      content: Text("The text the app received has no valid format!"),
      backgroundColor: Theme.of(context).errorColor);
  Scaffold.of(context).showSnackBar(snackbar);
}

showTextImportDialog(BuildContext context, String text) async {
  List<Note> notes = await LocalStorage().getNotes();
  print("received text: $text");
  ParsedNote parsed = parseText(text);

  if (parsed == null) {
    showInvalidTextSnack(context);
    return;
  }

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
        selected.sections.addAll(parsed.sections);
        LocalStorage().syncNote(selected);
        Navigator.of(context).pop();
        _open(selected);
      }

      _onNew() async {
        Note empty = Note.empty();
        empty.sections = parsed.sections;
        if (parsed.title != null) empty.title = parsed.title;

        LocalStorage().syncNote(empty);
        Navigator.of(context).pop();
        _open(empty);
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text("Import ${parsed.sections.length} Sections"),
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
