import 'package:sound/note_item.dart';
import 'model.dart';
import 'package:flutter/material.dart';
import 'storage.dart';

class NoteListItemModel {
  final Note note;
  final bool isSelected;
  final String highlight; // a test to highlight

  NoteListItemModel({this.note, this.isSelected, this.highlight});
}

class NoteList extends StatefulWidget {
  final bool sliver;
  final bool singleView;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onLongPress;
  final String highlight;

  final List<NoteListItemModel> items;
  NoteList(
      this.sliver, this.singleView, this.items, this.onTap, this.onLongPress,
      {this.highlight});

  @override
  State<StatefulWidget> createState() {
    return NoteListState();
  }
}

class NoteListState extends State<NoteList> {
  @override
  void initState() {
    super.initState();
  }

  List<NoteListItemModel> processList(List<NoteListItemModel> data, bool even) {
    List<NoteListItemModel> returns = new List();

    for (int i = 0; i < data.length; i++) {
      if (even && i % 2 == 0) returns.add(data[i]);
      if (!even && i % 2 != 0) returns.add(data[i]);
    }
    return returns;
  }

  _getItem(double width, int index, {double padding = 8}) {
    if (!widget.singleView) {
      return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                    flex: 1,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            direction: Axis.vertical,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: processList(widget.items, true)
                                .map((i) => SmallNoteItem(
                                    i.note,
                                    i.isSelected,
                                    () => widget.onTap(i.note),
                                    () => widget.onLongPress(i.note),
                                    widget.highlight,
                                    width / 2 - padding,
                                    EdgeInsets.only(left: 0)))
                                .toList(),
                          )
                        ])),
                Flexible(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                      Wrap(
                        direction: Axis.vertical,
                        alignment: WrapAlignment.spaceEvenly,
                        children: processList(widget.items, false)
                            .map((i) => SmallNoteItem(
                                i.note,
                                i.isSelected,
                                () => widget.onTap(i.note),
                                () => widget.onLongPress(i.note),
                                widget.highlight,
                                width / 2 - padding,
                                EdgeInsets.only(left: 0)))
                            .toList(),
                      )
                    ]))
              ]));
    } else {
      print("index: $index");
      print(widget.items);
      var item = widget.items[index];

      return Padding(
          padding: EdgeInsets.only(
              left: padding,
              right: padding,
              top: index == 0 ? padding : 0,
              bottom: index == widget.items.length - 1 ? padding : 0),
          child: NoteItem(
              item.note,
              item.isSelected,
              () => widget.onTap(item.note),
              () => widget.onLongPress(item.note),
              widget.highlight,
              padding: padding));
    }
  }

  _body(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int childCount = (widget.singleView) ? widget.items.length : 1;

    if (widget.sliver) {
      return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
        return _getItem(width, index);
      }, childCount: childCount));
    } else {
      return ListView.builder(
        itemBuilder: (context, index) {
          return _getItem(width, index);
        },
        itemCount: childCount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _body(context);
  }
}
