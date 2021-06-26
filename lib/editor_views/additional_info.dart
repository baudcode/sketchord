import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';

class NoteEditorTitle extends StatelessWidget {
  final String title, hintText, labelText;
  final bool allowEdit;
  final ValueChanged<String> onChange;

  NoteEditorTitle(
      {@required this.title,
      @required this.onChange,
      this.allowEdit = true,
      this.hintText = 'Enter Title',
      this.labelText = 'Title',
      Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
        visualDensity: VisualDensity.comfortable,
        title: TextFormField(
            enabled: allowEdit,
            initialValue: title,
            decoration: InputDecoration(
                labelText: labelText,
                border: InputBorder.none,
                hintText: hintText),
            onChanged: onChange,
            maxLines: 1));
  }
}

class NoteEditorAdditionalInfo extends StatelessWidget {
  final Note note;
  final bool allowEdit;

  const NoteEditorAdditionalInfo(this.note, {this.allowEdit = true, Key key})
      : super(key: key);

  _edit({initial, title, hint, onChanged}) {
    return TextFormField(
        initialValue: initial,
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        enabled: allowEdit,
        onChanged: (v) => onChanged(v),
        maxLines: 1);
  }

  @override
  Widget build(BuildContext context) {
    // EdgeInsets.only(left: 10, top: 10)
    return Wrap(runSpacing: 1, children: [
      _edit(
          initial: note.tuning == null ? "" : note.tuning,
          title: "Tuning",
          hint: "Standard, Dadgad ...",
          onChanged: changeTuning),
      _edit(
          initial: note.capo == null ? "" : note.capo.toString(),
          title: "Capo",
          hint: "7, 5 ...",
          onChanged: changeCapo),
      _edit(
          initial: note.key == null ? "" : note.key.toString(),
          title: "Key",
          hint: "C Major, A Minor ...",
          onChanged: changeKey),
      _edit(
          initial: note.label == null ? "" : note.label.toString(),
          title: "Label",
          hint: "Idea, Rock, Pop...",
          onChanged: changeLabel),
      _edit(
          initial: note.artist == null ? "" : note.artist.toString(),
          title: "Artist",
          hint: "leave empty if you are the artist",
          onChanged: changeArtist),
    ]);
  }
}
