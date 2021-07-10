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

getAddtionalInfoItemFromNote(Note note, AdditionalInfoItem item) {
  switch (item) {
    case AdditionalInfoItem.key:
      return note.key;
    case AdditionalInfoItem.tuning:
      return note.tuning;
    case AdditionalInfoItem.capo:
      return note.capo;
    case AdditionalInfoItem.label:
      return note.label;
    case AdditionalInfoItem.artist:
      return note.artist;
    default:
      return null;
  }
}

class NoteEditorAdditionalInfo extends StatefulWidget {
  final Note note;
  final bool allowEdit;
  final List<AdditionalInfoItem> items;
  final ValueChanged<AdditionalInfoItem> onFocusChange;
  final ValueChanged<Tuple2<AdditionalInfoItem, String>>
      onChange; // general any value change (to update suggestions)

  const NoteEditorAdditionalInfo(this.note,
      {this.allowEdit = true,
      this.items = AdditionalInfoItem.values,
      this.onFocusChange,
      this.onChange,
      Key key})
      : super(key: key);

  @override
  _NoteEditorAdditionalInfoState createState() =>
      _NoteEditorAdditionalInfoState();
}

class _NoteEditorAdditionalInfoState extends State<NoteEditorAdditionalInfo> {
  Map<AdditionalInfoItem, FocusNode> focusNodes = {};
  Map<AdditionalInfoItem, TextEditingController> controllers = {};

  @override
  void didUpdateWidget(NoteEditorAdditionalInfo oldWidget) {
    super.didUpdateWidget(oldWidget);

    print("Addtional Info Widget Update");
    widget.items.forEach((item) {
      String data = getAddtionalInfoItemFromNote(widget.note, item);
      print(item);
      print("note value: $data");
      print("controller value: ${controllers[item].text}");
      if (data == null) data = "";

      if (controllers[item].text != data && data != null) {
        print("update from note");
        controllers[item].text = data;
        controllers[item].selection =
            TextSelection.fromPosition(TextPosition(offset: data.length));
      }
    });
  }

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

      String text = getAddtionalInfoItemFromNote(widget.note, item);
      controllers[item] = TextEditingController(text: text == null ? "" : text);
    });
  }

  _edit({initial, title, hint, item}) {
    return TextFormField(
        focusNode: focusNodes[item],
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        enabled: widget.allowEdit,
        onChanged: (v) {
          print("$item on changed => ${v == null}");
          if (widget.onChange != null) widget.onChange(Tuple2(item, v));
        },
        controller: controllers[item],
        maxLines: 1);
  }

  getEdit(AdditionalInfoItem item) {
    switch (item) {
      case AdditionalInfoItem.tuning:
        return _edit(
          initial: widget.note.tuning == null ? "" : widget.note.tuning,
          title: "Tuning",
          hint: "Standard, Dadgad ...",
          item: item,
        );

      case AdditionalInfoItem.capo:
        return _edit(
          initial: widget.note.capo == null ? "" : widget.note.capo.toString(),
          title: "Capo",
          hint: "7, 5 ...",
          item: item,
        );

      case AdditionalInfoItem.key:
        return _edit(
          initial: widget.note.key == null ? "" : widget.note.key.toString(),
          title: "Key",
          hint: "C Major, A Minor ...",
          item: item,
        );
      case AdditionalInfoItem.label:
        return _edit(
          initial:
              widget.note.label == null ? "" : widget.note.label.toString(),
          title: "Label",
          hint: "Idea, Rock, Pop ...",
          item: item,
        );

      case AdditionalInfoItem.artist:
        return _edit(
          initial:
              widget.note.artist == null ? "" : widget.note.artist.toString(),
          title: "Artist",
          hint: "Passenger, Ed Sheeran ...",
          item: item,
        );
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
