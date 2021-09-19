import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/settings_store.dart';
import 'package:sound/utils.dart';
import 'local_storage.dart';
import 'file_manager.dart';
import 'model.dart';
import 'db.dart';
import 'package:flutter/material.dart' show Color;

enum FilterBy { LABEL, TUNING, KEY, CAPO }

class Filter {
  FilterBy by;
  String content;

  Filter({this.by, this.content});

  @override
  int get hashCode => (by.index.toString() + content).hashCode;

  bool operator ==(o) => (o is Filter && o.by == by && o.content == content);
}

class StaticStorage extends Store {
  List<Filter> _filters;
  Map<FilterBy, bool> _showMore;
  bool _twoPerRow;

  bool get view => _twoPerRow;

  List<Filter> get filters => _filters;

  List<Note> _selectedNotes;
  List<Note> get selectedNotes => _selectedNotes;

  List<String> _prevDiscardedNoteIds;
  List<String> get prevDiscardedNoteIds => _prevDiscardedNoteIds;

  String _search = "";
  String get search => _search;

  SortBy _sortBy = SortBy.lastModified;
  SortBy get sortBy => _sortBy;

  SortDirection _sortDirection = SortDirection.up;
  SortDirection get sortDirection => _sortDirection;

  bool mustShowMore(FilterBy by) {
    Map<FilterBy, List<Filter>> f = _getFiltersByCategory();
    if (f.keys.contains(by)) {
      return f[by].length > 3;
    } else
      return false;
  }

  bool isSelected(Note note) =>
      _selectedNotes.where((n) => n.id == note.id).toList().length > 0;

  bool isAnyNoteSelected() => _selectedNotes.length > 0;

  bool isAnyNoteStarred() => filteredNotes.any((n) => n.starred);

  bool showMore(FilterBy by) =>
      _showMore.containsKey(by) ? _showMore[by] : false;

  bool isFilterApplied(Filter filter) => _filters.contains(filter);

