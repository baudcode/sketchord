import 'package:flutter/material.dart';
import 'package:sound/model.dart';
import 'package:sound/utils.dart';

typedef FutureNoteImportCallback = Future Function(List<Note>);

showAddNotesDialog(
    {@required BuildContext context,
    @required List<Note> notes,
    @required List<Note> preselected,
    @required FutureNoteImportCallback onImport,
    String title = 'Add Notes',
    String newButtonText = 'Import as NEW',
    String importButtonText = "Import",
    String cancelButtonText = "Cancel"}) {
  // trigger note selection / deselection via button press

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)

      List<Note> selected = [];

      _import() async {
        // sync and pop current dialog
        await onImport(selected);
        Navigator.of(context).pop();
      }

      bool isSelected(int index) {
        return selected.contains(notes[index]);
      }

      bool emptyTitle(Note note) {
        return (note.title == null || note.title.trim() == "");
      }

      return StatefulBuilder(builder: (context, setState) {
        var width = MediaQuery.of(context).size.width;
        return AlertDialog(
          title: new Text(title),
          content: Builder(builder: (context) {
            return ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: 16, maxWidth: 160),
                        child: Text(
                          emptyTitle(notes[index])
                              ? "Empty"
                              : notes[index].title,
                          overflow: TextOverflow.clip,
                        )),
                    onTap: () {
                      setState(() {
                        if (isSelected(index)) {
                          selected.remove(notes[index]);
                        } else {
                          selected.add(notes[index]);
                        }
                      });
                    },
                    trailing: isSelected(index)
                        ? IconButton(
                            icon: Icon(
                            Icons.check,
                            color: getSelectedCardColor(context),
                          ))
                        : null,
                  );
                },
                itemCount: notes.length);
          }),
          actions: <Widget>[
            new TextButton(
              child: Text(cancelButtonText),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new TextButton(
              child: new Text(importButtonText),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
