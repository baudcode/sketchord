import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

Future<void> showDeleteDialog(
  BuildContext context,
  Note note,
  VoidCallback onDelete,
) async {
  const message = 'Are you sure you want to delete this note?';
  _deleteDialog(context, message, onDelete);
}

Future<void> showNoteCollectionDeleteDialog(
  BuildContext context,
  Object collection,
  VoidCallback onDelete,
) async {
  const message = 'Are you sure you want to delete this collection?';
  _deleteDialog(context, message, onDelete);
}

void _deleteDialog(
  BuildContext context,
  String message,
  VoidCallback onDelete,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              onDelete();
              Navigator.of(context).pop();
            },
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );
}

void showDeleteForeverDialog({
  required BuildContext context,
  required Note note,
  required VoidCallback onDelete,
}) {
  final message = 'Are you sure you want to delete "${note.title}" irrevocably?';
  showConfirmationDialog(
    title: 'Delete Irrevocably',
    context: context,
    onConfirm: () {
      LocalStorage().deleteNote(note);
      onDelete();
    },
    onDeny: () {},
    message: message,
  );
}

void showDeleteNotesForeverDialog({
  required BuildContext context,
  required List<Note> notes,
  required VoidCallback onDelete,
}) {
  final message =
      'Are you sure you want to delete ${notes.length} note/s irrevocably?';
  showConfirmationDialog(
    title: 'Delete Irrevocably',
    context: context,
    onConfirm: () {
      for (final note in notes) {
        LocalStorage().deleteNote(note);
      }
      onDelete();
    },
    onDeny: () {},
    message: message,
  );
}

void showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onConfirm,
  VoidCallback? onDeny,
}) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(message),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () {
              onDeny?.call();
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Yes'),
            onPressed: () {
              onConfirm();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