  StaticStorage() {
    _twoPerRow = false;

    toggleChangeView.listen((_) {
      _twoPerRow = !_twoPerRow;
      if (_twoPerRow) {
        setDefaultNoteListType(NoteListType.double);
      } else {
        setDefaultNoteListType(NoteListType.single);
      }
      trigger();
    });

    setTwoPerRow.listen((value) {
      _twoPerRow = value;
      trigger();
    });

    _filters = [];
    _selectedNotes = [];
    _showMore = Map();

    toggleShowMore.listen((by) {
      if (_showMore.containsKey(by)) {
        _showMore[by] = !_showMore[by];
      } else {
        _showMore[by] = true;
      }
      trigger();
    });

    addNote.listen((note) {
      DB().addNote(note);
      trigger();
    });

    addFilter.listen((f) {
      if (!_filters.contains(f)) {
        _filters.add(f);
        trigger();
      }
    });

    removeFilter.listen((f) {
      _filters.remove(f);
      trigger();
    });
    searchNotes.listen((s) {
      _search = s;
      trigger();
    });

    triggerSelectNote.listen((Note note) {
      if (!isSelected(note)) {
        _selectedNotes.add(note);
        trigger();
      } else {
        _selectedNotes.removeWhere((element) => element.id == note.id);
        trigger();
      }
    });

    resetStaticStorage.listen((_) {
      _search = "";
      _selectedNotes.clear();
      _filters.clear();
      trigger();
    });

    removeAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        for (var audio in note.audioFiles) {
          FileManager().delete(audio);
        }

        LocalStorage().deleteNote(note);
      }
      _selectedNotes.clear();
      trigger();
    });

    discardAllSelectedNotes.listen((removeFromCollections) {
      for (Note note in _selectedNotes) {
        LocalStorage().discardNote(note, removeFromCollections);
      }

      _prevDiscardedNoteIds = _selectedNotes.map((e) => e.id).toList();
      _selectedNotes.clear();
      trigger();
    });

    starAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        note.starred = true;
        LocalStorage().syncNoteAttr(note, 'starred');
      }
      _selectedNotes.clear();
      trigger();
    });
    unstarAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        note.starred = false;
        LocalStorage().syncNoteAttr(note, 'starred');
      }
      _selectedNotes.clear();
      trigger();
    });

    colorAllSelectedNotes.listen((Color color) {
      for (Note note in _selectedNotes) {
        note.color = color;
        LocalStorage().syncNoteAttr(note, 'color');
      }
      _selectedNotes.clear();
      trigger();
    });

    restoreNotes.listen((_notes) {
      for (Note note in _notes) {
        LocalStorage().restoreNote(note);
      }
      trigger();
    });

    clearSelection.listen((_) {
      _selectedNotes.clear();
      trigger();
    });

    updateView.listen((_) {
      // only update the view, data is stored in file_manager
      trigger();
    });

    changeSortDirection.listen((d) {
      if (this._sortDirection != d) {
        this._sortDirection = d;
        trigger();
      }
    });

    changeSortBy.listen((by) {
      if (_sortBy != by) {
        print("set sort by to $by");
        this._sortBy = by;
        trigger();
      }
    });

    changeListType.listen((event) {
      var twoPerRow = (event == NoteListType.single) ? false : true;
      if (twoPerRow != _twoPerRow) {
        _twoPerRow = twoPerRow;
        trigger();
      }
    });

    undoDiscardAllSelectedNotes.listen((event) {
      for (String noteId in this._prevDiscardedNoteIds) {
        LocalStorage().restoreNoteById(noteId);
      }
    });
  }

  bool _isSearchValid(Note note) {
    if (_search != null) {
      var search = _search.toLowerCase();
      if (note.label != null && note.label.toLowerCase().contains(search))
        return true;
      if (note.capo != null &&
          note.capo.toString().toLowerCase().contains(search)) return true;
      if (note.title != null && note.title.toLowerCase().contains(search))
        return true;

      if (note.artist != null && note.artist.toLowerCase().contains(search))
        return true;

      if (note.tuning != null && note.tuning.toLowerCase().contains(search))
        return true;

      if (note.sections.any((s) =>
          s.content.toLowerCase().contains(search) ||
          resolveRichContent(s.content).toLowerCase().contains(search) ||
          s.title.toLowerCase().contains(search))) return true;
    }
    return false;
  }

  Map<FilterBy, List<Filter>> _getFiltersByCategory() {
    Map<FilterBy, List<Filter>> m = Map();
    for (Filter f in _filters) {
      if (m.keys.contains(f.by)) {
        m[f.by].add(f);
      } else {
        m[f.by] = [f];
      }
    }
    return m;
  }

  bool _isFilterValid(Filter filter, Note note) {
    if (filter.by == FilterBy.CAPO) {
      if (note.capo.toString() == filter.content) return true;
    } else if (filter.by == FilterBy.KEY) {
      if (note.key == filter.content) return true;
    } else if (filter.by == FilterBy.TUNING) {
      if (note.tuning == filter.content) return true;
    } else if (filter.by == FilterBy.LABEL) {
      if (note.label == filter.content) return true;
    }
    return false;
  }

  bool _isAnyFilterValid(Note note) {
    Map<FilterBy, List<Filter>> m = _getFiltersByCategory();
    for (List<Filter> l in m.values) {
      if (!l.any((f) => _isFilterValid(f, note))) {
        return false;
      }
    }
    return true;
  }

  String getLower(String t) {
    if (t == null)
      return null;
    else
      return t.toLowerCase();
  }

  int _sort(Note a, Note b) {
    if (_sortBy == SortBy.lastModified) {
      if (_sortDirection == SortDirection.up) {
        return b.lastModified.compareTo(a.lastModified);
      } else {
        return a.lastModified.compareTo(b.lastModified);
      }
    } else if (_sortBy == SortBy.created) {
      if (_sortDirection == SortDirection.up) {
        return b.createdAt.compareTo(a.createdAt);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    } else if (_sortBy == SortBy.az) {
      if (_sortDirection == SortDirection.up) {
        return getLower(b.title).compareTo(getLower(a.title));
      } else {
        return getLower(a.title).compareTo(getLower(b.title));
      }
    } else
      return 1;
  }

  List<Note> get filteredNotes {
    List<Note> notes = DB().notes;
    notes.sort(_sort);

    return notes.where((Note note) {
      if (_filters.length == 0 && (_search == null || _search == ""))
        return true;

      if (_search != null && search != "") {
        if (_filters.length == 0) {
          return _isSearchValid(note);
        } else {
          return _isSearchValid(note) && _isAnyFilterValid(note);
        }
      } else {
        return _isAnyFilterValid(note);
      }
    }).toList();
  }
}

Action<List<Note>> setNotes = Action();
Action<Note> addNote = Action();
Action<Filter> addFilter = Action();
Action<Filter> removeFilter = Action();

Action<String> searchNotes = Action();
Action<FilterBy> toggleShowMore = Action();
Action toggleChangeView = Action();
Action<bool> setTwoPerRow = Action();
Action openSettings = Action();
//Action<FirebaseUser> setUser = Action();

Action<Note> triggerSelectNote = Action();
Action removeAllSelectedNotes = Action();
Action<bool> discardAllSelectedNotes = Action();
Action undoDiscardAllSelectedNotes = Action();
Action starAllSelectedNotes = Action();
Action unstarAllSelectedNotes = Action();
Action<Color> colorAllSelectedNotes = Action();

Action<List<Note>> restoreNotes = Action();
Action clearSelection = Action();
Action updateView = Action();
Action resetStaticStorage = Action();
Action<SortBy> changeSortBy = Action();
Action<SortDirection> changeSortDirection = Action();
Action<NoteListType> changeListType = Action();

StoreToken storageToken = StoreToken(StaticStorage());
StoreToken searchNoteStorageToken = StoreToken(StaticStorage());
