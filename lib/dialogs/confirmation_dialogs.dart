import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

showDeleteDialog(BuildContext context, Note note, Function onDelete) async {
  bool isInCollection =
      await LocalStorage().getNumCollectionsByNoteId(note.id) > 0;

  String message = "Are you sure you want to delete this note?";

  if (isInCollection) {
    message =
        "Note is part of a collection. When removing this note it will be automatically removed from its collections. \n Are you sure you want to delete this note?";
  }

  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: <Widget>[
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("No")),
            ElevatedButton(
                onPressed: () {
                  onDelete();
                  Future.delayed(Duration(milliseconds: 100), () {
                    onDelete();
                  });
                },
                child: Text("Yes"))
          ],
        );
      });
}

showDeleteForeverDialog({
  BuildContext context,
  Note note,
  Function onDelete,
}) {
  String message =
      "Are you sure you want to delete \"${note.title}\" irrevocably?";
  showConfirmationDialog(
      title: "Delete Irrevocably",
      context: context,
      onConfirm: () {
        LocalStorage().deleteNote(note);
        onDelete();
      },
      onDeny: () {},
      message: message);
}

showDeleteNotesForeverDialog({
  BuildContext context,
  List<Note> notes,
  Function onDelete,
}) {
  String message =
      "Are you sure you want to delete ${notes.length} note/s irrevocably?";
  showConfirmationDialog(
      title: "Delete Irrevocably",
      context: context,
      onConfirm: () {
        for (Note note in notes) {
          LocalStorage().deleteNote(note);
        }
        onDelete();
      },
      onDeny: () {},
      message: message);
}

showConfirmationDialog(
    {BuildContext context,
    String title,
    String message,
    Function onConfirm,
    Function onDeny}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text(title),
          content: Padding(
            child: Text(message),
            padding: EdgeInsets.only(right: 10),
          ),
          actions: <Widget>[
            new TextButton(
              child: Text("No"),
              onPressed: () {
                if (onDeny != null) {
                  onDeny();
                }
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new ElevatedButton(
                child: new Text("Yes"),
                onPressed: () {
                  onConfirm();
                  Navigator.of(context).pop();
                }),
          ],
        );
      });
    },
  );
}
