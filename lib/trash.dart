import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/db.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_list.dart';
import 'package:sound/storage.dart';

class Trash extends StatefulWidget {
  final Function onMenuPressed;

  Trash(this.onMenuPressed, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TrashState();
  }
}

class _TrashState extends State<Trash> with StoreWatcherMixin {
  StaticStorage storage;

  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    storage = listenToStore(storageToken);
  }

  _selectionAppBar() {
    return AppBar(
      leading: IconButton(
          icon: Icon(Icons.clear), onPressed: () => clearSelection()),
      title: Text(storage.selectedNotes.length.toString()),
      actions: <Widget>[
        IconButton(
            icon: Icon(Icons.delete), onPressed: () => restoreSelectedNotes()),
      ],
    );
  }

  _appBar() {
    return AppBar(
        title: Text("Trash"),
        leading: IconButton(
            icon: Icon(Icons.menu), onPressed: widget.onMenuPressed));
  }

  @override
  Widget build(BuildContext context) {
    // items.add(_title());

    LocalStorage()
        .getNotes()
        .then((value) => LocalStorage().controller.sink.add(value));

    var builder = StreamBuilder<List<Note>>(
      stream: LocalStorage().stream,
      initialData: [],
      builder: (context, snap) {
        print(snap);
        if (snap.hasData) {
          return NoteList(false, false);
        } else {
          return CircularProgressIndicator();
        }
      },
    );

    return Scaffold(
        key: _globalKey,
        appBar: storage.isAnyNoteSelected() ? _selectionAppBar() : _appBar(),
        body: Container(
          child: builder,
        ));
  }
}
