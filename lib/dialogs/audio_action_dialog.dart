import 'package:flutter/material.dart';
import 'package:sound/file_manager.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';
import 'package:sound/note_search_view.dart';

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
  // actions are an icon with a descrition unterneath it

  var actions = actionEnums.map((x) => enum2Action[x]).toList();
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
                    Text(action.description, textScaleFactor: 0.7)
                  ],
                );
              }).toList()),
          // actions: [
          //   FlatButton(
          //       child: Text("Close"),
          //       onPressed: () => Navigator.of(context).pop())
          // ]
        );
      });
}

showMoveToNoteDialog(BuildContext context, Function onDone, AudioFile f) {
  // actions are an icon with a descrition unterneath it
  onMoveToNew() async {
    // create a new note
    Note note = Note.empty();
    note.audioFiles.add(f);

    // manual sync
    await LocalStorage().syncNote(note);
    // open the note
    onDone();

    Navigator.of(context)
        .push(new MaterialPageRoute(builder: (context) => NoteEditor(note)));
  }

  onSearch() {
    Navigator.push(
        context,
        new MaterialPageRoute(
            builder: (context) => NoteSearchViewLoader(
                  single: true,
                  collection: NoteCollection.empty(),
                  onAddNotes: (List<Note> notes) {
                    print("selected notes: ${notes.map((e) => e.title)}");
                    onDone();
                  },
                ))).then((value) {
      onDone();
    });
  }

  toggleStar() async {
    f.starred = !f.starred;
    await LocalStorage().syncAudioFile(f);
  }

  var id2action = {
    AudioActionEnum.move_to_new.index: onMoveToNew,
    AudioActionEnum.search.index: onSearch,
    AudioActionEnum.star.index: toggleStar,
    AudioActionEnum.unstar.index: toggleStar,
  };
  var order = [
    AudioActionEnum.move_to_new,
    AudioActionEnum.search,
  ];

  showAudioActionDialog(context, order, (value) {
    id2action[value.id]();
  });
}
