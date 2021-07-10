import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:tuple/tuple.dart';

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

enum AdditionalInfoItem { tuning, capo, key, label, artist }

class NoteEditorAdditionalInfo extends StatefulWidget {
  final Note note;
  final bool allowEdit;
  final List<AdditionalInfoItem> items;
  final ValueChanged<AdditionalInfoItem> onFocusChange;

  const NoteEditorAdditionalInfo(this.note,
      {this.allowEdit = true,
      this.items = AdditionalInfoItem.values,
      this.onFocusChange,
      Key key})
      : super(key: key);

  @override
  _NoteEditorAdditionalInfoState createState() =>
      _NoteEditorAdditionalInfoState();
}

class _NoteEditorAdditionalInfoState extends State<NoteEditorAdditionalInfo> {
  Map<AdditionalInfoItem, FocusNode> focusNodes = {};

  @override
  void initState() {
    super.initState();
    widget.items.forEach((item) {
      FocusNode node = FocusNode();
      node.addListener(() {
        if (widget.onFocusChange != null && node.hasFocus) {
          print("focused $item");
          widget.onFocusChange(item);
        }
      });
      focusNodes[item] = node;
    });
  }

  _edit({initial, title, hint, onChanged, focus}) {
    return TextFormField(
        initialValue: initial,
        focusNode: focus,
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        enabled: widget.allowEdit,
        onChanged: (v) => onChanged(v),
        maxLines: 1);
  }

  getEdit(AdditionalInfoItem item) {
    switch (item) {
      case AdditionalInfoItem.tuning:
        return _edit(
            initial: widget.note.tuning == null ? "" : widget.note.tuning,
            title: "Tuning",
            hint: "Standard, Dadgad ...",
            focus: focusNodes[item],
            onChanged: changeTuning);

      case AdditionalInfoItem.capo:
        return _edit(
            initial:
                widget.note.capo == null ? "" : widget.note.capo.toString(),
            title: "Capo",
            hint: "7, 5 ...",
            focus: focusNodes[item],
            onChanged: changeCapo);

      case AdditionalInfoItem.key:
        return _edit(
            initial: widget.note.key == null ? "" : widget.note.key.toString(),
            title: "Key",
            hint: "C Major, A Minor ...",
            focus: focusNodes[item],
            onChanged: changeKey);
      case AdditionalInfoItem.label:
        return _edit(
            initial:
                widget.note.label == null ? "" : widget.note.label.toString(),
            title: "Label",
            hint: "Idea, Rock, Pop ...",
            focus: focusNodes[item],
            onChanged: changeLabel);

      case AdditionalInfoItem.artist:
        return _edit(
            initial:
                widget.note.artist == null ? "" : widget.note.artist.toString(),
            title: "Artist",
            hint: "Passenger, Ed Sheeran ...",
            focus: focusNodes[item],
            onChanged: changeArtist);
      default:
        return null;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
        runSpacing: 1,
        children: widget.items.map<Widget>((item) => getEdit(item)).toList());
  }
}
