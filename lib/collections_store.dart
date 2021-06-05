import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/db.dart';
import 'package:sound/model.dart';
import 'package:sound/local_storage.dart';

class CollectionsStore extends Store {
  List<NoteCollection> _selectedCollections;
  List<NoteCollection> get selectedCollections => _selectedCollections;

  List<NoteCollection> get filteredCollections =>
      DB().collections.where((NoteCollection collection) {
        return true;
        // if (_filters.length == 0 && (_search == null || _search == ""))
        //   return true;

        // if (_search != null && search != "") {
        //   if (_filters.length == 0) {
        //     return _isSearchValid(note);
        //   } else {
        //     return _isSearchValid(note) && _isAnyFilterValid(note);
        //   }
        // } else {
        //   return _isAnyFilterValid(note);
        // }
      }).toList();

  bool isAnyCollectionSelected() => _selectedCollections.length > 0;
  bool isAnyCollectionStarred() => filteredCollections.any((n) => n.starred);

  bool isSelected(NoteCollection collection) =>
      this._selectedCollections.contains(collection);

  CollectionsStore() {
    _selectedCollections = [];

    triggerSelectCollection.listen((NoteCollection collection) {
      if (!_selectedCollections.contains(collection)) {
        _selectedCollections.add(collection);
        trigger();
      } else {
        _selectedCollections.remove(collection);
        trigger();
      }
    });

    clearCollectionSelection.listen((_) {
      _selectedCollections.clear();
      trigger();
    });

    removeAllSelectedCollections.listen((_) {
      for (NoteCollection collection in _selectedCollections) {
        LocalStorage().deleteCollection(collection);
      }
      _selectedCollections.clear();
      trigger();
    });

    starAllSelectedCollections.listen((_) {
      for (NoteCollection collection in _selectedCollections) {
        collection.starred = true;
        LocalStorage().syncCollection(collection);
      }
      _selectedCollections.clear();
      trigger();
    });

    unstarAllSelectedCollections.listen((_) {
      for (NoteCollection collection in _selectedCollections) {
        collection.starred = false;
        LocalStorage().syncCollection(collection);
      }
      _selectedCollections.clear();
      trigger();
    });
  }
}

Action<NoteCollection> triggerSelectCollection = Action();
Action clearCollectionSelection = Action();
Action removeAllSelectedCollections = Action();
Action unstarAllSelectedCollections = Action();
Action starAllSelectedCollections = Action();

StoreToken collectionsStoreToken = StoreToken(CollectionsStore());
