import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:sound/model.dart';

class AbstractNoteItem extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final Function onTap, onLongPress;

  AbstractNoteItem({this.note, this.isSelected, this.onTap, this.onLongPress});

  bool get empty => ((note.title == null || note.title.trim() == "") &&
      this.sectionText().trim() == "");

  Widget singleText(BuildContext context, String text) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .headline5
                .copyWith(fontWeight: FontWeight.w200)));
  }

  Widget emptyText(BuildContext context) {
    return singleText(context, "Empty");
  }

  Widget onlyTitle(BuildContext context) {
    return singleText(context, note.title);
  }

  bool get hasOnlyTitle =>
      (note.title != null && note.title != "") &&
      this.sectionText().trim() == "";

  String sectionText() {
    String text = "";
    for (Section section in note.sections) {
      text += section.content + '\n';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return null;
  }
}

class SmallNoteItem extends AbstractNoteItem {
  final double width;
  final EdgeInsets padding;

  SmallNoteItem(Note note, bool isSelected, Function onTap,
      Function onLongPress, this.width, this.padding)
      : super(
            note: note,
            isSelected: isSelected,
            onTap: onTap,
            onLongPress: onLongPress);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
            width: this.width,
            height: (empty) ? 50 : null,
            padding: this.padding,
            child: Card(
                color: (isSelected)
                    ? Theme.of(context).accentColor
                    : Theme.of(context).cardColor,
                child: empty
                    ? emptyText(context)
                    : hasOnlyTitle
                        ? onlyTitle(context)
                        : Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                      padding: EdgeInsets.only(bottom: 10),
                                      child: Text(
                                        note.title,
                                        textScaleFactor: .75,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline6,
                                      )),
                                  Text(this.sectionText(),
                                      maxLines: 9,
                                      textAlign: TextAlign.left,
                                      softWrap: true,
                                      overflow: TextOverflow.clip)
                                ])))));
  }
}

class NoteItem extends AbstractNoteItem {
  final double padding;

  NoteItem(Note note, bool isSelected, Function onTap, Function onLongPress,
      {this.padding = 8})
      : super(
            note: note,
            isSelected: isSelected,
            onTap: onTap,
            onLongPress: onLongPress);

  _top() {
    return Padding(
        padding: EdgeInsets.only(left: padding, right: padding, top: padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(note.key == null ? 'No Key' : note.key),
            Text(note.capo == null ? "No Capo" : "Capo ${note.capo}")
          ],
        ));
  }

  _title(context) {
    return Padding(
        child: Row(children: [
          Text(
            note.title,
            textScaleFactor: .8,
            style: Theme.of(context).textTheme.headline6,
          )
        ]),
        padding: EdgeInsets.all(padding));
  }

  _text() {
    return Padding(
        padding: EdgeInsets.all(padding),
        child: Text(
          this.sectionText(),
          textAlign: TextAlign.left,
          softWrap: true,
          maxLines: 5,
          overflow: TextOverflow.clip,
        ));
  }

  _bottom() {
    return Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text("${note.sections.length} Sections"),
            Text((note.tuning == null) ? "Standard" : "${note.tuning}")
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
            child: Card(
                color: (isSelected)
                    ? Theme.of(context).accentColor
                    : Theme.of(context).cardColor,
                child: (empty)
                    ? emptyText(context)
                    : hasOnlyTitle
                        ? onlyTitle(context)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                                _top(),
                                _title(context),
                                _text(),
                                _bottom(),
                              ]))));
  }
}
