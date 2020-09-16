import 'package:flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:sound/model.dart';

class AbstractNoteItem extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final Function onTap, onLongPress;
  final String highlight;

  AbstractNoteItem(
      {this.note,
      this.isSelected,
      this.onTap,
      this.onLongPress,
      this.highlight});

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

  Widget highlightTitle(BuildContext context, String title, String highlight) {
    List<TextSpan> spans = [];

    if (highlight == null) {
      spans.add(TextSpan(text: title));
    } else {
      int start = title.indexOf(highlight);
      if (start == -1) {
        spans.add(TextSpan(text: title));
      } else {
        spans.add(TextSpan(text: title.substring(0, start)));
        spans.add(TextSpan(
            text: title.substring(start, start + title.length),
            style: TextStyle(backgroundColor: Theme.of(context).primaryColor)));
        spans.add(TextSpan(text: title.substring(start + title.length)));
      }
    }

    return Text.rich(
      TextSpan(
        children: spans,
      ),
      //softWrap: true,
      //overflow: TextOverflow.clip,
      //maxLines: 1,
      style: Theme.of(context).textTheme.headline6,
      textScaleFactor: 0.75,
      textAlign: TextAlign.left,
    );
  }

  Widget highlightSectionText(
      BuildContext context, String text, String highlight,
      {int maxLines = 9}) {
    List<TextSpan> spans = [];

    if (highlight == null) {
      spans.add(TextSpan(text: text));
    } else {
      List<String> sections = text.split("\n");
      int start = text.indexOf(highlight);

      if (start == -1)
        spans.add(TextSpan(text: text));
      else {
        int k = 0;
        int inSection = 0;
        for (var i = 0; i < sections.length; i++) {
          if (start >= k && start <= (k + sections[i].length)) {
            inSection = i;
            break;
          }
          k += sections[i].length + 1;
        }
        print("section: ${sections[inSection]}, text: $highlight");
        // start at the start of the found section
        int sectionStart = text.indexOf(sections[inSection]);
        int end = start + highlight.length;
        print("$sectionStart, $start, $end, ${text.length}");

        spans.add(TextSpan(text: text.substring(sectionStart, start)));
        spans.add(TextSpan(
            text: text.substring(start, end),
            style: TextStyle(backgroundColor: Theme.of(context).primaryColor)));
        spans.add(TextSpan(text: text.substring(end)));
      }
    }

    return Text.rich(
      TextSpan(
        //text: 'TEST',
        children: spans,
      ),
      softWrap: true,
      overflow: TextOverflow.clip,
      maxLines: maxLines,
      textAlign: TextAlign.left,
    );
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
      Function onLongPress, String highlight, this.width, this.padding)
      : super(
            note: note,
            isSelected: isSelected,
            onTap: onTap,
            onLongPress: onLongPress,
            highlight: highlight);

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
                                      child: highlightTitle(
                                          context, note.title, highlight)),
                                  highlightSectionText(
                                      context, this.sectionText(), highlight),
                                ])))));
  }
}

class NoteItem extends AbstractNoteItem {
  final double padding;

  NoteItem(Note note, bool isSelected, Function onTap, Function onLongPress,
      String highlight, {this.padding = 8})
      : super(
            note: note,
            isSelected: isSelected,
            onTap: onTap,
            onLongPress: onLongPress,
            highlight: highlight);

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
