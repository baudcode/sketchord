import 'package:flutter_flux/flutter_flux.dart';
import 'model.dart';
import 'package:flutter/material.dart';
import 'note_editor.dart';
import 'storage.dart';

class NoteList extends StatefulWidget {
  final bool sliver;

  NoteList(this.sliver);

  @override
  State<StatefulWidget> createState() {
    return NoteListState();
  }
}

class AbstractNoteItem extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final bool isAnySelected;

  AbstractNoteItem({this.note, this.isSelected, this.isAnySelected});

  bool get empty => (note.title == null ||
      (note.title.trim() == "" && this.sectionText().trim() == ""));

  Widget emptyText(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("empty",
            style: Theme.of(context)
                .textTheme
                .title
                .copyWith(fontWeight: FontWeight.w100)));
  }

  _onTap(context) {
    if (this.isAnySelected) {
      triggerSelectNote(note);
    } else {
      Navigator.push(context,
          new MaterialPageRoute(builder: (context) => NoteEditor(note)));
    }
  }

  _onLongPress(context) {
    print("long press on note ${note.title}");
    triggerSelectNote(note);
  }

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
  SmallNoteItem(
      Note note, bool isSelected, bool isAnySelected, this.width, this.padding)
      : super(note: note, isSelected: isSelected, isAnySelected: isAnySelected);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => _onTap(context),
        onLongPress: () => _onLongPress(context),
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
                                    textScaleFactor: .7,
                                    style: Theme.of(context).textTheme.title,
                                  )),
                              Text(this.sectionText(),
                                  maxLines: 9,
                                  softWrap: true,
                                  overflow: TextOverflow.clip)
                            ])))));
  }
}

class NoteItem extends AbstractNoteItem {
  final double padding;

  NoteItem(Note note, bool isSelected, bool isAnySelected, {this.padding = 8})
      : super(note: note, isSelected: isSelected, isAnySelected: isAnySelected);

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
        onTap: () => _onTap(context),
        onLongPress: () => _onLongPress(context),
        child: Container(
            child: Card(
                color: (isSelected)
                    ? Theme.of(context).accentColor
                    : Theme.of(context).cardColor,
                child: (empty)
                    ? emptyText(context)
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

class NoteListState extends State<NoteList> with StoreWatcherMixin<NoteList> {
  StaticStorage store;

  @override
  void initState() {
    super.initState();
    store = listenToStore(storageToken);
  }

  List<Note> processList(List<Note> data, bool even) {
    List<Note> returns = new List();

    for (int i = 0; i < data.length; i++) {
      if (even && i % 2 == 0) returns.add(data[i]);
      if (!even && i % 2 != 0) returns.add(data[i]);
    }
    return returns;
  }

  _getItem(List<Note> notes, double width, int index, {double padding = 8}) {
    if (!store.view) {
      print("view");
      return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        direction: Axis.vertical,
                        alignment: WrapAlignment.spaceEvenly,
                        children: processList(notes, true)
                            .map((n) => SmallNoteItem(
                                n,
                                store.isSelected(n),
                                store.isAnyNoteSelected(),
                                width / 2 - padding,
                                EdgeInsets.only(left: 0)))
                            .toList(),
                      )
                    ]),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        direction: Axis.vertical,
                        alignment: WrapAlignment.spaceEvenly,
                        children: processList(notes, false)
                            .map((n) => SmallNoteItem(
                                n,
                                store.isSelected(n),
                                store.isAnyNoteSelected(),
                                width / 2 - padding,
                                EdgeInsets.only(left: 0)))
                            .toList(),
                      )
                    ])
              ]));
    } else {
      return Padding(
          padding: EdgeInsets.only(
              left: padding, right: padding, top: index == 0 ? padding : 0),
          child: NoteItem(
              notes[index],
              store.isSelected(
                notes[index],
              ),
              store.isAnyNoteSelected(),
              padding: padding));
    }
  }

  _body() {
    List<Note> notes = store.filteredNotes;

    double width = MediaQuery.of(context).size.width;
    int childCount = (store.view) ? notes.length : 1;
    if (widget.sliver) {
      return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
        return _getItem(notes, width, index);
      }, childCount: childCount));
    } else {
      return ListView.builder(
        itemBuilder: (context, index) {
          return _getItem(notes, width, index);
        },
        itemCount: childCount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _body();
  }
}
