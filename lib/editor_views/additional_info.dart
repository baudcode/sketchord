import 'package:flutter/material.dart';
import 'package:sound/dialogs/change_number_dialog.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';

class NoteEditorTitle extends StatefulWidget {
  final String title, hintText, labelText;
  final bool allowEdit;
  final ValueChanged<String> onChange;
  final FocusNode focus;
  final bool showInsertDate;

  NoteEditorTitle(
      {@required this.title,
      @required this.onChange,
      this.allowEdit = true,
      this.hintText = 'Enter Title',
      this.labelText = 'Title',
      this.focus,
      this.showInsertDate = false,
      Key key})
      : super(key: key);

  @override
  _NoteEditorTitleState createState() => _NoteEditorTitleState();
}

class _NoteEditorTitleState extends State<NoteEditorTitle> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(NoteEditorTitle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (controller.text != widget.title) {
      controller.text = widget.title;
      controller.selection =
          TextSelection.fromPosition(TextPosition(offset: widget.title.length));
    }
  }

  _insertDate() {
    if (!widget.showInsertDate || controller.text.length > 0) {
      return null;
    }
    return TextButton(
        onPressed: () {
          widget.onChange(getFormattedDate(DateTime.now()));
        },
        child: Text("Insert Date"));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
        visualDensity: VisualDensity.comfortable,
        trailing: _insertDate(),
        title: TextFormField(
            controller: controller,
            enabled: widget.allowEdit,
            focusNode: widget.focus,
            decoration: InputDecoration(
                labelText: widget.labelText,
                border: InputBorder.none,
                hintText: widget.hintText),
            onChanged: widget.onChange,
            maxLines: 1));
  }
}

enum AdditionalInfoItem { tuning, capo, key, label, artist, title }

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
    case AdditionalInfoItem.title:
      return note.title;
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
      this.items = const [
        AdditionalInfoItem.key,
        AdditionalInfoItem.tuning,
        AdditionalInfoItem.capo,
        AdditionalInfoItem.label,
        AdditionalInfoItem.artist
      ],
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

  TextEditingController bpmController, lengthController;

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

    if (widget.note.bpm != null) {
      bpmController.text = widget.note.bpm.toString();
    }
    if (widget.note.length != null) {
      lengthController.text = widget.note.lengthStr;
    }
  }

  @override
  void initState() {
    super.initState();

    widget.items.forEach((item) {
      FocusNode node = FocusNode();
      node.addListener(() {
        if (widget.onFocusChange != null && node.hasFocus) {
          widget.onFocusChange(item);
        } else {
          widget.onFocusChange(null);
        }
      });
      focusNodes[item] = node;

      String text = getAddtionalInfoItemFromNote(widget.note, item);
      controllers[item] = TextEditingController(text: text == null ? "" : text);
    });

    bpmController = TextEditingController(
        text: widget.note.bpm == null ? null : widget.note.bpm.toString());
    lengthController = TextEditingController(text: widget.note.lengthStr);
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

  _extra({text, title}) {
    return TextFormField(
        enabled: false,
        initialValue: text,
        decoration:
            InputDecoration(labelText: title, border: InputBorder.none));
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
      case AdditionalInfoItem.title:
        return _edit(
          initial:
              widget.note.title == null ? "" : widget.note.title.toString(),
          title: "Title",
          hint: "...",
          item: item,
        );
      default:
        return null;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    var edits = widget.items.map<Widget>((item) => getEdit(item)).toList();

    // add bpm and length
    // default length: 3 minutes
    print(widget.note.bpm);

    // show
    var bpmField = GestureDetector(
        onTap: () {
          if (widget.allowEdit) {
            FocusScope.of(context).unfocus();

            showChangeNumberDialog(
                context,
                "BPM",
                widget.note.bpm == null
                    ? Note.defaultBPM.toDouble()
                    : widget.note.bpm.toDouble(), (value) {
              print("setting bpm to $value");
              changeBPM(value.toInt());
            }, min: 0, max: 300, longPressStep: 5);
          }
        },
        child: TextFormField(
          enabled: false,
          controller: bpmController,
          //focusNode: widget.focus,
          decoration:
              InputDecoration(labelText: "BPM", border: InputBorder.none),
        ));

    var lengthField = GestureDetector(
        onTap: () {
          if (widget.allowEdit) {
            FocusScope.of(context).unfocus();

            showChangeNumberDialog(
                context,
                "Length",
                widget.note.length == null
                    ? Note.defaultLength.toDouble()
                    : widget.note.length.toDouble(), (value) {
              print("setting length to $value");
              changeLength(value.toInt());
            }, min: 0, max: 300, isTime: true, longPressStep: 10);
          }
        },
        child: TextFormField(
          enabled: false,
          controller: lengthController,
          //focusNode: widget.focus,
          decoration:
              InputDecoration(labelText: "Length", border: InputBorder.none),
        ));

    var extra = <Widget>[
      lengthField,
      bpmField,
      _extra(text: dateToString(widget.note.createdAt), title: "Created At"),
      _extra(
          text: dateToString(widget.note.lastModified),
          title: "Last Modified At")
    ];
    var children = edits + extra;
    return Wrap(runSpacing: 1, children: children);
  }
}
