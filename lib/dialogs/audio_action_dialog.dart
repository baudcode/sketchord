import 'package:flutter/material.dart';
import 'package:sound/model.dart';
import 'package:sound/dialogs/import_dialog.dart';

class AudioAction {
  final IconData icon;
  final String description;
  final int id;

  AudioAction(this.id, this.icon, this.description);
}

enum AudioActionEnum {
  share,
  move,
  duplicate,
  copy,
  move_to_new,
  search,
  star,
  unstar
}

var enum2Action = {
  AudioActionEnum.duplicate:
      AudioAction(AudioActionEnum.duplicate.index, Icons.copy, "Duplicate"),
  AudioActionEnum.move:
      AudioAction(AudioActionEnum.move.index, Icons.move_to_inbox, "Move"),
  AudioActionEnum.move_to_new: AudioAction(
      AudioActionEnum.move_to_new.index, Icons.new_label, "Move to New"),
  AudioActionEnum.search:
      AudioAction(AudioActionEnum.search.index, Icons.search, "Search"),
  AudioActionEnum.share:
      AudioAction(AudioActionEnum.share.index, Icons.share, "Share"),
  AudioActionEnum.star:
      AudioAction(AudioActionEnum.star.index, Icons.star_border, "Star"),
  AudioActionEnum.unstar:
      AudioAction(AudioActionEnum.unstar.index, Icons.star, "Unstar"),
};

showAudioActionDialog(BuildContext context, List<AudioActionEnum> actionEnums,
    ValueChanged<AudioAction> onActionPressed) {
  final actions = actionEnums
      .map((x) => enum2Action[x])
      .whereType<AudioAction>()
      .toList();
  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions.map<Widget>((action) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: Icon(action.icon, size: 30),
                        onPressed: () => onActionPressed(action)),
                    Text(action.description,
                        textScaler: const TextScaler.linear(0.7))
                  ],
                );
              }).toList()),
          // actions: [
          //   TextButton(
          //       child: Text("Close"),
          //       onPressed: () => Navigator.of(context).pop())
          // ]
        );
      });
}

showMoveToNoteDialog(
    BuildContext context, Future<void> Function() onDone, AudioFile f) {
  Future<Note> onMoveToNew() async {
    // create a new note
    Note note = Note.empty();
    note.audioFiles.add(f);
    await onDone();
    return note;
  }

  Future<Note> onMoveToExisting(Note note) async {
    note.audioFiles.add(f);
    await onDone();
    return note;
  }

  showImportDialog(
    context,
    "Move audio file to note",
    onMoveToNew,
    onMoveToExisting,
    importButtonText: "Move",
  );
}
