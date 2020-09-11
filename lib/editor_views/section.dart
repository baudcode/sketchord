import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';

class Editable extends StatefulWidget {
  final String initialValue, hintText;
  final TextStyle textStyle;
  final ValueChanged<String> onChange;
  final int maxLines;
  final bool multiline;
  final String labelText;

  Editable(
      {this.initialValue,
      this.textStyle,
      this.onChange,
      this.hintText,
      this.maxLines,
      this.multiline = false,
      this.labelText});

  @override
  State<StatefulWidget> createState() {
    return EditableState();
  }
}

class EditableState extends State<Editable> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController.fromValue(
        TextEditingValue(text: widget.initialValue));
  }

  @override
  void dispose() {
    _controller.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        decoration: InputDecoration.collapsed(hintText: widget.hintText)
            .copyWith(labelText: widget.labelText),
        keyboardType:
            (widget.multiline) ? TextInputType.multiline : TextInputType.text,
        expands: false,
        minLines: 1,
        maxLines: 10,

        //maxLines: widget.maxLines,
        enableInteractiveSelection: true,
        onChanged: (s) {
          print("widget changed");
          widget.onChange(s);
        },
        controller: _controller,
        textInputAction:
            (widget.multiline) ? TextInputAction.newline : TextInputAction.done,
        style: widget.textStyle);
  }
}

class AddSectionItem extends StatelessWidget {
  const AddSectionItem({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Container(
            height: 40,
            decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).cardColor, width: 2)),
            child: FlatButton(
              child: Text("Add Section",
                  style: Theme.of(context).textTheme.caption),
              onPressed: () => addSection(Section(title: "", content: "")),
            )));
  }
}

class SectionListItem extends StatelessWidget {
  // Section section, bool moveDown, bool moveUp, GlobalKey globalKey) {
  final Section section;
  final bool moveDown, moveUp;
  final GlobalKey globalKey;

  const SectionListItem(
      {this.section, this.moveUp, this.moveDown, this.globalKey, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> trailingWidgets = [];
    if (moveDown)
      trailingWidgets.add(IconButton(
          icon: Icon(Icons.arrow_drop_down),
          onPressed: () => moveSectionDown(section)));
    if (moveUp)
      trailingWidgets.add(IconButton(
        icon: Icon(Icons.arrow_drop_up),
        onPressed: () => moveSectionUp(section),
      ));
    Widget trailing = Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: trailingWidgets
          .map<Widget>((t) => Row(children: <Widget>[t]))
          .toList(),
    );

    Card card = Card(
        child: Container(
            child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Expanded(
            child: Container(
                padding: EdgeInsets.all(10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Editable(
                              initialValue: section.title,
                              textStyle: Theme.of(context).textTheme.subtitle1,
                              onChange: (s) =>
                                  changeSectionTitle(Tuple2(section, s)),
                              hintText: 'Title',
                              maxLines: 100)),
                      Wrap(children: [
                        Editable(
                            initialValue: section.content,
                            textStyle: Theme.of(context)
                                .textTheme
                                .subtitle2
                                .copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal),
                            onChange: (s) => changeContent(Tuple2(section, s)),
                            hintText: 'Content',
                            maxLines: 100,
                            multiline: true)
                      ])
                    ]))),
        trailing
      ],
    )));

    return Dismissible(
      child: card,
      onDismissed: (d) {
        deleteSection(section);
        showUndoSnackbar(globalKey.currentState, "Section", section, (_) {
          undoDeleteSection(section);
        });
      },
      direction: DismissDirection.startToEnd,
      key: globalKey,
      background: Card(
          child: Container(
              color: Colors.redAccent,
              child: Row(children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }
}
