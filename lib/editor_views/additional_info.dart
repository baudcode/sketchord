import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';

class NoteEditorTitle extends StatelessWidget {
  final String title;

  const NoteEditorTitle({this.title, Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
        visualDensity: VisualDensity.comfortable,
        title: TextFormField(
            initialValue: title,
            decoration: InputDecoration(
                labelText: "Title",
                border: InputBorder.none,
                hintText: 'Enter Title'),
            onChanged: (s) => changeTitle(s),
            maxLines: 1));
  }
}

class NoteEditorAdditionalInfo extends StatelessWidget {
  final Note note;

  const NoteEditorAdditionalInfo(this.note, {Key key}) : super(key: key);

  _edit({initial, title, hint, onChanged}) {
    return TextFormField(
        initialValue: initial,
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        onChanged: (V) => onChanged(V),
        maxLines: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(left: 10, top: 10),
        child: Wrap(runSpacing: 1, children: [
          _edit(
              initial: note.tuning == null ? "" : note.tuning,
              title: "Tuning",
              hint: "f.e. Standard, Dadgad",
              onChanged: changeTuning),
          _edit(
              initial: note.capo == null ? "" : note.capo.toString(),
              title: "Capo",
              hint: "f.e. 7, 5",
              onChanged: changeCapo),
          _edit(
              initial: note.key == null ? "" : note.key.toString(),
              title: "Key",
              hint: "f.e. C Major, A Minor",
              onChanged: changeKey),
          _edit(
              initial: note.label == null ? "" : note.label.toString(),
              title: "Label",
              hint: "f.e. Rock, Pop...",
              onChanged: changeLabel),
          _edit(
              initial: note.artist == null ? "" : note.artist.toString(),
              title: "Artist",
              hint: "leave empty if you are the artist",
              onChanged: changeArtist),
        ]));
  }
}
