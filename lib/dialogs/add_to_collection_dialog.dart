import 'package:flutter/material.dart';
import 'package:sound/collections.dart';
import 'package:sound/main.dart';
import 'package:sound/model.dart';
import 'package:sound/local_storage.dart';

typedef FutureNoteCollectionCallback = Future<NoteCollection> Function();
typedef FutureAddNoteToCollectionCallback = Future<NoteCollection> Function(
    NoteCollection);

showAddToCollectionDialog(BuildContext context, Note note) {
  Future<NoteCollection> onNew() async {
    NoteCollection collection = NoteCollection.empty();
    collection.notes.add(note);
    return collection;
  }

  Future<NoteCollection> onAdd(NoteCollection collection) async {
    if (!collection.notes.any((element) => element.id == note.id)) {
      collection.notes.add(note);
    }
    return collection;
  }

  _showAddToCollectionDialog(context, "Add To Set", onNew, onAdd, note,
      importButtonText: 'Add');
}

_showAddToCollectionDialog(
    BuildContext context,
    String title,
    FutureNoteCollectionCallback onNew,
    FutureAddNoteToCollectionCallback onAdd,
    Note note,
    {String newButtonText = 'Create NEW',
    String importButtonText = "Import",
    bool openCollection = true,
    bool syncCollection = true}) async {
  List<NoteCollection> collections = await LocalStorage().getCollections();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if selected is null (use empty new note)
      NoteCollection selected;

      _open(NoteCollection col) {
        if (openCollection) {
          Navigator.push(
              context,
              new MaterialPageRoute(
                  builder: (context) => CollectionEditor(col)));
        }
      }

      _import() async {
        // sync and pop current dialog
        NoteCollection collection = await onAdd(selected);
        if (syncCollection) {
          LocalStorage().syncCollection(collection);
        }
        Navigator.of(context).pop();
        _open(collection);
      }

      _onNew() async {
        NoteCollection newCollection = await onNew();
        if (syncCollection) {
          LocalStorage().syncCollection(newCollection);
        }

        Navigator.of(context).pop();
        _open(newCollection);
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text(title),
          content: Builder(builder: (context) {
            double width = MediaQuery.of(context).size.width;
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                      child: ElevatedButton(
                          child: Text(newButtonText), onPressed: _onNew)),
                  SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(child: Text("-- or select a set --"))
                  ]),
                  SizedBox(height: 15),
                  Row(mainAxisSize: MainAxisSize.max, children: [
                    new DropdownButton<NoteCollection>(
                        value: selected,
                        isDense: true,
                        items: collections
                            .where((c) {
                              try {
                                c.notes.firstWhere((n) => n.id == note.id);
                                return false;
                              } catch (e) {
                                return true;
                              }
                            })
                            .map((e) => DropdownMenuItem<NoteCollection>(
                                child: SizedBox(
                                    width: width - 152,
                                    child: Text(
                                        "${collections.indexOf(e)}: ${e.title}",
                                        overflow: TextOverflow.ellipsis)),
                                value: e))
                            .toList(),
                        onChanged: (v) => setState(() => selected = v)),
                  ])
                ]);
          }),
          actions: <Widget>[
            new TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new ElevatedButton(
              child: new Text(
                importButtonText,
              ),
              onPressed: (selected != null) ? _import : null,
            ),
          ],
        );
      });
    },
  );
}
