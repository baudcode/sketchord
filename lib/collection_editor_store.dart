import 'package:flutter/material.dart' show Color;
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import '../local_storage.dart';
import '../file_manager.dart';
import '../model.dart';
import 'package:tuple/tuple.dart';

class CollectionEditorStore extends Store {
  NoteCollection _collection;
  NoteCollection get collection => _collection;

  Tuple2<int, dynamic> _lastDeletion;

  void setCollection(NoteCollection c) {
    _collection = c;
  }

  CollectionEditorStore() {
    editorSetCollection.listen((c) {
      _collection = c;
      trigger();
    });

    removeNoteFromCollection.listen((note) async {
      int index = _collection.notes.indexWhere((n) => n.id == note.id);
      _collection.notes.removeAt(index);
      _lastDeletion = Tuple2(index, note);
      await LocalStorage().syncCollection(_collection);

      trigger();
    });

    undoRemoveNoteFromCollection.listen((_) async {
      _collection.notes.insert(_lastDeletion.item1, _lastDeletion.item2);
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    moveNoteUp.listen((Note note) async {
      int index = _collection.notes.indexOf(note);

      if (index >= 1) {
        print("move up with index $index");
        _collection.notes.removeAt(index);
        _collection.notes.insert(index - 1, note);
        await LocalStorage().syncCollection(_collection);
        trigger();
      }
    });
    moveNoteDown.listen((Note note) async {
      int index = _collection.notes.indexOf(note);

      if (index != (collection.notes.length - 1) && index >= 0) {
        print('move down with index: $index');
        _collection.notes.removeAt(index);
        _collection.notes.insert(index + 1, note);
        await LocalStorage().syncCollection(_collection);
      }
      trigger();
    });

    changeCollectionTitle.listen((t) async {
      _collection.title = t;
      print('chaning title...');
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    changeCollectionDescription.listen((t) async {
      _collection.description = t;
      print('chaning description...');
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    updateCollectionEditorView.listen((_) {
      trigger();
    });

    toggleCollectionStarred.listen((event) async {
      _collection.starred = !_collection.starred;
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    addNoteToCollection.listen((Note note) async {
      _collection.notes.add(note);
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    addNotesToCollection.listen((List<Note> notes) async {
      _collection.notes.addAll(notes);
      await LocalStorage().syncCollection(_collection);
      trigger();
    });

    setNotesOfCollection.listen((List<Note> notes) async {
      _collection.notes = notes;
      await LocalStorage().syncCollection(_collection);
      trigger();
    });
  }
}

Action<NoteCollection> editorSetCollection = Action();
Action<Note> removeNoteFromCollection = Action();
Action<List<Note>> setNotesOfCollection = Action();
Action<String> changeCollectionDescription = Action();
Action<String> changeCollectionTitle = Action();
Action<Note> moveNoteDown = Action();
Action<Note> moveNoteUp = Action();
Action<Note> addNoteToCollection = Action();
Action<List<Note>> addNotesToCollection = Action();
Action undoRemoveNoteFromCollection = Action();
Action toggleCollectionStarred = Action();
Action updateCollectionEditorView = Action();

StoreToken collectionEditorStoreToken = StoreToken(CollectionEditorStore());
