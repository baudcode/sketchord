import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/model.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';
import 'package:google_fonts/google_fonts.dart';

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
        maxLines: widget.maxLines,

        //maxLines: widget.maxLines,
        enableInteractiveSelection: true,
        onChanged: (s) {
          if (widget.onChange != null) {
            widget.onChange(s);
          }
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
            child: TextButton(
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
                              hintText: 'Section Title',
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
        showUndoSnackbar(Scaffold.of(context),
            section.hasEmptyTitle ? "Section" : section.title, section, (_) {
          undoDeleteSection(section);
        });
      },
      direction: DismissDirection.startToEnd,
      key: globalKey,
      background: Card(
          child: Container(
              color: Theme.of(context).accentColor,
              child: Row(children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(10))),
    );
  }
}

class SectionView extends StatelessWidget {
  final Section section;
  final double textScaleFactor;
  final bool richChords;

  SectionView({this.section, this.textScaleFactor, this.richChords = false});

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 0,
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
                              child: Text(section.title,
                                  style: GoogleFonts.robotoMono(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .subtitle1
                                        .copyWith(),
                                    fontSize: 14,
                                    fontFeatures: [
                                      FontFeature.enable('smcp'),
                                    ],
                                  ),
                                  textScaleFactor: textScaleFactor,
                                  maxLines: 1)),
                          Wrap(children: [
                            Text(
                              (richChords)
                                  ? resolveRichContent(section.content)
                                  : section.content,
                              style: GoogleFonts.robotoMono(
                                textStyle:
                                    Theme.of(context).textTheme.subtitle2,
                                fontSize: 10,
                                letterSpacing: 0,
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.normal,
                              ),
                              textScaleFactor: textScaleFactor,
                              maxLines: null,
                            )
                          ])
                        ]))),
          ],
        )));
  }
}
